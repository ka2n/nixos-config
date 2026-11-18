# Window restore tokens

The patch extends xdg-desktop-portal-wlr 0.8.2 to return and restore an
`ext-foreign-toplevel-list-v1` window identifier. Monitor restore data stays at
version 1; window data uses version 2. Unknown, closed, or disallowed targets
fall back to the chooser. Window titles and app IDs are never used to restore
a different window.

The service sets `XDPW_PERSIST_MODE=transient`, allowing applications to reuse
the selection within their lifetime. The policy also applies to restored
sessions. This enables Chromium to reuse the preview selection for its actual
capture; it can also reuse that selection for subsequent requests during its
lifetime. A new selection is required when the original window no longer exists.

The patch also fixes Start's session lookup: it must stop at the matching
session before reading that session's persistence mode.

## Local backend integration test

Run from the repository root in a live river session with PipeWire running:

```bash
nix build .#nixosConfigurations.wk2511058.pkgs.xdg-desktop-portal-wlr \
  --out-link /tmp/xdpw-window-restore-result
nix shell --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = f.nixosConfigurations.wk2511058.pkgs;
  in p.python3.withPackages (ps: [ ps.dbus-next ])
' --command python pkgs/xdg-desktop-portal-wlr/test-restore.py \
  /tmp/xdpw-window-restore-result/libexec/xdg-desktop-portal-wlr
```

The test requires `foot` and `dbus-run-session` on PATH. It creates temporary
windows, starts the patched backend on a private D-Bus bus, and leaves the live
portal service unchanged. All test processes are stopped afterward.

Coverage: actual window and monitor capture session startup, restore data round
trips across closed sessions, chooser invocation counts, source type restrictions,
invalid restore data, closed windows, transient persistence limits, and disabled
persistence. The unpatched backend fails at the missing window restore data.
This does not test received video frames or Chromium's frontend token handling.

## Apply and check Chrome

```bash
sudo nixos-rebuild switch --flake .#wk2511058
systemctl --user restart xdg-desktop-portal-wlr
```

End any existing screen share and start a new one in Chrome. Select a test
window in wlr-chooser, then press Share in Chrome. The actual share should reuse the
selected window without showing the picker again. Verify the receiving side displays
the intended window. Close the selected window and begin a new share to check
that the picker prompts for a new target.

The graphical picker requires a river session using wlroots 0.20.2 or newer.
