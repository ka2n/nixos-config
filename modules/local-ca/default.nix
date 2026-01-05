{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.localCA;
  opensslBin = "${pkgs.openssl}/bin/openssl";
in {
  options.security.localCA = {
    enable = mkEnableOption "local CA certificate for HTTPS development";

    certificateFile = mkOption {
      type = types.path;
      description = "Path to the CA certificate file (PEM format)";
    };

    sopsSecretFile = mkOption {
      type = types.path;
      description = "Path to the sops-encrypted secret file containing the CA private key";
    };

    sopsSecretKey = mkOption {
      type = types.str;
      default = "data";
      description = "Key name in the sops secret file";
    };

    domains = mkOption {
      type = types.listOf types.str;
      default = [ "localhost" "*.localhost" "*.local" ];
      description = "Domains to include in the server certificate SAN";
    };

    serverCertValidityDays = mkOption {
      type = types.int;
      default = 825;
      description = "Validity period for server certificates in days (Apple requires <= 825)";
    };

    organization = mkOption {
      type = types.str;
      default = "Local Development";
      description = "Organization name for generated certificates";
    };
  };

  config = mkIf cfg.enable {
    # sops-nix configuration for CA private key
    sops.defaultSopsFile = mkDefault cfg.sopsSecretFile;
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets.local-ca-key = {
      key = cfg.sopsSecretKey;
      path = "/etc/ssl/local-ca/ca.key";
      mode = "0600";
    };

    # Trust local CA certificate system-wide
    security.pki.certificateFiles = [ cfg.certificateFile ];

    # Place CA public certificate in /etc/ssl/local-ca/
    environment.etc."ssl/local-ca/ca.crt".source = cfg.certificateFile;

    # Generate server certificates signed by local CA
    system.activationScripts.localCACerts = {
      deps = [ "setupSecrets" ];
      text = let
        sanEntries = concatMapStringsSep "," (d: "DNS:${d}") cfg.domains;
      in ''
        CERT_DIR=/etc/ssl/local-ca/certs
        mkdir -p $CERT_DIR

        # Regenerate if cert doesn't exist or CA cert is newer
        if [ ! -f $CERT_DIR/localhost.crt ] || [ /etc/ssl/local-ca/ca.crt -nt $CERT_DIR/localhost.crt ]; then
          echo "Generating localhost server certificate..."

          ${opensslBin} genrsa -out $CERT_DIR/localhost.key 2048
          ${opensslBin} req -new \
            -key $CERT_DIR/localhost.key \
            -out /tmp/localhost.csr \
            -subj "/O=${cfg.organization}/CN=localhost"

          cat > /tmp/localhost.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
subjectAltName=${sanEntries}
EOF

          ${opensslBin} x509 -req \
            -in /tmp/localhost.csr \
            -CA /etc/ssl/local-ca/ca.crt \
            -CAkey /etc/ssl/local-ca/ca.key \
            -CAcreateserial \
            -out $CERT_DIR/localhost.crt \
            -days ${toString cfg.serverCertValidityDays} -sha256 \
            -extfile /tmp/localhost.ext

          chmod 644 $CERT_DIR/localhost.crt
          chmod 640 $CERT_DIR/localhost.key
          rm -f /tmp/localhost.csr /tmp/localhost.ext

          echo "Server certificate generated at $CERT_DIR/localhost.crt"
        fi
      '';
    };
  };
}
