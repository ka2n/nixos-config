pkgs-unstable:
final: prev:
let
  overrides = import ./overrides { inherit pkgs-unstable; };
in
{
  # Claude CLI wrapper
  claude-code-wrapped = final.writeShellScriptBin "claude" ''
    exec ${overrides.claude-code}/bin/claude "$@"
  '';

  libcskk = final.callPackage ./libcskk { };
  fcitx5-cskk = final.callPackage ./fcitx5-cskk {
    inherit (final) libcskk fcitx5;
    inherit (final.qt6) qtbase wrapQtAppsHook;
    inherit (final.kdePackages) fcitx5-qt;
  };
  keeper-desktop = final.callPackage ./keeper-desktop { };
  display-switch = final.callPackage ./display-switch { };
  alma = final.callPackage ./alma { };
  git-wt = final.callPackage ./git-wt { };
  go-readability = final.callPackage ./go-readability { };
  inputactions-standalone = final.callPackage ./inputactions-standalone { };
  pencil = final.callPackage ./pencil { };

  # Cursor 2.2.20 - Update from nixpkgs 2.1.42
  # Patches:
  #   1. Disable built-in extension hash verification (security trade-off)
  #   2. Fix MCP OAuth callback - uri.query is empty on Linux custom protocol URLs
  code-cursor = (prev.code-cursor.override {
    commandLineArgs = "";
  }).overrideAttrs (oldAttrs: rec {
    version = "2.2.20";
    src = final.appimageTools.extract {
      pname = "cursor";
      inherit version;
      src = final.fetchurl {
        url = "https://downloads.cursor.com/production/b3573281c4775bfc6bba466bf6563d3d498d1074/linux/x64/Cursor-${version}-x86_64.AppImage";
        hash = "sha256-dY42LaaP7CRbqY2tuulJOENa+QUGSL09m07PvxsZCr0=";
      };
    };
    sourceRoot = "cursor-${version}-extracted/usr/share/cursor";

    postPatch = ''
      # Patch 1: Skip hash mismatch verification for built-in extensions
      # WARNING: This disables security verification for ALL built-in extensions
      sed -i 's/o\.mismatched\.length>0?{valid:!1,error:`Hash mismatch for files: ''${o\.mismatched\.join(", ")}`}:{valid:!0}/{valid:!0}/g' \
        resources/app/out/vs/workbench/api/node/extensionHostProcess.js

      # Patch 2: Add debug log at handleUri entry point using McpLogger
      sed -i 's/handleUri:async t=>{try{/handleUri:async t=>{o.McpLogger.info("[OAUTH-DEBUG] handleUri called: scheme="+t.scheme+" path="+t.path+" query="+t.query+" toString="+t.toString());try{/g' \
        resources/app/extensions/cursor-mcp/dist/main.js

      # Patch 3: Fix OAuth callback state parameter extraction with McpLogger debug
      sed -i 's/const i=new URLSearchParams(t\.query),s=i\.get("state")/o.McpLogger.info("[OAUTH-DEBUG] parsing query: t.query="+t.query);const i=new URLSearchParams(t.query||t.toString().split("?")[1]||""),s=i.get("state");o.McpLogger.info("[OAUTH-DEBUG] parsed state="+s)/g' \
        resources/app/extensions/cursor-mcp/dist/main.js

      # Patch 4: Bypass state parameter check when missing
      # WARNING: This disables CSRF protection - Figma MCP doesn't return state parameter
      sed -i 's/if(!s)return o\.McpLogger\.error("OAuth callback received without state parameter"),void u\.window\.showErrorMessage("OAuth callback is missing required state parameter\. Please try again\.");/if(!s){o.McpLogger.warn("[OAUTH] state parameter missing, attempting to continue...");}/g' \
        resources/app/extensions/cursor-mcp/dist/main.js

      # Patch 5: Bypass invalid state check and use fallback identifier
      # When state is missing, try to find the pending OAuth server from globalState
      # Original: const a=decodeOAuthState(s);if(!a)return error...;const c=a.id,h=i.get("code")
      # We need to keep the ,h part for the next variable declaration
      sed -i 's/const a=(0,d\.decodeOAuthState)(s);if(!a)return o\.McpLogger\.error("OAuth callback received with invalid state parameter"),void u\.window\.showErrorMessage("OAuth callback has invalid state parameter\. Please try again\.");const c=a\.id,h/const a=(0,d.decodeOAuthState)(s);let c;if(!a){o.McpLogger.warn("[OAUTH] invalid or missing state, using fallback identifier");c="user-figma";}else{c=a.id;}const h/g' \
        resources/app/extensions/cursor-mcp/dist/main.js
    '';
  });
}
