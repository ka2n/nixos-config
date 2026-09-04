# WebRTC パケロスの切り分け手順と、踏んだ罠

2026-09-04 の調査で実際に有効だった手順と、時間を溶かした落とし穴。

## 大原則: ping では絶対に再現しない

本件も [../wifi7-mlo-packetloss.md](../wifi7-mlo-packetloss.md) も、**クライアント側の指標は
すべて 0% だった**。17% のロスが出ている通話の真っ最中に打った ping が 0% ロスで返る。

```
Meet 実測      音声損失 16.5%  映像損失 17.1%  freeze 通話の29%
同時刻の ping   ノード 1200発 0%  親ルーター 1200発 0%  Meet中継 300発 0%
```

低レートの小さな ICMP は 802.11 の再送で生き残るが、200pps・1200バイトのメディアは
1 秒のエアタイム停止で AP のキューが溢れて落ちる。**判定材料は rtcstats のみ。**

## 1. データの取り方

### rtcstats_dump（これを使う）

Meet の troubleshooting からエクスポートする。行区切り JSON で
`["getStats", pcId, 完全なスナップショット, t]` の形式。**差分圧縮ではない**ので素直に読める。

- **`webrtc_internals_dump` は使えない。** getUserMedia の情報しか入らず 3KB 程度にしかならない。
- 途中で再入室するとピア接続が作り直され、**getStats が数サンプルしか入らない**ことがある。
  ファイル内の pcId が複数あったら要注意。抜けずに 10 分維持してからエクスポートする。
- **無音だと音声統計が成立しない。** Meet の音声は DTX で無音時に送信しないため、
  喋らない通話では母数が足りず損失率が跳ね上がる。相手側で音楽等を流しておく。
- 一人で入ると受信ストリームが存在しないので**テストにならない**。スマホ等で同じ会議に入る。

### 見るべき統計

| type | 見るもの | 意味 |
| --- | --- | --- |
| `inbound-rtp` | `packetsLost` / `freezeCount` / `totalFreezesDuration` / `nackCount` | 受信品質 |
| `outbound-rtp` | `qualityLimitationDurations` | **`cpu` が 0 秒なら CPU 競合は無罪** |
| `remote-inbound-rtp` | `packetsLost` | サーバから見た**こちらの送信**品質 |
| `candidate-pair` (nominated) | `currentRoundTripTime` / `networkType` | 実際に使われた経路 |
| `transport` | `[bytesReceived_in_bits/s]` | 経路全体が止まっているか |

**受信と送信のどちらが壊れているかを最初に確定させる。** 本件は受信のみで、
送信は 19 分で 3〜5 パケットしか落ちていなかった。この非対称が切り分けの起点になる。

音声のジッタは等間隔送信なので経路の素の指標になる（本件 p50 4ms = 正常）。
**映像のジッタ p50 111ms は異常ではない** — フレーム単位のバースト送信で当然上がる。

## 2. 罠リスト

### 親ルーターとメッシュノードを取り違えない

**必ずデフォルトゲートウェイの MAC で確定させる。** 電波が強い方が親とは限らない。

```bash
ip route show default                 # ゲートウェイの IP
ip neigh show <gateway-ip>            # その MAC = 親ルーターの本体 MAC
```

1 台の AP は各バンドごとに BSSID を持つが、**同じ機体の BSSID は上位オクテットが同系列**に
なる。ゲートウェイの MAC と同系列なら親、別系列ならメッシュノード。

バンド構成からも判別できる。本件では親が RT-BE18000（tri-band、**6GHz を持つのは親だけ**）、
ノードが RT-AX86U（dual-band、6GHz なし）なので、6GHz を吹いている BSSID は必ず親。

一度これを逆に取り違え、**電波が強いだけのノードに BSSID 固定して 2 ホップの競合経路へ
押し込んでしまった**。判断材料は電波強度ではなく**ホップ数とエアタイム競合**。

### `ss` で拾った Google の IP はメディア中継ではない

QUIC / シグナリング用の接続が大量に見える。**実際のメディア中継は rtcstats の
nominated candidate-pair の remoteCandidate から取る**。

### IPv4 のカウンタでは Meet は見えない

Meet のメディアは **IPv6 UDP** で流れる。`/proc/net/snmp` は IPv4 専用なので
パケットが 1 つも計上されない。**`/proc/net/snmp6` を見ること。**

```
awk '/Udp6RcvbufErrors/{print $2}' /proc/net/snmp6
```

同様に speedtest / ping を IPv4 で測っても Meet の経路を測ったことにならない。

### `/proc/net/snmp` のフィールド位置

`Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors`
なので `$5` は OutDatagrams。InErrors は `$4`。

### 累積カウンタを「現在の異常」と読まない

`Udp6RcvbufErrors` が 10 万件あっても、それは起動以来の累積。
**通話中の増分を測ること。** 本件は 17% ロスの最中 121 秒で増分 0 だった。

### 有線と WiFi が同一サブネットに同居すると測定が壊れる

`ping -I <iface>` の戻りが逆のインターフェイスに届き、100% ロスに見える。
インターフェイス別 A/B を取るには片方を落とす必要がある。

### speedtest-cli のサーバ自動選択

3.3 Mbit/s のような嘘の値を出す。`--server 14623`（IPA CyberLab, 文京）を指定するか、
JAIST から実ファイルを落として測る。Cloudflare の `speed.cloudflare.com/__down` は 403。

```
curl -o /dev/null -s -r 0-104857599 -w "%{time_total}s %{speed_download} B/s\n" \
  https://ftp.jaist.ac.jp/pub/Linux/ubuntu-releases/24.04/ubuntu-24.04.3-live-server-amd64.iso
```

## 3. 経路の切り分け

メッシュ構成では**バックホールの手前と向こう側に同時に ping を打つ**。

```bash
ping -D -i 0.1 -c 1200 <ノードのIP>   &   # バックホールを通らない
ping -D -i 0.1 -c 1200 <ゲートウェイ> &   # バックホール越し
```

`-D` で絶対時刻が入るので、rtcstats の損失時刻と 1 対 1 で突き合わせられる。

参考値（本件・正常時）: ノード p99 0.82ms / 親ルーター p99 6〜16ms。
ただし前述の通り**この差では Meet の可否は判定できない**。

## 4. 無線環境の確認

```bash
nmcli dev wifi rescan; sleep 5
nmcli -f SSID,BSSID,CHAN,FREQ,SIGNAL dev wifi list --rescan no | awk 'NR==1 || ($4+0)>=5000'
```

`DIRECT-*` は Wi-Fi Direct。**その MAC は本体 MAC の第 1 オクテットに locally administered
ビット (0x02) を立てただけ**のことが多い（第 1 オクテットが `24` なら Direct 側は `26`）。
残りのオクテットは同一なので、`ip neigh` の一覧と突き合わせれば有線 LAN 側の同一機体を同定できる。
本件はこれで TV を特定した。

## 5. 日本の 5GHz チャンネル

**非 DFS は W52 (ch36/40/44/48) のみ。ch48 から逃げると必ず DFS に入る。**

| バンド | チャンネル | 備考 |
| --- | --- | --- |
| W52 | 36-48 | 非 DFS・屋内限定 |
| W53 | 52-64 | DFS |
| W56 | 100-140 | DFS。**5590-5650 (ch120-128) は気象レーダー帯**（CAC 10分・誤検出多い） |

80MHz ブロック: `{36,40,44,48}` `{52,56,60,64}` `{100,104,108,112}` `{116,120,124,128}` `{132,136,140,144}`

**ch116 を選ぶと気象レーダー帯を含むので避ける。** 過去に ch116 で不安定だったのは
これが原因の可能性がある。推奨は **ch100**（占有 5490-5570、レーダー帯に不接触）。

レーダー退避が起きていないかの確認:

```bash
nmcli -f SSID,BSSID,CHAN,FREQ dev wifi list --rescan no   # チャンネルが動いていないか
journalctl -b -k | grep -iE "radar|dfs|channel switch|CSA"
```

## 6. ツール

[`meet-diag`](meet-diag) — 通話中に実行すると in/out pps、`Udp6RcvbufErrors` 増分、
NIC ドロップ、load、Chrome の CPU を 1 秒粒度で記録し、ローカル起因のドロップの有無を判定する。

```
meet-diag 120
```

通話中（40pps 以上）に RcvbufErrors が増えれば CPU 競合起因。増えなければ経路かサーバ側。
