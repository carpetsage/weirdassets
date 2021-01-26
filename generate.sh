#!/usr/bin/env zsh
for size in 32 64 128 256; do
    mkdir -p $size/egginc $size/egginc-extras
done
for src in orig/egginc/*.png orig/egginc-extras/*.png; do
    for size in 32 64 128 256; do
        dst=${size}/${src#orig/}
        echo "$src => $dst"
        convert $src -resize ${size}x${size} $dst
        optipng -quiet $dst
    done
done
