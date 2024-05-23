#!/bin/bash

for file in firmware/all-debs/*.deb; do
    dpkg -c "$file" | grep -i "$1"
    $? && echo "$file"
done
