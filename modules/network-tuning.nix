# 全ホスト共通のカーネルチューニング。
#
# 方針:
# ArchWiki の sysctl 記事 (https://wiki.archlinux.jp/index.php/Sysctl) は
# 「ネットワークインターフェイス専用のメモリを増やす」節に正確性の警告が付いており、
# 出典は Cloudflare のブログ記事のみ。実際 RedHat の tuned プロファイルを読むと
#   desktop                : kernel.sched_autogroup_enabled のみ (ネットワーク調整なし)
#   balanced               : sysctl セクション自体が無い
#   throughput-performance : vm.swappiness と net.core.somaxconn のみ
#   network-throughput     : tcp_rmem/tcp_wmem のみ。summary いわく
#                            "generally only necessary on older CPUs or 40G+ networks"
# となっており、net.core.rmem_* を設定するプロファイルは一つも無い。
#
# よってここでは記事の値を丸呑みせず、次の3つに該当するものだけ採用する:
#   (1) このリポジトリのホストで実測して裏が取れたもの
#   (2) tuned が実際に設定している値
#   (3) 低リスクでレイテンシに効くもの
# 見送った項目は末尾に理由付きで列挙する。
{ ... }:

{
  # BBR 用。systemd-sysctl.service は systemd-modules-load.service の後に走るので
  # tcp_congestion_control=bbr の設定時点でモジュールはロード済みになる。
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    # --- (1) 実測に基づく UDP 受信ドロップ対策 ---
    # wk2511058 で Udp6RcvbufErrors が受信データグラムの 1.16%。Meet/WebRTC は
    # IPv6 UDP で流れるが、CPU 競合時にブラウザが受信を捌ききれず、カーネルが
    # 取りこぼしていた。ping・PHY カウンタ・スループット試験のどれにも現れない。
    # 確認: awk '/Udp6RcvbufErrors/{print $2}' /proc/net/snmp6
    "net.core.rmem_default" = 1048576; # 既定 212992 (208 KiB)
    "net.core.rmem_max" = 16777216; # 既定 4194304。上限の引き上げのみ
    "net.ipv4.udp_rmem_min" = 8192; # 既定 4096。UDP ソケットの最低保証量

    # --- (2) tuned が実際に設定している値 ---
    # network-latency 由来。既定の 1 はクライアント側のみ、3 で送受信とも有効。
    "net.ipv4.tcp_fastopen" = 3;
    # throughput-performance 由来。既定 60 は実メモリの潤沢なワークステーションには高い。
    "vm.swappiness" = 10;

    # --- (3) 低リスクなレイテンシ改善 ---
    # PMTU ブラックホール対策。経路上に MTU を詰める区間があっても停止しない。
    "net.ipv4.tcp_mtu_probing" = 1;
    # 既定 cubic。qdisc は NixOS 既定の fq_codel のままで BBR と組み合わせる。
    "net.ipv4.tcp_congestion_control" = "bbr";

    # --- ルーターではないので ICMP リダイレクトを受け取らない/送らない ---
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  # 意図的に採用しなかった項目 (ArchWiki 記載順):
  #
  # net.core.netdev_max_backlog=16384
  #   記事は「高速なカード」向けとするが根拠は Cloudflare のブログのみ。1GbE では
  #   まず飽和しない。インターフェイスの RX drop は観測しているが、Linux の RX
  #   dropped は非 IP フレーム等も数えるため backlog 溢れの証拠にならない。
  #   load と相関することを確認できたら再検討する。
  # net.core.somaxconn=8192 … 既に 4096 (kernel 5.4 以降の既定) で tuned の 2048 を上回る。
  # net.core.wmem_* / tcp_wmem の拡大 … 送信側で詰まった実測がまだ無い。
  # net.ipv4.tcp_max_syn_backlog / tcp_max_tw_buckets / tcp_tw_reuse / tcp_fin_timeout
  #   … いずれも高負荷サーバ向け。デスクトップでは無意味。
  # net.ipv4.tcp_slow_start_after_idle=0 … 常時接続サーバ向け。
  # net.ipv4.tcp_timestamps=0 … 記事自身が警告している通りセキュリティ上非推奨。
  # net.ipv4.ip_local_port_range … 記事自身に「性能がどう向上するのか」と
  #   正確性タグが付いている。
  # net.ipv4.conf.*.rp_filter=1 (strict)
  #   docker0/virbr0/tailscale0/複数ブリッジがあり、有線と WiFi が同一サブネットに
  #   同居する場面もある。strict にすると戻りパケットが落ちる。既定の loose のままにする。
  # net.ipv4.conf.*.log_martians=1 … 記事の注記通りログが膨れる。調査時に一時的に入れる。
  # net.ipv4.icmp_echo_ignore_all=1 … 監視と自前の疎通確認が壊れる。
  # net.core.busy_read / busy_poll=50 (tuned network-latency)
  #   受信レイテンシは下がるがビジーポーリングで CPU を焼く。上記 (1) の原因が
  #   そもそも CPU 競合なので逆効果になる。
  # vm.dirty_ratio / dirty_background_ratio … 記事も「RAM 量を考慮せよ」とするのみで
  #   推奨値を示していない。tuned の throughput-performance は既定より緩める方向で
  #   サーバ向け。デスクトップは既定のままとする。
}
