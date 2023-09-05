#!/bin/sh

sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update -y

apt-get install postgresql-15 -y

sudo -u postgres psql <<EOF
CREATE ROLE coder LOGIN SUPERUSER PASSWORD 'coder';
CREATE DATABASE coder OWNER coder;
EOF
