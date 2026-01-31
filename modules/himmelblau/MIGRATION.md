# Himmelblau モジュール移行計画

## 移行の目的

### 主目的: パッケージキャッシュの活用

**現在の問題:**
- カスタムパッケージ (`modules/himmelblau/package.nix`) をビルドするため、**ビルド時間が長い**
- Rust のコンパイルが毎回必要

**解決策:**
- 公式リポジトリのパッケージを使用
- **Cachix バイナリキャッシュ** を活用してビルドをスキップ

**Cachix キャッシュ:**
```sh
$ nix profile install 'nixpkgs#cachix'
$ cachix use himmelblau
```

公式ビルドは CI で署名済みバイナリとして Cachix にアップロードされるため、ローカルでのビルドが不要になります。

### 副次的なメリット

- 上流の変更を自動追従
- 100+ の型付き設定オプションへのアクセス（オプション）
- O365/Teams 統合サポート（オプション）
- コミュニティテストとバグフィックス

### モジュールについて

**重要:** カスタムモジュールでの override は問題ありません。

- 公式モジュールを完全に採用する必要はない
- **パッケージのみ公式のものを使用**することが最重要
- モジュールは既存のカスタム実装を維持して、必要な箇所を override する方針も可

## 現状分析

### カスタム実装の特徴

**場所:** `/home/k2/nixos-config/modules/himmelblau/`

**ファイル構成:**
- `default.nix` - NixOS モジュール (235行)
- `package.nix` - パッケージ定義 (134行)

**主な特徴:**
1. **設定:** ハードコード文字列ベースの設定ファイル生成
2. **TPM サポート:** tpm2-tss を使用した TPM binding
3. **IPv6 回避策:** `RestrictAddressFamilies = AF_INET AF_UNIX` で IPv6 無効化 (default.nix:227)
4. **PAM 統合:** passwd, login, sudo, doas, sshd に対応
5. **ブラウザ SSO:** Chrome, Chromium, Firefox の native messaging host
6. **Zen Browser 統合:** Firefox ベースの Zen Browser 用に拡張とnative messaging host を設定 (home/default.nix:5-17, 526)
7. **カスタム設定:**
   - `tss` グループの明示的追加 (default.nix:196)
   - `/var/cache/himmelblau-policies` の書き込み権限 (default.nix:224)
   - Capability bounding set の明示設定 (default.nix:228-229)

### 公式実装の利点

**リポジトリ:** https://github.com/himmelblau-idm/himmelblau

**クローン済み:** `/home/k2/nixos-config/external-docs/himmelblau/`

**主な利点:**
1. **型付きオプション:** 100+ の設定オプションが型安全に利用可能
2. **自動生成:** XML ドキュメントから `scripts/gen_param_code.py` で生成
3. **2つのバリアント:** 標準版と desktop 版 (O365/Teams サポート)
4. **ブラウザ統合:** Firefox 拡張の自動インストール (ポリシーベース)
5. **保守性:** 上流の変更を自動追従
6. **ドキュメント:** 全オプションの説明、デフォルト値、例が含まれる

**詳細分析:**
- `external-docs/himmelblau-analysis/README.md` - 要約
- `external-docs/himmelblau-analysis/COMPARISON.md` - 技術比較 (551行)

## 移行戦略

### 推奨アプローチ: パッケージ優先移行

**フェーズの優先順位:**

1. **フェーズ 0 (必須): Cachix セットアップ** - バイナリキャッシュの有効化
2. **フェーズ 2 (最重要): パッケージ切り替え** - ビルド時間の短縮
3. **フェーズ 1 (オプション): 型付きオプション** - 設定の型安全性向上
4. **フェーズ 3 (オプション): 公式モジュール採用** - または必要に応じて override

**理由:**
- **パッケージキャッシュの活用が最優先** - ビルド時間を劇的に短縮
- モジュールはカスタムのままでも問題ない
- 型付きオプションや公式モジュールは必要に応じて後から検討

## フェーズ 0: Cachix セットアップ (必須)

**目的:** 公式パッケージのバイナリキャッシュを有効化

**期間:** 5分

### 0.1 Cachix のインストールと設定

```bash
# Cachix のインストール
nix profile install 'nixpkgs#cachix'

# Himmelblau キャッシュの有効化
cachix use himmelblau
```

これで `~/.config/nix/nix.conf` または `/etc/nix/nix.conf` に以下が追加されます:

```
extra-substituters = https://himmelblau.cachix.org
extra-trusted-public-keys = himmelblau.cachix.org-1:...
```

### 0.2 動作確認

```bash
# キャッシュが有効か確認
nix show-config | grep substituters

# 以下のような出力が表示されるはず:
# extra-substituters = https://himmelblau.cachix.org ...
```

**検証項目:**
- [ ] Cachix がインストールされている
- [ ] himmelblau キャッシュが設定に追加されている
- [ ] substituters に himmelblau.cachix.org が含まれている

## Zen Browser について

### 現在の実装

Zen Browser (Firefox ベース) を使用しており、以下の設定がされている:

**場所:** `home/default.nix`

```nix
# 5-17行目: Zen Browser の wrap と拡張インストール
zenBrowser = pkgs.wrapFirefox ... {
  extraPolicies = lib.optionalAttrs hasHimmelblau {
    ExtensionSettings = {
      "linux-entra-sso@example.com" = {
        install_url = "https://github.com/siemens/linux-entra-sso/releases/download/v1.7.1/linux_entra_sso-1.7.1.xpi";
        installation_mode = "normal_installed";
      };
    };
  };
};

# 523-528行目: Firefox の設定を Zen Browser に override
programs.firefox = {
  enable = true;
  nativeMessagingHosts = [ pkgs.tridactyl-native ]
    ++ lib.optional hasHimmelblau himmelblauPkg.firefoxNativeMessagingHost;
  package = zenBrowser;
  configPath = ".zen";
};
```

### 公式モジュールとの統合

公式の himmelblau モジュールは `programs.firefox.policies` を使用するが、Zen Browser は別の package なので:

**戦略:**
1. 公式モジュールの Firefox 拡張設定は **そのまま有効化** (標準 Firefox にも対応)
2. Zen Browser 用の設定は **home-manager で追加** (現在と同じ方法)
3. Native messaging host は両方で共有可能

**フェーズ 3 での設定例:**
```nix
# システム側 (NixOS module)
services.himmelblau = {
  enable = true;
  # 公式モジュールが Firefox 用の policies を自動設定
};

# ユーザー側 (home-manager)
# hasHimmelblau の判定を維持
let
  hasHimmelblau = config.services.himmelblau.enable or false;
  zenBrowser = pkgs.wrapFirefox ... {
    extraPolicies = lib.optionalAttrs hasHimmelblau {
      # Zen Browser 用にも同じ拡張を設定
      ExtensionSettings = {
        "linux-entra-sso@example.com" = {
          install_url = "https://github.com/siemens/linux-entra-sso/releases/download/v1.7.1/linux_entra_sso-1.7.1.xpi";
          installation_mode = "normal_installed";
        };
      };
    };
  };
in {
  programs.firefox = {
    package = zenBrowser;
    # Native messaging host は公式モジュールが提供
  };
}
```

## フェーズ 2: 上流パッケージへの移行 (最重要)

**目的:** 公式の flake を使用してパッケージを取得し、**Cachix キャッシュを活用**

**期間:** 1日

**効果:** ビルド時間が大幅に短縮される（Rust コンパイルが不要）

### 2.1 Flake input の追加

`flake.nix` の himmelblau input を更新:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # 既存の stable-2.x ブランチから main に変更（または適切なバージョンを指定）
    himmelblau.url = "github:himmelblau-idm/himmelblau";
    # または特定バージョンをピン: "github:himmelblau-idm/himmelblau/v3.0.0"
    # 既存の inputs...
  };

  outputs = { self, nixpkgs, himmelblau, ... }@inputs: {
    # ...
  };
}
```

### 2.2 カスタムモジュールの更新

**オプション A: パッケージのみ差し替え（最小限の変更、推奨）**

`modules/himmelblau/default.nix` を修正:

```nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.azure-entra;
  # 上流パッケージを使用（Cachix キャッシュを活用）
  himmelblauPkg = inputs.himmelblau.packages.${pkgs.system}.himmelblau;
  # または desktop 版: inputs.himmelblau.packages.${pkgs.system}.himmelblau-desktop
in {
  options.services.azure-entra = {
    package = lib.mkOption {
      type = lib.types.package;
      default = himmelblauPkg;
      description = "Himmelblau package to use";
    };
    # 既存のオプションをそのまま維持...
  };

  config = lib.mkIf cfg.enable {
    # 既存の config をそのまま維持...
  };
}
```

**削除するファイル:**
```bash
# package.nix は不要になる
cd /home/k2/nixos-config/modules/himmelblau
mkdir archive
mv package.nix archive/
```

**オプション B: 公式モジュールを import して override（より高度）**

```nix
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.himmelblau.nixosModules.himmelblau
  ];

  # 公式モジュールの設定を使いつつ、必要な箇所を override
  services.himmelblau = {
    enable = lib.mkDefault config.services.azure-entra.enable;
    # ... 必要な設定
  };

  # IPv6 問題などのカスタマイズ
  systemd.services.himmelblaud-tasks.serviceConfig = {
    RestrictAddressFamilies = lib.mkForce "AF_INET AF_UNIX";
    ReadWritePaths = lib.mkAfter [ "/var/cache/himmelblau-policies" ];
  };

  # services.azure-entra を services.himmelblau にマッピングするエイリアス
  options.services.azure-entra = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config.services.himmelblau.enable = lib.mkIf config.services.azure-entra.enable true;
}
```

### 2.3 オプションモジュールの作成 (フェーズ 1 からの内容、オプション)

公式の `himmelblau-options.nix` を参考に、必要なオプションを抽出:

**作業:**
1. `options.nix` を新規作成
2. 以下のオプションを型付きで定義:
   - `domain` (listOf str)
   - `debug` (bool)
   - `enable_hello` (bool)
   - `enable_experimental_mfa` (bool)
   - `enable_sfa_fallback` (bool)
   - `hello_pin_min_length` (int)
   - `cn_name_mapping` (bool)
   - `local_groups` (listOf str)
   - `hsm_type` (enum)
   - `idmap_range` (str)
   - `cache_timeout` (int)
   - `offline_breakglass` (submodule)
   - その他、現在の設定で使用している全オプション

**参考ファイル:**
```
external-docs/himmelblau/nix/modules/himmelblau-options.nix
```

### 1.3 INI 生成関数の実装

`default.nix` に以下を追加:

```nix
let
  # 値を INI 形式に変換
  toIniValue = v:
    if v == null then null
    else if lib.isBool v then (if v then "true" else "false")
    else if lib.isList v then lib.concatStringsSep "," v
    else toString v;

  # null 値を除外
  filterNulls = lib.filterAttrs (n: v: v != null);

  # INI セクションに変換
  toIniSettings = settings:
    let
      isSubsection = n: v: lib.isAttrs v && !(lib.isList v);
      globalOpts = lib.filterAttrs (n: v: !(isSubsection n v)) settings;
      subsections = lib.filterAttrs isSubsection settings;

      globalSection = lib.mapAttrs (n: v: toIniValue v) (filterNulls globalOpts);
      convertedSubsections = lib.mapAttrs (sectionName: sectionOpts:
        lib.mapAttrs (n: v: toIniValue v) (filterNulls sectionOpts)
      ) subsections;
    in
      { global = globalSection; } // convertedSubsections;

  # generators.toINI を使用して文字列化
  iniConfig = pkgs.formats.ini { }.generate "himmelblau.conf" (toIniSettings cfg.settings);
in
```

### 1.4 設定ファイル生成の置き換え

**現在 (default.nix:71-106):**
```nix
environment.etc."himmelblau/himmelblau.conf".text = ''
  [global]
  apply_policy = true
  # ... ハードコード値
'';
```

**変更後:**
```nix
environment.etc."himmelblau/himmelblau.conf".source = iniConfig;
```

### 1.5 デフォルト設定の移行

`cfg.settings` のデフォルト値として、現在のハードコード値を設定:

```nix
services.azure-entra.settings = lib.mkDefault {
  apply_policy = true;
  authority_host = "login.microsoftonline.com";
  broker_socket_path = "/var/run/himmelblaud/broker_sock";
  cache_timeout = 300;
  cn_name_mapping = true;
  connection_timeout = 30;
  db_path = "/var/cache/himmelblaud/himmelblau.cache.db";
  debug = cfg.debugFlag;
  domain = [ (builtins.head privateConfig.domains) ];
  # ... 残りの設定
  offline_breakglass = {
    enabled = true;
    ttl = "7d";
  };
};
```

### 1.6 テスト

```bash
# ビルドテスト
nixos-rebuild build

# 設定ファイル確認
cat /etc/himmelblau/himmelblau.conf

# 動作確認 (ビルド成功後、実環境でテスト)
systemctl status himmelblaud
systemctl status himmelblaud-tasks
```

**検証項目:**
- [ ] 設定ファイルが正しく生成される
- [ ] サービスが正常に起動する
- [ ] 認証が動作する
- [ ] ブラウザ SSO が動作する

## フェーズ 1: 型付きオプションの導入 (オプション)

**目的:** 設定を型付きオプションに移行（型安全性の向上）

**期間:** 1-2日

**優先度:** 低 - パッケージキャッシュの活用（フェーズ 2）の後で検討

**注意:**
- Zen Browser の設定は home-manager にあるため、このフェーズでは影響なし
- このフェーズは**スキップ可能** - 既存の設定のままで問題ない

### 1.1 準備作業

```bash
cd /home/k2/nixos-config/modules/himmelblau
```

### 1.2 オプションモジュールの作成

`flake.nix` に himmelblau を追加:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    himmelblau.url = "github:himmelblau-idm/himmelblau";
    # 既存の inputs...
  };

  outputs = { self, nixpkgs, himmelblau, ... }@inputs: {
    # ...
  };
}
```

### 2.2 パッケージの切り替え

**オプション A: パッケージのみ使用 (モジュールはカスタムのまま)**

`modules/himmelblau/default.nix` を修正:

```nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.azure-entra;
  # 上流パッケージを使用
  himmelblauPkg = inputs.himmelblau.packages.${pkgs.system}.himmelblau;
in {
  options.services.azure-entra = {
    package = lib.mkOption {
      type = lib.types.package;
      default = himmelblauPkg;
      description = "Himmelblau package to use";
    };
    # 既存のオプション...
  };
  # 既存の config...
}
```

**削除するファイル:**
- `modules/himmelblau/package.nix` (不要になる)

### 2.3 カスタマイズが必要な箇所の対応

#### IPv6 問題の対応

上流のモジュールが IPv6 問題に対応していない場合、overlay で対応:

**方法 1: systemd override を使用 (推奨)**

`modules/himmelblau/default.nix` で:

```nix
systemd.services.himmelblaud-tasks.serviceConfig = {
  # IPv6 接続エラーを回避するため IPv4 のみに制限
  RestrictAddressFamilies = lib.mkForce "AF_INET AF_UNIX";
};
```

**方法 2: パッケージに overlay を適用**

```nix
nixpkgs.overlays = [
  (final: prev: {
    himmelblau = prev.himmelblau.overrideAttrs (oldAttrs: {
      # 必要に応じてカスタマイズ
    });
  })
];
```

#### 追加の ReadWritePaths

```nix
systemd.services.himmelblaud-tasks.serviceConfig = {
  ReadWritePaths = lib.mkAfter [
    "/var/cache/himmelblau-policies"
  ];
};
```

### 2.4 home-manager の更新

**Zen Browser 用に `hasHimmelblau` の判定を更新:**

`home/default.nix` を修正:

```nix
# 変更前
{ config, pkgs, inputs, lib, osConfig ? null, variant ? "desktop"
, himmelblauPkg ? null, ... }:
let
  hasHimmelblau = himmelblauPkg != null;

# 変更後
{ config, pkgs, inputs, lib, osConfig ? null, variant ? "desktop"
, himmelblauPkg ? null, ... }:
let
  # システム側で himmelblau が有効か、またはパッケージが渡されているか
  hasHimmelblau = (osConfig.services.azure-entra.enable or false) || (himmelblauPkg != null);
```

**Native messaging host の参照を更新:**

```nix
# 変更前
nativeMessagingHosts = [ pkgs.tridactyl-native ]
  ++ lib.optional hasHimmelblau himmelblauPkg.firefoxNativeMessagingHost;

# 変更後
nativeMessagingHosts = [ pkgs.tridactyl-native ]
  ++ lib.optional hasHimmelblau (
    if himmelblauPkg != null
    then himmelblauPkg.firefoxNativeMessagingHost
    else osConfig.services.azure-entra.package.firefoxNativeMessagingHost
  );
```

### 2.5 テスト

```bash
# flake lock 更新
nix flake lock --update-input himmelblau

# ビルドテスト（Cachix から取得されるはず）
nixos-rebuild build

# Cachix キャッシュが使われたか確認
# ビルドログに "copying path ... from 'https://himmelblau.cachix.org'" が表示されるはず
# ローカルビルドされた場合は "building ..." が表示される

# パッケージ確認
nix path-info /nix/store/*-himmelblau-*
```

**キャッシュヒット確認:**

ビルドが数秒〜数十秒で完了すれば、Cachix キャッシュが使われています。
数分かかる場合は、ローカルでビルドされています。

**検証項目:**
- [ ] **Cachix キャッシュからパッケージが取得される** (最重要)
- [ ] 上流パッケージが正しくインストールされる
- [ ] バイナリが正しい場所にインストールされる
- [ ] サービスが正常に起動する
- [ ] 認証が動作する
- [ ] IPv6 問題が発生しない
- [ ] Zen Browser の拡張がインストールされる
- [ ] Zen Browser の native messaging host が動作する

**トラブルシューティング:**

キャッシュが使われない場合:
```bash
# substituters を再確認
nix show-config | grep himmelblau

# 手動でキャッシュから取得を試行
nix build 'github:himmelblau-idm/himmelblau#himmelblau' --print-build-logs
```

## フェーズ 3: 公式モジュールの完全採用 (オプション)

**目的:** 公式の NixOS モジュールを使用（または必要に応じて override）

**期間:** 1-2日

**優先度:** 低 - カスタムモジュールでの override で十分な場合はスキップ可

**注意:** カスタムモジュールで公式モジュールを override する方針も可

### 3.1 モジュールの切り替え

#### 3.1.1 公式モジュールの import

`flake.nix` または対応する設定ファイルで:

```nix
imports = [
  inputs.himmelblau.nixosModules.himmelblau
];
```

#### 3.1.2 設定の移行

**カスタムモジュール (`modules/himmelblau/default.nix`) の設定を公式モジュールに移行:**

**変更前:**
```nix
services.azure-entra = {
  enable = true;
  debugFlag = true;
  pamServices = [ "passwd" "login" ];
  browserSso.firefox = true;
  userMap = { katsuma = "katsuma@example.onmicrosoft.com"; };
};
```

**変更後:**
```nix
services.himmelblau = {
  enable = true;
  debugFlag = true;
  pamServices = [ "passwd" "login" ];

  settings = {
    domain = [ "example.onmicrosoft.com" ];
    debug = true;
    enable_hello = true;
    enable_experimental_mfa = true;
    enable_sfa_fallback = true;
    cn_name_mapping = true;
    local_groups = [ "users" "networkmanager" "wheel" "docker" "uinput" ];
    hsm_type = "tpm_bound_soft_if_possible";
    idmap_range = "5000000-5999999";
    apply_policy = true;
    authority_host = "login.microsoftonline.com";
    cache_timeout = 300;
    connection_timeout = 30;
    hello_pin_min_length = 6;
    join_type = "join";
    selinux = false;
    shell = "/run/current-system/sw/bin/bash";
    use_etc_skel = false;

    offline_breakglass = {
      enabled = true;
      ttl = "7d";
    };
  };
};

# User mapping (公式モジュールが対応していない場合)
environment.etc."himmelblau/user-map".text = lib.concatStringsSep "\n"
  (lib.mapAttrsToList (local: upn: "${local}:${upn}") {
    katsuma = "katsuma@example.onmicrosoft.com";
  });
```

#### 3.1.3 カスタム設定の overlay

公式モジュールでサポートされていない設定:

**NixOS 側 (システム全体の設定):**

```nix
# IPv6 問題の回避
systemd.services.himmelblaud-tasks.serviceConfig = {
  RestrictAddressFamilies = lib.mkForce "AF_INET AF_UNIX";
  ReadWritePaths = lib.mkAfter [ "/var/cache/himmelblau-policies" ];
};
```

**home-manager 側 (Zen Browser 用の拡張設定):**

`home/default.nix`:

```nix
let
  # osConfig から himmelblau の有効状態を取得
  hasHimmelblau = osConfig.services.himmelblau.enable or false;

  zenBrowser = pkgs.wrapFirefox
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped {
      pname = "zen-browser";
      extraPolicies = lib.optionalAttrs hasHimmelblau {
        # Zen Browser 用の拡張設定
        ExtensionSettings = {
          "linux-entra-sso@example.com" = {
            install_url =
              "https://github.com/siemens/linux-entra-sso/releases/download/v1.7.1/linux_entra_sso-1.7.1.xpi";
            installation_mode = "normal_installed";
          };
        };
      };
    };
in {
  programs.firefox = {
    enable = true;
    package = zenBrowser;
    configPath = ".zen";

    # Native messaging host は公式モジュールから取得
    nativeMessagingHosts = [ pkgs.tridactyl-native ]
      ++ lib.optional hasHimmelblau
        osConfig.services.himmelblau.package.firefoxNativeMessagingHost;
  };
}
```

**注意:**
- 公式モジュールは `programs.firefox.policies` を設定するが、Zen Browser は別 package
- Zen Browser 用には home-manager で明示的に `extraPolicies` を設定
- Native messaging host は両者で共有可能

### 3.2 host 設定の更新

**himmelblauPkg を extraSpecialArgs から削除:**

`hosts/wk2511058/configuration.nix`:

```nix
# 変更前
let
  himmelblauPkg = pkgs.callPackage ../../modules/himmelblau/package.nix {
    himmelblauSrc = inputs.himmelblau;
  };
in {
  imports = [
    ../../modules/himmelblau
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs himmelblauPkg; };
  };
}

# 変更後
{
  imports = [
    inputs.himmelblau.nixosModules.himmelblau
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    # himmelblauPkg は不要 (home-manager から osConfig で参照)
  };

  services.himmelblau = {
    enable = true;
    # ... 設定
  };
}
```

**junior など他のホストも更新:**

```nix
# himmelblauPkg = null だった箇所は単に削除
home-manager = {
  extraSpecialArgs = { inherit inputs; variant = "desktop"; };
  # himmelblauPkg は削除
};
```

### 3.3 カスタムモジュールの削除

**以下のファイルを削除またはアーカイブ:**
- `modules/himmelblau/default.nix`
- `modules/himmelblau/package.nix`
- `modules/himmelblau/options.nix` (フェーズ1で作成した場合)

**アーカイブ推奨:**
```bash
cd /home/k2/nixos-config/modules/himmelblau
mkdir archive
mv default.nix package.nix archive/
# options.nix がある場合も archive へ
# MIGRATION.md は残す
```

### 3.4 テスト

```bash
# ビルドテスト
nixos-rebuild build

# 設定ファイル確認
cat /etc/himmelblau/himmelblau.conf

# 動作確認
systemctl status himmelblaud
systemctl status himmelblaud-tasks
himmelblaud --version
```

**検証項目:**

**システム側:**
- [ ] 公式モジュールが正しく動作する
- [ ] 全ての設定オプションが適用される
- [ ] サービスが正常に起動する
- [ ] 認証が動作する
- [ ] User mapping が動作する

**Zen Browser 側:**
- [ ] Zen Browser が起動する
- [ ] Entra SSO 拡張が自動インストールされる
- [ ] Native messaging host が動作する
- [ ] ブラウザから認証できる
- [ ] 拡張のアイコンが表示される

## リスクと対策

### リスク 1: IPv6 問題の再発

**リスク:** 上流のモジュールが IPv4 のみに制限していない

**対策:**
- systemd override で `RestrictAddressFamilies = AF_INET AF_UNIX` を強制
- テスト環境で事前検証

### リスク 2: 設定オプションの互換性

**リスク:** 上流のデフォルト値が異なる可能性

**対策:**
- 移行前に現在の設定をバックアップ
- diff で設定ファイルを比較
- `lib.mkDefault` で明示的にデフォルト値を設定

### リスク 3: TPM アクセスの問題

**リスク:** `tss` グループが不要になる可能性、または必要なのに設定されない

**対策:**
- 上流のコードで TPM アクセス方法を確認 (`/dev/tpmrm0` 直接アクセス)
- 必要に応じて `SupplementaryGroups` を追加

### リスク 4: 既存ユーザーの影響

**リスク:** 設定変更により既存の認証が動作しなくなる

**対策:**
- テスト環境で先に検証
- `offline_breakglass` を有効にしておく (7日間のオフライン認証)
- root パスワードを確認しておく

## ロールバック計画

各フェーズで問題が発生した場合のロールバック手順:

### フェーズ 1 でのロールバック

```bash
cd /home/k2/nixos-config/modules/himmelblau
git checkout default.nix
nixos-rebuild switch
```

### フェーズ 2 でのロールバック

```bash
# package.nix を復元
git checkout modules/himmelblau/package.nix

# default.nix を修正 (himmelblauPkg の定義を戻す)
# flake input を削除 (または無効化)
nixos-rebuild switch
```

### フェーズ 3 でのロールバック

```bash
# カスタムモジュールを復元
cd /home/k2/nixos-config/modules/himmelblau
mv archive/* .

# import から公式モジュールを削除
# 設定を services.azure-entra に戻す
nixos-rebuild switch
```

## 成功基準

### フェーズ 0 (必須)
- [ ] Cachix がインストールされている
- [ ] himmelblau キャッシュが有効化されている

### フェーズ 2 (最重要)
- [ ] **Cachix キャッシュからパッケージが取得される** (ビルド時間が大幅短縮)
- [ ] 上流パッケージで動作する
- [ ] カスタムモジュールと組み合わせて動作
- [ ] IPv6 問題が発生しない
- [ ] 全機能が動作（認証、ブラウザ SSO、Zen Browser）

### フェーズ 1 (オプション)
- [ ] 型付きオプションで設定できる
- [ ] 生成された INI ファイルが元のものと同一
- [ ] 全てのサービスが正常動作

### フェーズ 3 (オプション)
- [ ] 公式モジュールを使用（または override）
- [ ] 全機能が動作 (認証、ブラウザ SSO、user mapping)
- [ ] Zen Browser 拡張が自動インストールされる (home-manager 経由)
- [ ] Native messaging host が正しく参照される

## 次のステップ

### 推奨手順（最速でキャッシュ活用）

1. **フェーズ 0: Cachix セットアップ（今すぐ実施）**
   - [ ] `cachix use himmelblau` を実行
   - [ ] 設定を確認

2. **フェーズ 2: パッケージ切り替え（最優先）**
   - [ ] Git で作業ブランチ作成
   - [ ] `flake.nix` の himmelblau input を更新
   - [ ] `modules/himmelblau/default.nix` でパッケージのみ差し替え
   - [ ] `package.nix` を archive へ移動
   - [ ] ビルドしてキャッシュヒットを確認
   - [ ] 動作確認（認証、ブラウザ SSO）
   - [ ] コミット

3. **フェーズ 1 & 3: 必要に応じて実施（オプション）**
   - [ ] 型付きオプションのメリットを評価
   - [ ] 公式モジュールの完全採用を検討
   - [ ] またはカスタムモジュールでの override を継続

### 評価項目

**フェーズ 2 完了後に評価:**
- ビルド時間はどれくらい短縮されたか？
- カスタム設定（IPv6 回避など）は維持できているか？
- 公式モジュールに移行する必要があるか？（or カスタムで十分か？）

## 参考資料

### ドキュメント
- `/home/k2/nixos-config/external-docs/himmelblau-analysis/README.md`
- `/home/k2/nixos-config/external-docs/himmelblau-analysis/COMPARISON.md`

### 公式リポジトリ
- `/home/k2/nixos-config/external-docs/himmelblau/`
- https://github.com/himmelblau-idm/himmelblau

### 現在の実装
- `/home/k2/nixos-config/modules/himmelblau/default.nix`
- `/home/k2/nixos-config/modules/himmelblau/package.nix`

### 重要なファイル
- `external-docs/himmelblau/nix/modules/himmelblau.nix` - 公式モジュール
- `external-docs/himmelblau/nix/modules/himmelblau-options.nix` - 型付きオプション
- `external-docs/himmelblau/nix/packages/himmelblau.nix` - 公式パッケージ
- `external-docs/himmelblau/flake.nix` - Flake 定義

## 履歴

- 2026-01-31: 初版作成 (調査完了後)
