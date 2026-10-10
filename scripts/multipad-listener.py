#!/usr/bin/env python3
"""Keep a Quickshell Process connected to cleartouchd's JSON socket."""

import os
import socket
import sys
import time

cache_home = os.environ.get(
    "XDG_CACHE_HOME",
    os.path.join(os.path.expanduser("~"), ".cache"),
)
SOCKET_PATH = os.environ.get(
    "CLEARTOUCHD_SOCKET",
    os.path.join(cache_home, "cleartouchd.sock"),
)

while True:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(2.0)
            client.connect(SOCKET_PATH)
            client.settimeout(None)
            with client.makefile("r", encoding="utf-8") as stream:
                for line in stream:
                    if line.strip():
                        print(line.strip(), flush=True)
    except (OSError, ConnectionError):
        time.sleep(0.5)
    except Exception as error:
        print(f"multipad-listener: {error}", file=sys.stderr, flush=True)
        time.sleep(1.0)
