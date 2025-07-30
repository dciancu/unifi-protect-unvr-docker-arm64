#!/bin/bash

DIR="${DIR:-all-debs}"
dpkg -e "firmware/${DIR}/${1}.deb" "firmware/${DIR}/${1}"
dpkg-deb -x "firmware/${DIR}/${1}.deb" "firmware/${DIR}/${1}"
