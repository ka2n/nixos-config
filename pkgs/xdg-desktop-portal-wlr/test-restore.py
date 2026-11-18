"""Run against a local Wayland/PipeWire session using a private D-Bus bus.

Requires Python with dbus-next, dbus-run-session, and foot.
Usage: python test-restore.py /path/to/libexec/xdg-desktop-portal-wlr
"""

import asyncio
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def choose():
    directory = Path(sys.argv[2])
    counter = directory / "count"
    counter.write_text(str(int(counter.read_text()) + 1))
    mode = (directory / "mode").read_text()
    lines = sys.stdin.read().splitlines()
    prefix = "Monitor: " if mode == "monitor" else "Window: XDPW restore test"
    for line in lines:
        if line.startswith(prefix):
            print(line)
            return


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


async def test(binary, directory):
    from dbus_next import Message, MessageType, Variant
    from dbus_next.aio import MessageBus

    bus = await MessageBus().connect()
    destination = "org.freedesktop.impl.portal.desktop.wlr"
    interface = "org.freedesktop.impl.portal.ScreenCast"
    root = "/org/freedesktop/portal/desktop"
    count = directory / "count"
    mode = directory / "mode"
    count.write_text("0")
    mode.write_text("window")
    config = directory / "config"
    command = shlex.join([sys.executable, str(Path(__file__).resolve()), "--chooser", str(directory)])
    config.write_text(f"[screencast]\nchooser_type=dmenu\nchooser_cmd={command}\n")
    environment = dict(os.environ, XDPW_PERSIST_MODE="transient")
    windows = []
    backend = None
    sequence = 0

    async def call(path, member, signature="", body=None, iface=interface):
        reply = await asyncio.wait_for(bus.call(Message(
            destination=destination, path=path, interface=iface,
            member=member, signature=signature, body=body or [],
        )), timeout=15)
        assert reply.message_type != MessageType.ERROR, (member, reply.error_name, reply.body)
        return reply.body

    async def capture(types, restore=None, persist=1, canceled=False):
        nonlocal sequence
        sequence += 1
        request = f"/org/freedesktop/portal/desktop/request/test/r{sequence}"
        session = f"/org/freedesktop/portal/desktop/session/test/s{sequence}"
        app = "org.example.XdpwRestoreTest"
        result = await call(root, "CreateSession", "oosa{sv}", [request, session, app, {}])
        assert result[0] == 0, result
        options = {"types": Variant("u", types), "persist_mode": Variant("u", persist)}
        if restore is not None:
            options["restore_data"] = restore
        try:
            selected = await call(root, "SelectSources", "oosa{sv}", [request, session, app, options])
            if canceled:
                assert selected[0] == 1, "chooser returned a source outside requested types"
                return
            assert selected[0] == 0, selected
            started = await call(root, "Start", "oossa{sv}", [request, session, app, "", {}])
            assert started[0] == 0, started
            assert started[1]["streams"].value[0][0] > 0
            return started[1]
        finally:
            await call(session, "Close", iface="org.freedesktop.impl.portal.Session")

    def prompts():
        return int(count.read_text())

    def window(title):
        process = subprocess.Popen(["foot", "--app-id=xdpw-restore-test", f"--title={title}", "sleep", "300"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        windows.append(process)
        return process

    try:
        primary = window("XDPW restore test primary")
        await asyncio.sleep(0.8)
        with (directory / "backend.log").open("w") as log:
            backend = subprocess.Popen([binary, "--config", str(config), "--loglevel=INFO"],
                                       env=environment, stdout=log, stderr=log)
        for _ in range(100):
            reply = await bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                interface="org.freedesktop.DBus", member="NameHasOwner", signature="s", body=[destination]))
            if reply.body == [True]:
                break
            assert backend.poll() is None, "backend exited at startup"
            await asyncio.sleep(0.05)
        else:
            raise AssertionError("backend did not acquire its bus name")

        first = await capture(2)
        assert "restore_data" in first, "window capture did not return restore_data"
        token = first["restore_data"]
        assert token.value[1] == 2 and "toplevel_identifier" in token.value[2].value
        assert first["persist_mode"].value == 1
        assert prompts() == 1
        second = await capture(2, token, persist=2)
        assert prompts() == 1, "restored window opened chooser again"
        assert second["restore_data"].value == token.value
        assert second["persist_mode"].value == 1, "restoration bypassed transient policy"
        print("PASS: window capture restores across closed sessions without another chooser")

        mode.write_text("monitor")
        monitor = await capture(1, token)
        assert prompts() == 2, "window token bypassed monitor-only source restriction"
        monitor_token = monitor["restore_data"]
        assert monitor_token.value[1] == 1 and "output_name" in monitor_token.value[2].value
        await capture(1, monitor_token)
        assert prompts() == 2, "legacy monitor restoration regressed"
        mode.write_text("window")
        await capture(2, monitor_token)
        assert prompts() == 3, "monitor token bypassed window-only source restriction"
        print("PASS: source type restrictions and legacy monitor restoration")

        mode.write_text("monitor")
        await capture(2, canceled=True)
        mode.write_text("window")
        await capture(1, canceled=True)
        print("PASS: chooser selections outside requested source types are rejected")

        malformed = [
            Variant("(suv)", ["wlroots", 2, Variant("a{sv}", {})]),
            Variant("(suv)", ["wlroots", 99, Variant("a{sv}", {})]),
            Variant("(suv)", ["wlroots", 2, Variant("a{sv}", {
                **token.value[2].value, **monitor_token.value[2].value})]),
        ]
        for invalid in malformed:
            before = prompts()
            await capture(2, invalid)
            assert prompts() == before + 1, "invalid token did not fall back to chooser"
        print("PASS: missing, unknown-version, and ambiguous restore data prompt again")

        window("XDPW restore test fallback")
        stop(primary)
        await asyncio.sleep(0.5)
        before = prompts()
        fallback = await capture(2, token)
        assert prompts() == before + 1, "closed window did not trigger a fresh selection"
        assert fallback["restore_data"].value != token.value
        print("PASS: closed window falls back to selecting another window")

        before = prompts()
        no_persist = await capture(2, persist=0)
        assert no_persist["persist_mode"].value == 0 and "restore_data" not in no_persist
        assert prompts() == before + 1
        print("PASS: caller can disable persistence")
    except BaseException:
        # Capturable window titles in the log belong to the user's live session.
        print("Test failed; backend log stays private and is removed during cleanup.", file=sys.stderr)
        raise
    finally:
        bus.disconnect()
        for process in [backend, *windows]:
            stop(process)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--chooser":
        choose()
    elif len(sys.argv) > 1 and sys.argv[1] == "--isolated":
        with tempfile.TemporaryDirectory(prefix="xdpw-restore-test-") as temporary:
            asyncio.run(test(sys.argv[2], Path(temporary)))
    else:
        if len(sys.argv) != 2:
            sys.exit(__doc__)
        subprocess.run(["dbus-run-session", "--", sys.executable, __file__, "--isolated", sys.argv[1]], check=True)
