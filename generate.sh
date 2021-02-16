#!/usr/bin/env zsh
force=0
[[ $1 == -f || $1 == --force ]] && force=1
for size in 32 64 128 256; do
    mkdir -p $size/egginc $size/egginc-extras $size/egginc-extras/glow
done
for src in orig/egginc/*.png orig/egginc-extras/**/*.png; do
    for size in 32 64 128 256; do
        dst=${size}/${src#orig/}
        (( !force )) && [[ -e $dst ]] && continue
        echo "$src => $dst"
        convert $src -resize ${size}x${size} $dst
        optipng -quiet $dst
    done
done
