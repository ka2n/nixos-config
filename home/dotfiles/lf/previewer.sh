#!/bin/sh
# Image preview using Sixel

# Command paths (replaced by Nix)
stat=@stat@
readlink=@readlink@
sha256sum=@sha256sum@
awk=@awk@
chafa=@chafa@
file=@file@
identify=@identify@
convert=@convert@
ffmpegthumbnailer=@ffmpegthumbnailer@
fold=@fold@

hash() {
  printf '%s/.cache/lf/%s' "$HOME" \
    "$($stat --printf '%n\0%i\0%F\0%s\0%W\0%Y' -- "$($readlink -f "$1")" | $sha256sum | $awk '{print $1}')"
}

cache() {
  if [ -f "$1" ]; then
    $chafa -f sixel -s "${2}x${3}" --animate off --polite on "$1"
    exit 1
  fi
}

case "$($file -Lb --mime-type -- "$1")" in
  image/*)
    orientation="$($identify -format '%[EXIF:Orientation]\n' -- "$1" 2>/dev/null)"
    if [ -n "$orientation" ] && [ "$orientation" != 1 ]; then
      cache_file="$(hash "$1").jpg"
      cache "$cache_file" "$2" "$3"
      $convert -- "$1" -auto-orient "$cache_file"
      $chafa -f sixel -s "$2x$3" --animate off --polite on "$cache_file"
    else
      $chafa -f sixel -s "$2x$3" --animate off --polite on "$1"
    fi
    exit 1
    ;;
  video/*)
    cache_file="$(hash "$1").jpg"
    cache "$cache_file" "$2" "$3"
    $ffmpegthumbnailer -i "$1" -o "$cache_file" -s 0
    $chafa -f sixel -s "$2x$3" --animate off --polite on "$cache_file"
    exit 1
    ;;
  text/*)
    cat "$1"
    ;;
  *)
    $file -Lb -- "$1" | $fold -s -w "$2"
    ;;
esac
exit 0
