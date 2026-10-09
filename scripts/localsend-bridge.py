#!/usr/bin/env python3
"""Small LocalSend v2 bridge for the Quickshell menu-bar indicator."""

import argparse
import concurrent.futures
import hashlib
import http.client
import json
import mimetypes
import ipaddress
import os
import random
import select
import socket
import ssl
import struct
import tempfile
import subprocess
import sys
import time
import uuid
from urllib.parse import urlencode

MULTICAST_ADDRESS = "224.0.0.167"
DEFAULT_PORT = 53317
DISCOVERY_TIMEOUT = 5.0


_security_material = None


def local_security_material():
    global _security_material
    if _security_material is not None:
        return _security_material

    candidates = [
        os.path.expanduser(
            "~/.var/app/org.localsend.localsend_app/data/"
            "org.localsend.localsend_app/shared_preferences.json"
        ),
        os.path.expanduser(
            "~/.local/share/org.localsend.localsend_app/shared_preferences.json"
        ),
    ]
    for path in candidates:
        try:
            with open(path, encoding="utf-8") as source:
                preferences = json.load(source)
            raw = preferences.get("flutter.ls_security_context")
            context = json.loads(raw) if raw else {}
            certificate = context["certificate"]
            private_key = context["privateKey"]
            fingerprint = context.get("certificateHash") or ""
            directory = tempfile.mkdtemp(prefix="quickshell-localsend-")
            certificate_path = os.path.join(directory, "certificate.pem")
            private_key_path = os.path.join(directory, "private-key.pem")
            with open(certificate_path, "w", encoding="utf-8") as output:
                output.write(certificate)
            with open(private_key_path, "w", encoding="utf-8") as output:
                output.write(private_key)
            os.chmod(private_key_path, 0o600)
            _security_material = (certificate_path, private_key_path, fingerprint)
            return _security_material
        except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
            continue

    _security_material = None
    return None


def identity(port, protocol="http", fingerprint=None):
    return {
        "alias": socket.gethostname(),
        "version": "2.0",
        "deviceModel": "Linux",
        "deviceType": "desktop",
        "fingerprint": fingerprint or uuid.uuid4().hex,
        "port": port,
        "protocol": protocol,
        "download": True,
    }


def add_device(devices, payload, host):
    if not isinstance(payload, dict) or not payload.get("alias"):
        return
    fingerprint = str(payload.get("fingerprint") or "")
    if fingerprint and fingerprint in devices:
        return

    key = fingerprint or f"{payload.get('alias')}@{host}"
    if key in devices:
        return

    try:
        port = int(payload.get("port") or DEFAULT_PORT)
    except (TypeError, ValueError):
        port = DEFAULT_PORT

    devices[key] = {
        "alias": str(payload.get("alias")),
        "host": host,
        "port": port,
        "protocol": str(payload.get("protocol") or "https"),
        "deviceType": str(payload.get("deviceType") or "desktop"),
        "deviceModel": str(payload.get("deviceModel") or ""),
        "fingerprint": fingerprint,
    }


def read_http_request(conn):
    conn.settimeout(0.4)
    data = b""
    while b"\r\n\r\n" not in data and len(data) < 65536:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk

    if b"\r\n\r\n" not in data:
        return {}

    header, body = data.split(b"\r\n\r\n", 1)
    length = 0
    for line in header.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            try:
                length = int(line.split(b":", 1)[1].strip())
            except ValueError:
                pass

    while len(body) < length:
        chunk = conn.recv(min(65536, length - len(body)))
        if not chunk:
            break
        body += chunk

    try:
        return json.loads(body[:length or len(body)].decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return {}


def discover(timeout=DISCOVERY_TIMEOUT):
    devices = {}
    material = local_security_material()
    protocol = "https" if material else "http"
    fingerprint = material[2] if material else None
    tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    tcp.bind(("0.0.0.0", 0))
    tcp.listen(8)
    tcp.setblocking(False)
    port = tcp.getsockname()[1]

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except (AttributeError, OSError):
        pass

    # LocalSend listens for announcements on the well-known multicast port.
    # The old bridge bound the UDP socket to the random TCP port instead, so
    # it could send announcements but never saw the devices' replies.
    udp.bind(("0.0.0.0", DEFAULT_PORT))
    local_addresses = local_ipv4_addresses()
    if local_addresses:
        for local_address in local_addresses:
            membership = struct.pack(
                "=4s4s",
                socket.inet_aton(MULTICAST_ADDRESS),
                socket.inet_aton(local_address),
            )
            udp.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
        udp.setsockopt(
            socket.IPPROTO_IP,
            socket.IP_MULTICAST_IF,
            socket.inet_aton(sorted(local_addresses)[0]),
        )
    else:
        membership = struct.pack(
            "=4sl", socket.inet_aton(MULTICAST_ADDRESS), socket.INADDR_ANY
        )
        udp.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
    udp.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    udp.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
    udp.setblocking(False)

    announcement = identity(port, protocol, fingerprint)
    announcement["announce"] = True
    announcement["announcement"] = True
    payload = json.dumps(announcement).encode("utf-8")
    try:
        udp.sendto(payload, (MULTICAST_ADDRESS, DEFAULT_PORT))
        # A second announcement helps devices that were waking from sleep.
        time.sleep(0.05)
        udp.sendto(payload, (MULTICAST_ADDRESS, DEFAULT_PORT))

        deadline = time.monotonic() + timeout
        next_announcement = time.monotonic() + 1.0
        while time.monotonic() < deadline:
            now = time.monotonic()
            if now >= next_announcement:
                udp.sendto(payload, (MULTICAST_ADDRESS, DEFAULT_PORT))
                next_announcement = now + 1.0
            remaining = max(0.01, min(deadline - now, next_announcement - now))
            readable, _, _ = select.select([udp, tcp], [], [], remaining)
            for source in readable:
                if source is udp:
                    try:
                        data, address = udp.recvfrom(65536)
                        response = json.loads(data.decode("utf-8"))
                        if response.get("fingerprint") != announcement["fingerprint"]:
                            add_device(devices, response, address[0])
                    except (OSError, ValueError, UnicodeDecodeError):
                        pass
                else:
                    try:
                        connection, address = tcp.accept()
                        if material:
                            server_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                            server_context.load_cert_chain(material[0], material[1])
                            connection = server_context.wrap_socket(
                                connection, server_side=True
                            )
                        response = read_http_request(connection)
                        add_device(devices, response, address[0])
                        connection.sendall(
                            b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                        )
                        connection.close()
                    except OSError:
                        pass
    finally:
        udp.close()
        tcp.close()

    # Multicast is fast, but Wi-Fi isolation and some firewalls drop it.
    # Match LocalSend's legacy HTTP fallback so the menu finds the same LAN
    # devices as the full application.
    if not devices:
        scan_http(devices, announcement)

    # The local LocalSend app may answer our announcement too. It is not a
    # useful transfer target for this menu, so keep only remote addresses.
    local_addresses = local_ipv4_addresses()
    devices = {
        key: device
        for key, device in devices.items()
        if device["host"] not in local_addresses
    }

    return sorted(devices.values(), key=lambda device: device["alias"].lower())


def connection(host, port, protocol, timeout=20):
    if protocol.lower() == "https":
        context = ssl._create_unverified_context()
        material = local_security_material()
        if material:
            context.load_cert_chain(material[0], material[1])
        return http.client.HTTPSConnection(host, port, timeout=timeout, context=context)
    return http.client.HTTPConnection(host, port, timeout=timeout)


def post_json(host, port, protocol, path, body, timeout=20):
    conn = connection(host, port, protocol, timeout)
    data = json.dumps(body).encode("utf-8")
    conn.request(
        "POST",
        path,
        body=data,
        headers={
            "Content-Type": "application/json",
            "Content-Length": str(len(data)),
        },
    )
    response = conn.getresponse()
    response_body = response.read()
    status = response.status
    conn.close()
    return status, response_body


def upload_file(host, port, protocol, path, file_path):
    size = os.path.getsize(file_path)
    conn = connection(host, port, protocol)
    conn.putrequest("POST", path)
    conn.putheader("Content-Type", "application/octet-stream")
    conn.putheader("Content-Length", str(size))
    conn.endheaders()
    with open(file_path, "rb") as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            conn.send(chunk)
    response = conn.getresponse()
    response.read()
    status = response.status
    conn.close()
    return status


def send_files(args):
    files = []
    temporary_paths = []
    for path in args.files:
        path = os.path.abspath(path)
        if not os.path.isfile(path):
            raise RuntimeError(f"Not a file: {path}")
        digest = hashlib.sha256()
        with open(path, "rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        file_id = uuid.uuid4().hex
        files.append(
            {
                "path": path,
                "id": file_id,
                "fileName": os.path.basename(path),
                "size": os.path.getsize(path),
                "fileType": mimetypes.guess_type(path)[0] or "application/octet-stream",
                "sha256": digest.hexdigest(),
            }
        )

    for index, text in enumerate(args.text, start=1):
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".txt", delete=False
        ) as output:
            output.write(text)
            path = output.name
        temporary_paths.append(path)
        encoded = text.encode("utf-8")
        files.append(
            {
                "path": path,
                "id": uuid.uuid4().hex,
                "fileName": "Shared text.txt" if index == 1
                    else f"Shared text {index}.txt",
                "size": len(encoded),
                "fileType": "text/plain",
                "sha256": hashlib.sha256(encoded).hexdigest(),
            }
        )

    if not files:
        raise RuntimeError("No files or text to send")

    material = local_security_material()
    sender = identity(
        0,
        "https" if material else "http",
        material[2] if material else None,
    )
    sender["alias"] = socket.gethostname()
    request = {
        "info": sender,
        "files": {
            item["id"]: {
                "id": item["id"],
                "fileName": item["fileName"],
                "size": item["size"],
                "fileType": item["fileType"],
                "sha256": item["sha256"],
            }
            for item in files
        },
    }

    status, response_body = post_json(
        args.host,
        args.port,
        args.protocol,
        "/api/localsend/v2/prepare-upload",
        request,
    )
    if status == 204:
        return
    if status < 200 or status >= 300:
        raise RuntimeError(f"Receiver rejected the transfer ({status})")

    try:
        response = json.loads(response_body.decode("utf-8"))
        tokens = response["files"]
        session_id = response["sessionId"]
    except (KeyError, ValueError, UnicodeDecodeError) as error:
        raise RuntimeError("Invalid response from receiver") from error

    for item in files:
        token = tokens.get(item["id"])
        if not token:
            continue
        query = urlencode(
            {
                "sessionId": session_id,
                "fileId": item["id"],
                "token": token,
            }
        )
        status = upload_file(
            args.host,
            args.port,
            args.protocol,
            "/api/localsend/v2/upload?" + query,
            item["path"],
        )
        if status < 200 or status >= 300:
            raise RuntimeError(f"Upload failed for {item['fileName']} ({status})")

    for path in temporary_paths:
        try:
            os.unlink(path)
        except OSError:
            pass


def local_ipv4_addresses():
    try:
        result = subprocess.run(
            ["ip", "-j", "-4", "addr", "show", "scope", "global"],
            check=True,
            capture_output=True,
            text=True,
        )
        interfaces = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return set()

    return {
        address["local"]
        for interface in interfaces
        for address in interface.get("addr_info", [])
        if address.get("family") == "inet" and address.get("local")
    }


def local_network_hosts():
    try:
        result = subprocess.run(
            ["ip", "-j", "-4", "addr", "show", "scope", "global"],
            check=True,
            capture_output=True,
            text=True,
        )
        interfaces = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return []

    hosts = set()
    for interface in interfaces:
        for address in interface.get("addr_info", []):
            if address.get("family") != "inet":
                continue
            try:
                network = ipaddress.ip_network(
                    f"{address['local']}/{address['prefixlen']}", strict=False
                )
            except (KeyError, ValueError):
                continue
            # Avoid turning a discovery click into a huge scan on /16 or /8
            # networks. LocalSend's normal LANs are /24 or smaller.
            if network.num_addresses > 256:
                network = ipaddress.ip_network(
                    f"{address['local']}/24", strict=False
                )
            hosts.update(str(host) for host in network.hosts())
            hosts.discard(address["local"])
    return sorted(hosts)


def scan_http(devices, announcement):
    body = dict(announcement)
    body.pop("announce", None)
    body.pop("announcement", None)

    def probe(host):
        for protocol in ("https", "http"):
            try:
                status, response = post_json(
                    host,
                    DEFAULT_PORT,
                    protocol,
                    "/api/localsend/v2/register",
                    body,
                    timeout=0.35,
                )
                if 200 <= status < 300:
                    payload = json.loads(response.decode("utf-8"))
                    if payload.get("alias"):
                        return payload
            except (OSError, ValueError, UnicodeDecodeError):
                pass
        return None

    hosts = local_network_hosts()
    with concurrent.futures.ThreadPoolExecutor(max_workers=32) as executor:
        for host, payload in zip(hosts, executor.map(probe, hosts)):
            if payload:
                add_device(devices, payload, host)


def process_running():
    exact_patterns = ("localsend_app", "localsend")
    for pattern in exact_patterns:
        result = subprocess.run(
            ["pgrep", "-x", pattern],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True

    # Flatpak may expose the application under its full app id instead of
    # the short binary name.
    result = subprocess.run(
        ["pgrep", "-f", "org\\.localsend\\.localsend(_app)?"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status")
    discover_parser = subparsers.add_parser("discover")
    discover_parser.add_argument("--timeout", type=float, default=DISCOVERY_TIMEOUT)
    send_parser = subparsers.add_parser("send")
    send_parser.add_argument("--host", required=True)
    send_parser.add_argument("--port", type=int, required=True)
    send_parser.add_argument("--protocol", choices=("http", "https"), default="https")
    send_parser.add_argument("--files", nargs="*", default=[])
    send_parser.add_argument("--text", action="append", default=[])
    args = parser.parse_args()

    try:
        if args.command == "status":
            print(json.dumps({"running": process_running()}))
        elif args.command == "discover":
            print(json.dumps({"devices": discover(args.timeout)}))
        else:
            send_files(args)
            print(json.dumps({"ok": True}))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
