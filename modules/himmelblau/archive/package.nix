# Himmelblau package with TPM support
# Based on upstream flake.nix recipe (SELinux removed)
{ lib
, rustPlatform
, runCommand
, writeText
, pkg-config
, python3
, talloc
, tevent
, ding-libs
, libunistring
, sqlite
, openssl
, libcap
, ldb
, krb5
, pcre2
, pam
, dbus
, udev
, tpm2-tss
, himmelblauSrc
}:

let
  cargoToml = builtins.fromTOML (builtins.readFile "${himmelblauSrc}/Cargo.toml");

  mainPackage = rustPlatform.buildRustPackage {
  pname = "himmelblau";
  version = cargoToml.workspace.package.version;

  # Use lib.sources for filtering (works with both path and string-like sources)
  src = lib.sources.sourceByRegex himmelblauSrc [
    "^fuzz.*"
    "^src.*"
    "^man.*"
    "^docs-xml.*"
    "^Cargo\\.toml$"
    "^Cargo\\.lock$"
    "^scripts.*"
  ];

  outputs = [ "out" "man" ];

  cargoLock = {
    lockFile = "${himmelblauSrc}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  # Enable TPM feature (passed to cargo build)
  # This works because Cargo resolver 2 propagates features to workspace members
  cargoBuildFlags = [ "--features" "tpm" ];
  cargoCheckFlags = [ "--features" "tpm" ];

  nativeBuildInputs = [
    pkg-config
    python3
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    talloc
    tevent
    ding-libs
    libunistring
    sqlite.dev
    openssl.dev
    libcap.dev
    ldb.dev
    krb5.dev
    pcre2.dev
    pam
    dbus.dev
    udev.dev
    tpm2-tss  # Required for TPM feature
  ];

  # Skip SELinux build (not supported)
  env.HIMMELBLAU_ALLOW_MISSING_SELINUX = "1";

  postBuild = "cp -r man $man/";

  postInstall = ''
    ln -s $out/lib/libnss_himmelblau.so $out/lib/libnss_himmelblau.so.2

    # Install DBus service file for identity broker
    mkdir -p $out/share/dbus-1/services
    cat > $out/share/dbus-1/services/com.microsoft.identity.broker1.service <<EOF
[D-BUS Service]
Name=com.microsoft.identity.broker1
Exec=$out/bin/broker
EOF
  '';

    meta = with lib; {
      description = "Himmelblau - Azure Entra ID and Intune interoperability suite (with TPM support)";
      homepage = "https://github.com/himmelblau-idm/himmelblau";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  };

  # Native messaging host manifest generator
  mkNativeMessagingManifest = browser: builtins.toJSON ({
    name = "linux_entra_sso";
    description = "Entra ID SSO via Himmelblau Identity Broker";
    path = "${mainPackage}/bin/linux-entra-sso";
    type = "stdio";
  } // (if browser == "firefox"
    then { allowed_extensions = [ "linux-entra-sso@example.com" ]; }
    else { allowed_origins = [ "chrome-extension://jlnfnnolkbjieggibinobhkjdfbpcohn/" ]; }
  ));

in mainPackage.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or {}) // {
    # Native messaging host packages
    firefoxNativeMessagingHost = runCommand "linux-entra-sso-firefox" {} ''
      mkdir -p $out/lib/mozilla/native-messaging-hosts
      echo '${mkNativeMessagingManifest "firefox"}' > $out/lib/mozilla/native-messaging-hosts/linux_entra_sso.json
    '';

    chromeNativeMessagingHost = runCommand "linux-entra-sso-chrome" {} ''
      mkdir -p $out/etc/opt/chrome/native-messaging-hosts
      echo '${mkNativeMessagingManifest "chrome"}' > $out/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json
    '';

    chromiumNativeMessagingHost = runCommand "linux-entra-sso-chromium" {} ''
      mkdir -p $out/etc/chromium/native-messaging-hosts
      echo '${mkNativeMessagingManifest "chromium"}' > $out/etc/chromium/native-messaging-hosts/linux_entra_sso.json
    '';
  };
})
