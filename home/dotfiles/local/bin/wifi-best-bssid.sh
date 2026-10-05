set -euo pipefail

export LC_ALL=C

usage() {
  printf 'Usage: wifi-best-bssid [MIN_SIGNAL]\n'
  printf 'Pin the current Wi-Fi connection to its fastest eligible BSSID.\n'
  printf 'MIN_SIGNAL defaults to 60 and must be an integer from 0 to 100.\n'
}

case "${1-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if (( $# > 1 )); then
  usage >&2
  exit 2
fi

min_signal=${1:-60}
if [[ ! $min_signal =~ ^[0-9]+$ ]] || (( 10#$min_signal > 100 )); then
  printf 'wifi-best-bssid: MIN_SIGNAL must be an integer from 0 to 100\n' >&2
  exit 2
fi

nmcli=@nmcli@
device=
while IFS= read -r line; do
  candidate=${line%%:*}
  rest=${line#*:}
  type=${rest%%:*}
  state=${rest#*:}
  if [[ $type == wifi && $state == connected ]]; then
    device=$candidate
    break
  fi
done < <("$nmcli" --terse --escape no --fields DEVICE,TYPE,STATE device status)

if [[ -z $device ]]; then
  printf 'wifi-best-bssid: no connected Wi-Fi device found\n' >&2
  exit 1
fi

uuid=$("$nmcli" --get-values GENERAL.CON-UUID device show "$device")
if [[ -z $uuid || $uuid == -- ]]; then
  printf 'wifi-best-bssid: could not determine the active connection UUID for %s\n' "$device" >&2
  exit 1
fi

ssid=$("$nmcli" --terse --escape no --get-values 802-11-wireless.ssid connection show uuid "$uuid")
if [[ -z $ssid ]]; then
  printf 'wifi-best-bssid: could not determine the current SSID for %s\n' "$device" >&2
  exit 1
fi

if ! scan=$("$nmcli" --terse --escape no --fields IN-USE,RATE,SIGNAL,CHAN,BSSID,SSID device wifi list --rescan yes ifname "$device"); then
  printf 'wifi-best-bssid: could not rescan and list access points on %s\n' "$device" >&2
  exit 1
fi

printf 'BSSIDs for %s on %s (minimum signal: %s):\n' "$ssid" "$device" "$min_signal"
printf '%-17s  %-12s  %6s  %7s  %s\n' BSSID RATE SIGNAL CHANNEL CURRENT

best_bssid=
best_rate=-1
best_rate_label=
best_signal=-1
current_bssid=

while IFS= read -r line; do
  in_use=${line%%:*}
  rest=${line#*:}
  rate=${rest%%:*}
  rest=${rest#*:}
  signal=${rest%%:*}
  rest=${rest#*:}
  channel=${rest%%:*}
  rest=${rest#*:}

  if (( ${#rest} < 18 )) || [[ ${rest:17:1} != : ]]; then
    continue
  fi
  bssid=${rest:0:17}
  found_ssid=${rest:18}
  [[ $found_ssid == "$ssid" ]] || continue

  marker=
  if [[ $in_use == "*" ]]; then
    marker="*"
    current_bssid=$bssid
  fi
  printf '%-17s  %-12s  %6s  %7s  %s\n' "$bssid" "$rate" "$signal" "$channel" "$marker"

  [[ $signal =~ ^[0-9]+$ ]] || continue
  (( 10#$signal >= 10#$min_signal )) || continue
  [[ $rate =~ ^([0-9]+)(\.([0-9]+))?([[:space:]]|$) ]] || continue

  rate_whole=${BASH_REMATCH[1]}
  rate_fraction=${BASH_REMATCH[3]-}
  rate_fraction=${rate_fraction}000
  rate_value=$((10#$rate_whole * 1000 + 10#${rate_fraction:0:3}))
  signal_value=$((10#$signal))
  if (( rate_value > best_rate || (rate_value == best_rate && signal_value > best_signal) )); then
    best_bssid=$bssid
    best_rate=$rate_value
    best_rate_label=$rate
    best_signal=$signal_value
  fi
done <<< "$scan"

if [[ -z $best_bssid ]]; then
  printf 'wifi-best-bssid: no BSSID for %s meets the signal threshold %s\n' "$ssid" "$min_signal" >&2
  exit 1
fi

pinned_bssid=$("$nmcli" --terse --escape no --get-values 802-11-wireless.bssid connection show uuid "$uuid")
if [[ $current_bssid == "$best_bssid" ]]; then
  if [[ $pinned_bssid != "$best_bssid" ]]; then
    "$nmcli" connection modify uuid "$uuid" 802-11-wireless.bssid "$best_bssid"
  fi
  printf 'Selected %s (%s, signal %s); already connected and profile is pinned.\n' \
    "$best_bssid" "$best_rate_label" "$best_signal"
  exit 0
fi

printf 'Selecting %s (%s, signal %s)...\n' "$best_bssid" "$best_rate_label" "$best_signal"
restore_pin() {
  "$nmcli" connection modify uuid "$uuid" 802-11-wireless.bssid "$pinned_bssid" >/dev/null 2>&1 || true
}

"$nmcli" connection modify uuid "$uuid" 802-11-wireless.bssid "$best_bssid"
trap restore_pin EXIT INT TERM
if ! "$nmcli" connection up uuid "$uuid" ifname "$device" ap "$best_bssid"; then
  printf 'wifi-best-bssid: failed to activate %s; restoring previous BSSID setting\n' "$best_bssid" >&2
  exit 1
fi
trap - EXIT INT TERM
printf 'Connected to %s and pinned the profile.\n' "$best_bssid"
