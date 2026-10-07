#!/usr/bin/env python3
import fcntl
import os
import signal
import stat

runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
path = os.path.join(runtime, "quickshell-notch-toggle")
lock_path = path + ".lock"

lock = open(lock_path, "w")
try:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)

try:
    if os.path.exists(path) and not stat.S_ISFIFO(os.stat(path).st_mode):
        os.unlink(path)
except FileNotFoundError:
    pass

try:
    os.mkfifo(path, 0o600)
except FileExistsError:
    pass

def cleanup(*_args):
    # Leave the FIFO in place so a reloaded Quickshell can reuse it without
    # racing the compositor keybind. The lock is released on process exit.
    raise SystemExit

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

while True:
    # Opening the FIFO blocks until the keybind writes. Reopen after each
    # writer exits so the next keypress is accepted immediately.
    with open(path, "r") as fifo:
        for _line in fifo:
            print("toggle", flush=True)
