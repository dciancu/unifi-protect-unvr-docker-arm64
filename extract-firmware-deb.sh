#!/bin/bash

DIR="${DIR:-all-debs}"
dpkg-deb -x "firmware/${DIR}/${1}.deb" "firmware/${DIR}/${1}"
