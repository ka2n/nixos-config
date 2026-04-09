# Himmelblau Troubleshooting Guide

NixOS 固有の問題と upstream の既知問題をまとめる。

## 構成概要

- himmelblau 3.0.0 (upstream flake から)
- `hsm_type=tpm_bound_soft_if_possible` (Soft HSM + TPM-bound PIN)
- `LoadCredentialEncrypted` で systemd が HSM PIN を復号して渡す
- `himmelblau-hsm-pin-init.service` が初回のみ PIN を生成・暗号化

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
- [himmelblau-idm/himmelblau#1228](https://github.com/himmelblau-idm/himmelblau/pull/1228) — 修正 PR (未マージ、テスターから未解決との報告あり)
- 2.3.5 では問題なし

### 対処

`sudo systemctl restart himmelblaud` で一時的に復旧する。ただしキャッシュ DB が壊れている場合は問題2へ。

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

## 問題4: Intune Enrollment 失敗

### 症状

ドメイン参加は成功するが Intune enrollment が失敗する。

### ログパターン A: RequestFailed

```
himmelblaud: 🚨 [error]: Intune device enrollment failed. | e: RequestFailed("error sending request for url (https://fef.msuc06.manage.microsoft.com/.../enroll?api-version=1.0&client-version=...)")
himmelblaud: 🚨 [error]: Failed to enroll in Intune during domain join, will retry later. | e: BadRequest
```

### ログパターン B: invalid_grant

```
himmelblaud: 🚨 [error]: Acquiring token for Intune device enrollment failed. | e: ErrorResponse { error: "invalid_grant", error_description: "AADSTS70000: Provided grant is invalid or malformed." }
```

### 原因

- パターン A: ネットワーク問題、または Conditional Access ポリシーがブロック
- パターン B: キャッシュ削除後にトークンが無効化された

### 対処

再度パスワード認証 (sudo 等) を行うと enrollment がリトライされる。
enrollment は認証フロー内で自動リトライされるため、手動操作は不要。

リトライ後のログ:
```
himmelblaud: ｉ [info]: Joined domain ms365.monicle.co.jp with device id ...
himmelblaud: Successfully applied Intune policies
```

### Conditional Access のブートストラップデッドロック

Conditional Access で「デバイスコンプライアンス必須」にしていると、
enrollment 自体がブロックされる鶏卵問題が発生する。

- [himmelblau-idm/himmelblau#1132](https://github.com/himmelblau-idm/himmelblau/issues/1132)
- 対策: enrollment 用にコンプライアンス要件を一時的に緩和する、または grace period を設定する

## 問題5: TPM not in use

### 症状

`sudo aad-tool tpm` が "TPM not in use" を返す。

### 確認手順

```bash
# TPM デバイスの存在確認
ls -la /dev/tpm0 /dev/tpmrm0

# SRK がプロビジョニングされているか
tpm2_getcap handles-persistent   # 0x81000001 が必要

# himmelblaud が tss グループに所属しているか
cat /proc/$(pgrep -x himmelblaud)/status | grep Groups
getent group tss

# systemd credential が正しく渡されているか
ls /run/credentials/himmelblaud.service/
```

### 原因と対処

#### systemd credential が渡されていない

`/etc/systemd/system/himmelblaud.service` に以下が必要:

```ini
LoadCredentialEncrypted=hsm-pin:/var/lib/private/himmelblaud/hsm-pin.enc
Environment="HIMMELBLAU_HSM_PIN_PATH=/run/credentials/himmelblaud.service/hsm-pin"
```

NixOS モジュール (`modules/himmelblau/default.nix`) で設定済み。

注意: `Environment=` では systemd の `%d` specifier は展開されない。
`/run/credentials/himmelblaud.service/hsm-pin` を直接指定する必要がある。

#### hsm-pin.enc が TPM-bound でない

```bash
sudo rm -f /var/lib/private/himmelblaud/hsm-pin.enc
sudo systemctl restart himmelblau-hsm-pin-init
# ログで "HSM PIN credential created successfully" を確認
sudo systemctl restart himmelblaud
```

## NixOS モジュール固有の注意点

### himmelblau-hsm-pin-init の ConditionPathExists

`ConditionPathExists=!/var/lib/private/himmelblaud/hsm-pin.enc` により、
HSM PIN が既に存在する場合はスキップされる。これにより `nixos-rebuild switch` で
PIN が再生成されてキャッシュ DB と不整合になる問題を防いでいる。

PIN を再生成したい場合は明示的に `hsm-pin.enc` を削除する。

### DynamicUser と TPM アクセス

himmelblaud は `DynamicUser=yes` で動作する。`/dev/tpmrm0` (mode 0660, group tss) に
アクセスするため `SupplementaryGroups=tss` が必要。

### himmelblaud-tasks の IPv6 問題

himmelblaud-tasks が IPv6 で federation provider を取得しようとして失敗する場合がある。
`RestrictAddressFamilies = "AF_INET AF_UNIX"` で IPv4 + Unix のみに制限している。

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

## 問題6: Chrome で "No connection to the host tooling"

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

### 関連

- Native Messaging マニフェスト: `/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json`
- Chrome 拡張機能 ID: `jlnfnnolkbjieggibinobhkjdfbpcohn`
- himmelblau_broker (user service): `systemctl --user status himmelblau-broker`

## 関連 upstream issues

| Issue | 状態 | 概要 |
|-------|------|------|
| [#1206](https://github.com/himmelblau-idm/himmelblau/issues/1206) | Open | Suspend 復帰後のロックアウト (3.0.0 regression) |
| [#1228](https://github.com/himmelblau-idm/himmelblau/pull/1228) | Open PR | #1206 の修正 (未マージ) |
| [#895](https://github.com/himmelblau-idm/himmelblau/issues/895) | Open | NixOS: Intune policy 検証失敗 |
| [#987](https://github.com/himmelblau-idm/himmelblau/issues/987) | Closed | アップグレード後にキャッシュ削除が必要 |
| [#1132](https://github.com/himmelblau-idm/himmelblau/issues/1132) | Closed | Conditional Access が enrollment をブロック |
| [#155](https://github.com/himmelblau-idm/himmelblau/issues/155) | Closed | Suspend 後に himmelblaud が停止 (0.x 時代、修正済み) |
