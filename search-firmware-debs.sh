#!/bin/bash

for file in "firmware/${DIR:-all-debs}"/*.deb; do
    dpkg -c "$file" | grep -i "$1"
    if [ $? -eq 0 ]; then
        echo "$file"
    fi
done
