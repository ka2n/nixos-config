# Wi-Fi 7 (MLO) による Zoom/Meet のパケロス

## 症状

- wk2511058 (Intel BE201 / iwlwifi) で Zoom・Google Meet など WebRTC 通話が
  断続的に 20% 級のパケロス + 高ジッタ。音声・映像とも不安定。

## 切り分けで分かったこと（重要な罠）

クライアント側の指標は**すべて 0%** で、ping/mtr でも一切再現しない:

| レイヤー | 結果 |
| --- | --- |
| Wi-Fi PHY (`iw station dump`) | tx retries 0 / tx failed 0 |
| 受信エラー (`ip -s link`) | rx errors 0 / drop 0 |
| カーネル UDP 配送 (`/proc/net/snmp(6)`) | RcvbufErrors の増加なし（30〜60s 観測で 0） |
| 経路 (ping / mtr to 8.8.8.8 / zoom SFU) | 0% ロス・低遅延安定 |
| 信号 | -33〜-44 dBm（極めて良好） |

→ パケットは端末に届くまで 1 つも落ちていない。WebRTC だけが
「遅延到着 / 順序乱れ」をロス計上していた。低レート小パケットの ICMP は
無傷ですり抜けるため **ping では絶対に再現しない**。

## 原因

**AP 側の MLO (Multi-Link Operation)**。Wi-Fi 7 自体は無罪。

このクライアントは `disable_11be=1`（後述）で HE (Wi-Fi 6) 接続しており MLO を
直接は使わない。だが **AP が MLO 有効だと、無線機を共有する HE クライアントへの
下りスケジューリングが乱れ**、クライアント側カウンタに現れない死角ロスになる。

### 1 変数ずつの切り分け結果

| ルーター設定 | 結果 |
| --- | --- |
| Wi-Fi7 ON + MLO ON | パケロスひどい |
| Wi-Fi7 OFF + MLO OFF | 安定（ただし Wi-Fi7 の速度を捨てる） |
| **Wi-Fi7 ON + MLO OFF** | **安定（最良。速度維持。Meet/Zoom 安定確認）** |

チャンネル (ch48→100→116, いずれ DFS) や Wi-Fi7 そのものは要因ではなかった。

## 対処

**ルーター (ASUS RT-BE18000) で MLO だけ無効化。Wi-Fi7 は ON のままでよい。**

クライアント側は既に Wi-Fi7/EHT を無効化済み（`hosts/wk2511058/configuration.nix`）:

```nix
boot.extraModprobeConfig = ''
  options iwlwifi disable_11be=1 power_save=0
'';
```

ランタイム確認: `cat /sys/module/iwlwifi/parameters/disable_11be` → `Y`

## 再発時のデバッグ手順

1. `about:webrtc`（Firefox/Zen）の `inbound-rtp packetsLost` で送受信どちらの
   ストリームがロスしているか、選択 ICE candidate pair（host/relay）を確認。
2. WebRTC が示す実 SFU の remote IP へ `mtr` を撃ち経路ロスを切り分け。
3. クライアント側カウンタ（`iw station dump` / `/proc/net/snmp`）が全 0% なら
   AP 側スケジューリングを疑う（= 本件）。
