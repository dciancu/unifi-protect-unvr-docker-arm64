#!/bin/bash

DIR="${DIR:-all-debs}"
for file in "firmware/${DIR}"/*.deb; do
    file="$(basename -s .deb "$file")"
    echo "$file"
    DIR="$DIR" bash extract-firmware-deb.sh "$file"
done
