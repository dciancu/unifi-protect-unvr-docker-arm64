#!/bin/bash

if [ ! -f "/tmp/disk.img" ]; then
  dd if=/dev/zero of=/tmp/disk.img bs=1M count=1
fi

losetup -d /dev/loop0
losetup /dev/loop0 /tmp/disk.img

if [ $? -eq 0 ]; then
  ln -fs /dev/loop0 /dev/sda1
  ln -fs /dev/loop0 /dev/sdb1
fi
