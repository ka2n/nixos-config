#!/bin/sh
# Show Himmelblau / Entra ID status
# Combines: aad-tool status, linux-entra-sso getAccounts

bindir=$(dirname "$(systemctl show himmelblaud.service -p ExecStart | grep -oP 'path=\K[^ ;]+')")

echo "=== aad-tool status ==="
sudo "$bindir/aad-tool" status

echo ""
echo "=== Entra SSO accounts ==="
"$bindir/linux-entra-sso" -i getAccounts
