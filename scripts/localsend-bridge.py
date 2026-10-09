#!/usr/bin/env python3
"""Small LocalSend v2 bridge for the Quickshell menu-bar indicator."""

import argparse
import hashlib
import http.client
import json
import mimetypes
import os
import random
import select
import socket
import ssl
import struct
import subprocess
import sys
import time
import uuid
from urllib.parse import urlencode

MULTICAST_ADDRESS = "224.0.0.167"
DEFAULT_PORT = 53317
DISCOVERY_TIMEOUT = 2.5


def identity(port):
    return {
        "alias": socket.gethostname(),
        "version": "2.0",
        "deviceModel": "Linux",
        "deviceType": "desktop",
        "fingerprint": uuid.uuid4().hex,
        "port": port,
        "protocol": "http",
        "download": False,
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
    udp.bind(("0.0.0.0", port))
    udp.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
    udp.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
    udp.setblocking(False)

    announcement = identity(port)
    announcement["announce"] = True
    payload = json.dumps(announcement).encode("utf-8")
    try:
        udp.sendto(payload, (MULTICAST_ADDRESS, DEFAULT_PORT))
        # A second announcement helps devices that were waking from sleep.
        time.sleep(0.05)
        udp.sendto(payload, (MULTICAST_ADDRESS, DEFAULT_PORT))

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            remaining = max(0.01, deadline - time.monotonic())
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

    return sorted(devices.values(), key=lambda device: device["alias"].lower())


def connection(host, port, protocol):
    if protocol.lower() == "https":
        context = ssl._create_unverified_context()
        return http.client.HTTPSConnection(host, port, timeout=20, context=context)
    return http.client.HTTPConnection(host, port, timeout=20)


def post_json(host, port, protocol, path, body):
    conn = connection(host, port, protocol)
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

    sender = identity(0)
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


def process_running():
    patterns = ("localsend_app", "localsend")
    for pattern in patterns:
        result = subprocess.run(
            ["pgrep", "-x", pattern],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True
    return False


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
    send_parser.add_argument("--files", nargs="+", required=True)
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
