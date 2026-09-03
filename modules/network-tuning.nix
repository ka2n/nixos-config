# 実機ワークステーション向けのネットワークチューニング。
# VM (nixos-vm) では import していない。
{ ... }:

{
  # UDP 受信バッファの拡大。
  # Meet/WebRTC は IPv6 UDP で流れるが、CPU 競合時にブラウザが受信を捌ききれず
  # Udp6RcvbufErrors としてカーネルが取りこぼす（wk2511058 で累積 1.16%）。
  # ping や PHY カウンタ、スループット試験のどれにも現れないロスなので切り分けが難しい。
  # 確認: awk '/Udp6RcvbufErrors/{print $2}' /proc/net/snmp6
  # 既定値は rmem_default=212992 / rmem_max=4194304。
  boot.kernel.sysctl = {
    "net.core.rmem_default" = 1048576; # 1 MiB
    "net.core.rmem_max" = 16777216; # 16 MiB
  };
}
