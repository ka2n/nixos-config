# NixOS Configuration

## Activation Scripts

- `coreutils` commands (`cat`, `mkdir`, `chmod`, `rm`, `tr`) are in PATH
- `sed`, `grep`, `openssl` etc. require full paths
- Define full paths in inner `let` block near usage

## SOPS Secrets

### Binary Format

- Encrypt plain text: `sops -e --input-type binary --output-type binary`
- Use `--filename-override` to match `.sops.yaml` rules when encrypting from stdin/temp file
- Use `format = "binary"` in module, decrypts to `/run/secrets/<name>` (tmpfs)
