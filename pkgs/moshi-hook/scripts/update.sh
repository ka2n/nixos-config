#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../.." && pwd)
package_file="$repo_root/pkgs/moshi-hook/default.nix"

version=$(curl --fail --silent --show-error --location \
  https://cdn.getmoshi.app/hook/latest/version.txt | tr -d '[:space:]')
version=${version#v}

if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'unexpected moshi-hook version: %s\n' "$version" >&2
  exit 1
fi

declare -A architectures=(
  [x86_64-linux]=Linux_x86_64
  [aarch64-linux]=Linux_arm64
  [x86_64-darwin]=Darwin_x86_64
  [aarch64-darwin]=Darwin_arm64
)

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

declare -A hashes
for system in "${!architectures[@]}"; do
  archive="$tmp_dir/moshi-hook_${system}.tar.gz"
  url="https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${architectures[$system]}.tar.gz"

  printf 'fetching %s\n' "$url" >&2
  curl --fail --silent --show-error --location --retry 3 "$url" -o "$archive"
  hashes[$system]=$(nix hash file --type sha256 --sri "$archive")
  printf '%s: %s\n' "$system" "${hashes[$system]}" >&2
done

updated_file="$tmp_dir/default.nix"
cp "$package_file" "$updated_file"

sed -E -i "s/version = \"[0-9]+\.[0-9]+\.[0-9]+\";/version = \"$version\";/" "$updated_file"
# Anchored on the whole `<system> = { arch = "..."; hash = "` prefix so only the
# hash is touched -- a bare `<system> = "..."` pattern also matched the arch
# suffix and rewrote it with the hash, producing 404 URLs.
for system in "${!architectures[@]}"; do
  sed -E -i "s|(${system} = \{ arch = \"[^\"]+\"; hash = \")[^\"]+(\";)|\1${hashes[$system]}\2|" "$updated_file"
done

mv "$updated_file" "$package_file"
printf 'updated %s to %s\n' "$package_file" "$version"
