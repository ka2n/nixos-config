#!/bin/sh

echo "=== aad-tool status ==="
sudo "@aad_tool@" status

echo ""
echo "=== Entra SSO accounts ==="
"@sso_helper@" -i getAccounts

echo ""
echo "=== Himmelblau device registration ==="
sudo grep -E '^(device_id|intune_device_id|tenant_id)' /var/cache/himmelblaud/himmelblau.conf

echo ""
echo "=== Defender (mdatp) health ==="
sudo mdatp health | grep -e '^healthy\s' -e '^licensed\s' -e '^org_id\s'
