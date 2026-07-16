{
  lib,
  stdenvNoCC,
  fetchurl,
  p7zip,
  writeShellApplication,
  wineWow64Packages,
  dxvk,
  coreutils,
}:

let
  version = "0.48.4";

  # winegstreamer(カメラ) + winex11.drv(描画) を含む full ビルドが必須。
  # stable には winegstreamer が、waylandFull には winex11.drv が無い。
  wine = wineWow64Packages.full;

  # electron-builder(NSIS) の Setup.exe は実行せず、中の app-64.7z を直接展開する
  # (インストーラは PowerShell 成功判定に依存し Wine で失敗するため)。
  app = stdenvNoCC.mkDerivation {
    pname = "gather-app";
    inherit version;

    src = fetchurl {
      # api.v2.gather.town/.../latest が下記バージョン付きURLへ 302 する。
      # 更新時: version と hash を差し替え。
      url = "https://downloads.gather.town/desktop-v2/GatherV2-${version}-Setup.exe";
      hash = "sha256-qy3UR/VjoyPpKlepJ/U51mP85qqupfF1eNYIS4vGJLQ=";
    };

    nativeBuildInputs = [ p7zip ];
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      7z e -y "$src" '$PLUGINSDIR/app-64.7z' -o.
      mkdir -p app
      7z x -y app-64.7z -oapp
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/gather"
      cp -r app/. "$out/share/gather/"
      runHook postInstall
    '';

    meta.description = "Gather desktop (Windows/Electron) app payload, extracted";
  };
in
writeShellApplication {
  name = "gather";
  runtimeInputs = [
    wine
    coreutils
  ];

  # 変更したら bump してプレフィックスを再セットアップさせる
  text = ''
    setup_rev="v${version}-dxvk-x11"

    export WINEPREFIX="''${GATHER_WINEPREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/gather/wineprefix}"
    export WINEARCH=win64
    # XWayland 経由で実GPUのGLを使う (Wine の Wayland ドライバは Chromium を present できず白画面)
    export DISPLAY="''${DISPLAY:-:0}"
    export WINEDEBUG="''${WINEDEBUG:-fixme-all,err+all}"
    export DXVK_LOG_LEVEL="''${DXVK_LOG_LEVEL:-none}"

    app="${app}/share/gather/GatherV2.exe"

    marker="$WINEPREFIX/.gather-setup-rev"
    if [ "$(cat "$marker" 2>/dev/null || true)" != "$setup_rev" ]; then
      echo "gather: setting up wine prefix at $WINEPREFIX ..." >&2
      mkdir -p "$WINEPREFIX"
      wineboot --init
      # X11 グラフィックスドライバを明示
      wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /d x11 /f
      # DXVK: Chromium ANGLE -> D3D11 -> DXVK -> Vulkan -> GPU (無いと Loading で停止)
      sys64="$WINEPREFIX/drive_c/windows/system32"
      sys32="$WINEPREFIX/drive_c/windows/syswow64"
      for d in d3d11 dxgi d3d10core; do
        install -m644 "${dxvk.bin}/x64/$d.dll" "$sys64/$d.dll"
        install -m644 "${dxvk.bin}/x32/$d.dll" "$sys32/$d.dll"
        wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /d native /f
      done
      echo "$setup_rev" > "$marker"
      echo "gather: prefix ready." >&2
    fi

    # --no-sandbox: Chromium sandbox は Wine で動かない
    # --force-device-scale-factor: XWayland の 2560->4K 拡大ボケを緩和 (GATHER_SCALE で上書き可)
    exec wine "$app" \
      --no-sandbox \
      --ignore-gpu-blocklist \
      --force-device-scale-factor="''${GATHER_SCALE:-1.5}" \
      "$@"
  '';

  meta = {
    description = "Gather desktop client (Windows build) via Wine + DXVK on XWayland";
    homepage = "https://www.gather.town/";
    platforms = [ "x86_64-linux" ];
    mainProgram = "gather";
  };
}
