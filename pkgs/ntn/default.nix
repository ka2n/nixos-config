{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  version = "0.16.0";

  targets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-G+pmJI8gtS5SUEft16H9ErqmIT3qB2UKcpnxOcCepHk=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-0uU3KPtbVGmQS9WOZWWrhup6JwFl0y3l49N9bA04l5M=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-irWxxeUqBj7wuYks7Zc1St3mJSzqFI5GzNPKVBR7YM8=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-i0gTlN4D7fzEcwijRWdY87P0crAfpvTNt2Mpym5vwPo=";
    };
  };

  targetInfo = targets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported system for ntn: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "ntn";
  inherit version;

  src = fetchurl {
    url = "https://ntn.dev/releases/v${version}/ntn-${targetInfo.target}.tar.gz";
    inherit (targetInfo) hash;
  };

  nativeBuildInputs =
    lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ]
    ++ [ makeWrapper ];

  sourceRoot = "ntn-${targetInfo.target}";

  installPhase = ''
    runHook preInstall
    install -Dm755 ntn "$out/bin/ntn"
    # Disable keyring because it does not work in this environment.
    wrapProgram "$out/bin/ntn" --set NOTION_KEYRING 0
    runHook postInstall
  '';

  meta = with lib; {
    description = "Notion CLI";
    homepage = "https://ntn.dev";
    license = licenses.unfreeRedistributable;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "ntn";
    platforms = builtins.attrNames targets;
  };
}
