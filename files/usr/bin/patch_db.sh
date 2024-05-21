#!/bin/bash
mkdir -p /data/postgresql/14/main/{data,conf}

if [[ -d /etc/postgresql/14/main ]]; then
  echo "Found /etc/postgresql/14/main dir. Moving everything to /data/postgresql/14/main/conf"
  mv /etc/postgresql/14/main/* /data/postgresql/14/main/conf
  rm -rf /etc/postgresql/14/main
  ln -s /data/postgresql/14/main/conf /etc/postgresql/14/main
fi

sed -i -e 's/host    all             all             127.0.0.1\/32            scram-sha-256/host    all             all             127.0.0.1\/32            trust/g'  /etc/postgresql/14/main/pg_hba.conf
sed -i -e 's/\/var\/lib\/postgresql\/14\/main/\/data\/postgresql\/14\/main\/data/g' /etc/postgresql/14/main/postgresql.conf
#sed -i -e 's/\/data\/postgresql\/14\/main/\/srv\/postgresql\/14\/main/g' /etc/default/postgresql/14-main

chown -R postgres:postgres /data/postgresql
chown -R postgres:postgres /srv/postgresql
chown -R postgres:postgres /etc/postgresql
