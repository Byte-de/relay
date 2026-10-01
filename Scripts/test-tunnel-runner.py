#!/usr/bin/env python3
"""Offline lifecycle checks. Creates only disposable child processes, never a tunnel."""
import os
import signal
import subprocess
import sys
import time

runner = os.path.abspath(sys.argv[1])


def gone(pid):
    try:
        os.kill(pid, 0)
        return False
    except ProcessLookupError:
        return True


def wait_gone(pid):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if gone(pid):
            return
        time.sleep(0.05)
    raise AssertionError(f"Owned fixture process {pid} survived")


def child_code(ignore_term=False):
    return (
        "import os,signal,sys,time; "
        + ("signal.signal(signal.SIGTERM, signal.SIG_IGN); " if ignore_term else "")
        + "assert sys.stdin.read() == ''; print(os.getpid(), flush=True); time.sleep(15)"
    )


for label, ignore_term, terminate in [("control pipe EOF", False, False),
                                     ("unresponsive child", True, False),
                                     ("supervisor SIGTERM", False, True)]:
    with subprocess.Popen([runner, sys.executable, "-c", child_code(ignore_term)],
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True) as process:
        child = int(process.stdout.readline())
        try:
            if terminate:
                process.terminate()
            else:
                process.stdin.close()
            assert process.wait(timeout=5) == 0
            wait_gone(child)
            print(f"PASS: {label}")
        finally:
            if process.poll() is None:
                process.stdin.close()
                process.terminate()
                process.wait(timeout=5)

# Simulate an app crash: the owner dies without calling any shutdown code.
parent_code = """
import subprocess,sys,time
runner = subprocess.Popen([sys.argv[1], sys.executable, '-c', sys.argv[2]],
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
print(runner.stdout.readline().strip(), flush=True)
time.sleep(15)
"""
with subprocess.Popen([sys.executable, "-c", parent_code, runner, child_code()],
                      stdout=subprocess.PIPE, text=True) as parent:
    child = int(parent.stdout.readline())
    parent.kill()
    parent.wait(timeout=5)
    wait_gone(child)
    print("PASS: owner crash closes the tunnel child")
