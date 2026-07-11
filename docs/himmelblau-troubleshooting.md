# Himmelblau Troubleshooting Guide

NixOS 固有の問題と upstream の既知問題をまとめる。

## 構成概要

- himmelblau 3.1.9 (upstream flake から / `modules/himmelblau`)
- `hsm_type=tpm_bound_soft_if_possible` + `tpm` cargo feature 有効 → ハードウェア TPM (`/dev/tpmrm0`) を使用
- `LoadCredentialEncrypted` で systemd が HSM PIN を復号して渡す
- `himmelblau-hsm-pin-init.service` が初回のみ PIN を生成・暗号化 (`hsm-pin-nopcr.enc`, PCR 非バインド)

> NixOS モジュール固有の設定根拠 (HSM PIN init / TPM アクセス(tss) / IPv4 強制 /
> `apply_policy` 用 `/var/cache/himmelblau-policies` / Intune enrollment の `request_timeout`
> 等) は `modules/himmelblau/default.nix` と `hosts/wk2511058/configuration.nix` の
> コメントに集約している。本ガイドは運用時に踏むランタイム問題に絞る。

## 問題1: Suspend 復帰後にログインできない

### 症状

swaylock でパスワードを入力しても認証が通らない。

### ログ

```
himmelblaud: unix_user_online_auth_step [ 2.02s ] service: "swaylock"
himmelblaud: 🚨 [error]: Aes256GcmDecrypt
```

auth_step の所要時間が 2s → 4s → 6s → 8s と指数的に増加（リトライバックオフ）。

### 原因

himmelblau 3.0.0 のリグレッション。suspend 復帰時にネットワークが未回復の状態でオンライン再認証を試み、失敗すると `AuthResult::Denied` を返す。

### 関連 issue

- [himmelblau-idm/himmelblau#1206](https://github.com/himmelblau-idm/himmelblau/issues/1206) — "Resume from standby locks user out"
- 2.3.5 では問題なし

### 解決状況 (3.1.9)

**3.1.9 で根本修正済み。** resolver がオンライン認証の初期化に失敗した際、オフライン認証フォールバックに入る前に DB ロックを解放するよう修正され (`fix(resolver): release db lock before offline auth fallback to prevent deadlock`)、デッドロックの根本原因が解消された。

これに伴い、3.1.6〜で暫定導入されていた NetworkManager dispatcher ワークアラウンド (interface down 時に himmelblaud を再起動) は upstream で revert・削除され、本リポジトリの `modules/himmelblau` からも撤去した。

3.1.9 適用後もまれに症状が残る場合の一時復旧: `sudo systemctl restart himmelblaud`。キャッシュ DB が壊れている場合は問題2へ。

## 問題2: Aes256GcmDecrypt エラーでクラッシュループ

### 症状

himmelblaud が起動直後にクラッシュし、restart を繰り返す。

### ログ

```
himmelblaud: Generated new HSM pin
himmelblaud: root_storage_key_load [ 9.25µs ]
himmelblaud: 🚨 [error]: Unable to load machine root key - This can occur if you have changed your HSM pin | err: Aes256GcmDecrypt
himmelblaud: 🚨 [error]: To proceed you must remove the content of the cache db (/var/cache/himmelblaud/himmelblau.cache.db) to reset all keys
```

### 原因

HSM PIN とキャッシュ DB 内の暗号化キーが不整合。以下のケースで発生する:

1. suspend 復帰で TPM/キーリング状態がリセットされた
2. `nixos-rebuild switch` で `himmelblau-hsm-pin-init` が再実行され PIN が再生成された（修正済み）
3. サービスファイルに `LoadCredentialEncrypted` がなく、himmelblaud が毎回ランダム PIN を生成していた（修正済み）

### 対処

```bash
sudo systemctl stop himmelblaud himmelblaud-tasks
sudo rm -f /var/cache/private/himmelblaud/himmelblau.cache.db
sudo systemctl start himmelblaud
```

キャッシュ DB を削除すると以下がリセットされる:
- オフライン認証キャッシュ
- デバイス登録情報 (domain join が再実行される)
- Intune enrollment (再 enrollment が必要)
- Hello PIN (再設定が必要)

### HSM PIN も壊れている場合

```bash
sudo systemctl stop himmelblaud himmelblaud-tasks
sudo rm -f /var/cache/private/himmelblaud/himmelblau.cache.db
sudo rm -f /var/lib/private/himmelblaud/hsm-pin.enc
sudo rm -f /var/lib/private/himmelblaud/hsm-pin
sudo systemctl restart himmelblau-hsm-pin-init
sudo systemctl start himmelblaud
```

順序が重要: `himmelblau-hsm-pin-init` が完了してから `himmelblaud` を起動すること。

## 問題3: キャッシュ DB が ReadOnly で作成できない

### ログ

```
himmelblaud: 🚨 [error]: sqlite set db_version_t error: SqliteFailure(Error { code: ReadOnly, extended_code: 1032 }, Some("attempt to write a readonly database")) db_path=Some("/var/cache/private/himmelblaud/himmelblau.cache.db")
himmelblaud: 🚨 [error]: Failed to migrate database
```

### 原因

前回のクラッシュ時に不完全な DB ファイルが残り、それが readonly 状態になっている。

### 対処

問題2と同じ。キャッシュ DB を削除して再起動。

## 問題4: Chrome で "No connection to the host tooling"

### 症状

Linux Entra SSO Chrome 拡張機能 (v1.8.0) のポップアップに以下が表示される。

```
No connection to the host tooling. Please read the installation guide to learn how to install it.
```

### 根本原因

2つの問題が連鎖している。

**① linux-entra-sso バイナリのバグ (himmelblau 3.1.1)**

`acquirePrtSsoCookie` リクエストに対して himmelblaud が `NotFound` を返したとき、
バイナリがエラーレスポンスを Chrome に送信せずにクラッシュして終了する。

```
run_as_native_messaging failed: Failure("EOF while parsing a value at line 1 column 0")
```

Chrome は Native Messaging ポートの切断 (`onDisconnect`) を検知し、
`nm_connected = false` → "No connection to the host tooling" を表示する。

**② PRT が refresh_cache に存在しない**

himmelblaud のログ:

```
unix_user_prt_cookie [ 5.62µs ]
🚨 [error]: Failed to fetch prt sso cookie: NotFound { what: "account_id", where_: "refresh_cache" }
```

`getAccounts` はアカウントを返す (account cache には存在する) が、
PRT (Primary Refresh Token) が refresh_cache にないため SSO cookie を発行できない。

### 診断手順

```bash
# アカウントが存在することを確認
linux-entra-sso -i getAccounts

# PRT 取得を試して失敗するか確認（プロセスが終了する）
python3 -c "
import subprocess, struct, json, select
proc = subprocess.Popen(['linux-entra-sso'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
send = lambda cmd: proc.stdin.write(struct.pack('<I', len(msg := json.dumps(cmd).encode())) + msg) or proc.stdin.flush()
recv = lambda: json.loads(proc.stdout.read(struct.unpack('<I', proc.stdout.read(4))[0]))
print(recv())   # brokerStateChanged: online のはず
send({'command': 'acquirePrtSsoCookie', 'account': {...}, 'ssoUrl': 'https://login.microsoftonline.com/'})
print(recv())   # EOF → バイナリ終了 = PRT なし
"

# himmelblaud ログで確認
journalctl -u himmelblaud --since "5 min ago" | grep -E "prt|refresh_cache"
```

### 対処

**PRT を取得する（Entra ID で再認証）**

PRT は Entra ID 認証時に取得・キャッシュされる。以下のコマンドで再認証をトリガーする。

```bash
sudo aad-tool status
```

Hello PIN の入力を求められるので入力する。
himmelblaud が PRT を取得・キャッシュした後、Chrome の拡張機能ポップアップで接続が確立される。

### Native Messaging の動作確認

```bash
# マニフェストの存在確認
cat /etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json

# バイナリが正常動作するか確認
linux-entra-sso -i getAccounts
linux-entra-sso -i getVersion
```

### upstream の状況

**linux-entra-sso が NotFound でクラッシュ（EOF）する問題**は、明示的に報告された issue がない。
PRT が refresh_cache にない根本原因は [#1107](https://github.com/himmelblau-idm/himmelblau/issues/1107) (Open) で追跡されている。
メンテナーのコメント:「パスワード認証でのオフライン SSO は未実装。Hello PIN でのみ動作する。」

**PRT のサービス再起動時の消失**は [PR #1214](https://github.com/himmelblau-idm/himmelblau/pull/1214) (Merged to main) で修正された。
systemd の FD Store を使って PRT をデーモン再起動間で保持する (`modules/himmelblau` で FDStore を有効化済み)。

### 関連

- Native Messaging マニフェスト: `/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json`
- Chrome 拡張機能 ID: `jlnfnnolkbjieggibinobhkjdfbpcohn`
- himmelblau_broker (user service): `systemctl --user status himmelblau-broker`

## 問題5: ロック解除後に画面復帰が遅い (iwlmld MLO scan WARNING)

### 症状

swaylock で PIN を入力 → himmelblau の認証は瞬殺で完了するが、デスクトップが再表示されるまで体感数秒〜十数秒のラグがある。画面オフではなくロック画面は出ている状態。

### ログ

```
kernel: ------------[ cut here ]------------
kernel: Last MLO scan was too long ago, can't select links
kernel: WARNING: drivers/net/wireless/intel/iwlwifi/mld/mlo.c:948
        at _iwl_mld_select_links+0x291/0x870 [iwlmld]
kernel: Workqueue: events_unbound cfg80211_wiphy_work [cfg80211]
kernel: Call Trace:
kernel:  iwl_mld_handle_scan_complete_notif+0x2db/0x300 [iwlmld]
kernel:  iwl_mld_async_handlers_wk+0xe7/0x160 [iwlmld]
```

himmelblaud 側のタイミングは正常 (`pam authenticate step` 200ms 程度で成功) なのに体感が遅いのが目印。

### 原因

Intel Wi-Fi 7 (BE 系: BE200/BE201/BE202) ドライバ `iwlmld` の MLO (Multi-Link Operations) スキャン管理バグ。

- `_iwl_mld_select_links()` が「直前の MLO スキャンが 5 秒以上前」だと WARN を投げる
- ロック中に Wi-Fi がアイドルになるとこの条件を踏み、解除直後の再アソシエーションが遅延
- 解除後に動く NetworkManager / waybar / mako 等が Wi-Fi 復帰待ちで一時固まる
- カーネル v7.0 commit [`ec66ec6a5a8f`](https://github.com/torvalds/linux/commit/ec66ec6a5a8f) "wifi: iwlwifi: mld: Fix MLO scan timing" で根本修正は入っているが、**長時間アイドル後の復帰では依然 5s 経過条件に引っかかる**

ハードウェア確定例: ThinkPad 21NS (Lunar Lake / Core Ultra 200V 系)。

### 関連リンク

- [Patchwork: wifi: iwlwifi: mld: always do MLO scan before link selection](https://patchwork.kernel.org/project/linux-wireless/patch/20250308235203.a4c96e5c49d4.Ie55697af49435c2c45dccf7c607de5857b370f7a@changeid/)
- [Linux commit ec66ec6a5a8f — Fix MLO scan timing (v7.0 含)](https://github.com/torvalds/linux/commit/ec66ec6a5a8f)
- [Intel Community: BE200 kernel warning and system freeze](https://community.intel.com/t5/Wireless/Intel-Wi-Fi-7-BE200-320MHz-kernel-warning-and-system-freeze/td-p/1703035)
- [Intel Community: Does Linux kernel 6.11 support MLO with BE200?](https://community.intel.com/t5/Wireless/Does-Linux-kernel-6-11-support-MLO-with-be200/td-p/1636306)
- [Manjaro: 6.15-rc7 not loading iwlwifi for BE200](https://forum.manjaro.org/t/6-15-rc7-not-loading-iwlwifi-for-be200-320mhz-anymore/178376)
- [Void Linux: Intel BE200 wifi not detected (iwlmld 移行問題) #56644](https://github.com/void-linux/void-packages/issues/56644)
- [NixOS: iwlwifi firmware load issues #454246](https://github.com/NixOS/nixpkgs/issues/454246)

### 対処

`iwlwifi` の `disable_11be=1` で Wi-Fi 7 / 802.11be (EHT) 自体を無効化し、MLO リンク選択ロジックを通さない。`mlo_capable` のような modparam は **存在しない** ので注意。

```nix
# hosts/wk2511058/configuration.nix
boot.extraModprobeConfig = ''
  options iwlwifi disable_11be=1
'';
```

副作用: 物理レイヤは Wi-Fi 6E/6 にフォールバック。MLO の同時複数リンクは使えなくなるが、シングルリンク BE 速度は維持されるケースがほとんど。

### 確認

```bash
# 再ビルド・再起動後
sudo dmesg | grep -i "Last MLO scan"   # 出ないこと
sudo iw dev | grep -E "type|channel"    # ssid 接続を確認
journalctl -k --since "1 hour ago" | grep -iE "iwlwifi|iwlmld" | head
```

### 関連 himmelblau ログとの切り分け

himmelblaud の `pam authenticate step` が 200ms 程度で成功しているのに体感が遅い場合は本問題。`Aes256GcmDecrypt` が出ている場合は問題1/2/6、`Hello key missing` / PRT 関連が出ている場合は問題4 を参照。

## 問題6: バージョンアップ直後の Aes256GcmDecrypt (libhimmelblau bump 起因)

### 症状

himmelblau パッケージのバージョンアップ後、しばらく(数時間〜)正常に動作した後に突然 `Aes256GcmDecrypt` が出始める。問題2 と同じエラー名だが、**前置きの `Unable to load machine root key` / `To proceed you must remove the content of the cache db` が出ない**点で区別できる。

`pam authenticate` がリトライバックオフで 2s → 4s → 6s → 8s と伸びる挙動も同じだが、引き金がパッケージバージョンアップにある。

### ログ (問題2 との違い)

```
himmelblaud: pam authenticate step [ 2.05s ] service: "swaylock"
himmelblaud:   └━ 🚨 [error]: Aes256GcmDecrypt
```

問題2 のような次の前置きが**出ない**:
- `Unable to load machine root key - This can occur if you have changed your HSM pin`
- `To proceed you must remove the content of the cache db ... to reset all keys`
- `Generated new HSM pin`

これは `Aes256GcmDecrypt` が HSM key 読み込み経路ではなく、**libhimmelblau 内部の AEAD 復号経路から**発火しているため。

### 原因

`libhimmelblau` (内部 crypto/auth library) の minor version bump で AEAD キャッシュフォーマット/key derivation が破壊的に変わることがある。旧 lib で書かれた cache を新 lib が復号できず、AES-GCM タグ検証で失敗する。

実例: 2026-05-07 の `himmelblau 3.1.1 → 3.1.3` bump で `Cargo.toml` の `libhimmelblau` が `0.8.13 → 0.8.18` に jump。切替後 boot 内で発症(数時間後、token refresh で初めて cache 本格利用したタイミング)。

### 問題2 との切り分け

| | 問題2 (HSM PIN drift) | 問題6 (lib bump cache incompat) |
|---|---|---|
| `Unable to load machine root key` | あり | **なし** |
| `Generated new HSM pin` | あり | なし |
| 直前のトリガー | suspend / PIN 再生成 | パッケージバージョンアップ |
| 修復方法 | cache 削除(HSM PIN 再生成も可) | **cache 削除のみ** |

### 対処

**HSM PIN は触らない。**消すと device 新規 join が走り、Entra/Intune 側で古い device record と衝突する事故が起きる:

```bash
sudo systemctl stop himmelblaud himmelblaud-tasks
sudo rm -f /var/cache/private/himmelblaud/himmelblau.cache.db \
           /var/cache/private/himmelblaud/himmelblau.cache.db-wal \
           /var/cache/private/himmelblaud/himmelblau.cache.db-shm
sudo systemctl start himmelblaud himmelblaud-tasks
# 次の sudo / 画面ロック解除でオンライン認証 → cache 自動再構築
```

cache 削除によるリセット範囲:
- オフライン認証キャッシュ
- デバイス登録情報 (domain join が再実行される)
- Intune enrollment (再 enrollment が必要)
- Hello PIN (再設定が必要)

### upstream 状況 (2026-05-09 時点)

- 該当する upstream issue は**未登録**。`Aes256GcmDecrypt` / `cache decrypt` / `0.8.18` で横断検索しても hit せず
- 関連 issue:
  - [#987](https://github.com/himmelblau-idm/himmelblau/issues/987) — 1.x → 2.x で類似事象。原因は旧 systemd unit の残存(本問題と別系統)。`src/daemon/scripts/postinst` で対処済み
- distro パッケージも lib bump 時に cache wipe しない構造:
  - `platform/debian/scripts/postinst` — AppArmor patch + krb5 + pam-auth-update のみ
  - `platform/el/`, `platform/opensuse/` — postinst 自体なし
  - `src/daemon/scripts/postinst` (共通) — HSM PIN migration と旧 unit 削除のみで cache に触れない
- 内部 DB 側 schema は `db_version_t` で migration するが、AES envelope の**内側**にあるため AEAD 段で詰むと到達しない
- NixOS module 側で `package.version` を stamp した自動 wipe を入れる選択は妥当(本リポジトリでは未実装)

### 予防と再発時の手順

1. バージョンアップ commit 時に `flake.lock` 内の libhimmelblau 関連変更を確認
2. 問題発生時は **まず問題2との切り分け**(HSM root key load エラーの有無)を行う
3. HSM PIN まで消す前に、本問題6 のパターン(エラー前置きなし、直近に bump)に該当しないか確認
4. cache 削除のみで治った場合、Entra/Intune 側で stale device の確認(古い device id が残っていれば削除)

## デバッグ方法

### debug ログの有効化

`services.himmelblau.debugFlag = true` に設定して rebuild。

### 関連サービスのログ確認

```bash
# himmelblaud 本体
journalctl -u himmelblaud --since "10 min ago"

# タスクデーモン (Intune policy 適用等)
journalctl -u himmelblaud-tasks --since "10 min ago"

# HSM PIN 初期化
journalctl -u himmelblau-hsm-pin-init --since "10 min ago"

# suspend/resume 周辺のログ
journalctl -u systemd-logind --since "10 min ago"

# エラーのみ抽出
journalctl -u himmelblaud --since "10 min ago" -p err
```

## 関連 upstream issues

| Issue | 状態 | 概要 |
|-------|------|------|
| [#1107](https://github.com/himmelblau-idm/himmelblau/issues/1107) | Open | オフラインパスワード認証後に SSO 不可 (PRT が refresh_cache にない) |
| [#1206](https://github.com/himmelblau-idm/himmelblau/issues/1206) | Fixed (3.1.9) | Suspend 復帰後のロックアウト。resolver の DB ロック解放で根本修正、NM dispatcher ワークアラウンドは revert |
| [#895](https://github.com/himmelblau-idm/himmelblau/issues/895) | Open | NixOS: Intune policy 検証失敗 |
| [#1214](https://github.com/himmelblau-idm/himmelblau/pull/1214) | Merged (main) | PRT を systemd FD Store に保持 |
| [#1154](https://github.com/himmelblau-idm/himmelblau/pull/1154) | Merged | broker: passwordExpiry 修正 |
| [#1201](https://github.com/himmelblau-idm/himmelblau/pull/1201) | Merged | PRT nonce 修正 |
| [#987](https://github.com/himmelblau-idm/himmelblau/issues/987) | Closed | アップグレード後にキャッシュ削除が必要 |
| [#1132](https://github.com/himmelblau-idm/himmelblau/issues/1132) | Closed | Conditional Access が enrollment をブロック |
| [#155](https://github.com/himmelblau-idm/himmelblau/issues/155) | Closed | Suspend 後に himmelblaud が停止 (0.x 時代、修正済み) |
