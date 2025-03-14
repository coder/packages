#!/bin/bash

# Ensure /tmp exists and has the proper permissions before
# checking for security updates
# https://github.com/digitalocean/marketplace-partners/issues/94
if [[ ! -d /tmp ]]; then
    mkdir /tmp
fi
chmod 1777 /tmp

apt-get -y update
apt-get -y upgrade
rm -rf /tmp/* /var/tmp/*
history -c
cat /dev/null >/root/.bash_history
unset HISTFILE
apt-get -y autoremove
apt-get -y autoclean
find /var/log -mtime -1 -type f -exec truncate -s 0 {} \;
rm -rf /var/log/*.gz /var/log/*.[0-9] /var/log/*-????????
rm -rf /var/lib/cloud/instances/*
rm -f /root/.ssh/authorized_keys /etc/ssh/*key*
touch /etc/ssh/revoked_keys
chmod 600 /etc/ssh/revoked_keys

# For AWS security scans
rm -f /home/ubuntu/.ssh/authorized_keys

# Ensure / filesystem is owned by root
chown root:root /
chmod o-w /

# Stop Coder service to ensure clean shutdown before wiping data
systemctl stop coder

# Clean PostgreSQL data directory to remove deployment ID
# This ensures each marketplace installation gets a unique deployment ID
# Fix for: https://github.com/coder/packages/issues/180
# Problem: All marketplace images had the same deployment ID because Coder was started
# during image build, which generated and saved a deployment ID in the PostgreSQL database
PG_VERSION=15  # Version set in 013-postgresql.sh
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
if [ -d "$PG_DATA_DIR" ]; then
  echo "Stopping PostgreSQL service..."
  systemctl stop postgresql
  
  echo "Wiping PostgreSQL data directory to remove Coder deployment ID..."
  # Backup pg_hba.conf and postgresql.conf
  cp "$PG_DATA_DIR/pg_hba.conf" "/tmp/pg_hba.conf.bak" 2>/dev/null
  cp "$PG_DATA_DIR/postgresql.conf" "/tmp/postgresql.conf.bak" 2>/dev/null
  
  # Remove data directory
  rm -rf "$PG_DATA_DIR"
  
  # Recreate data directory
  mkdir -p "$PG_DATA_DIR"
  chown -R postgres:postgres "$PG_DATA_DIR"
  chmod 700 "$PG_DATA_DIR"
  
  # Initialize PostgreSQL database
  echo "Initializing fresh PostgreSQL database..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/initdb -D "$PG_DATA_DIR"
  
  # Restore configuration if it existed
  if [ -f "/tmp/pg_hba.conf.bak" ]; then
    cp "/tmp/pg_hba.conf.bak" "$PG_DATA_DIR/pg_hba.conf"
    chown postgres:postgres "$PG_DATA_DIR/pg_hba.conf"
  fi
  
  if [ -f "/tmp/postgresql.conf.bak" ]; then
    cp "/tmp/postgresql.conf.bak" "$PG_DATA_DIR/postgresql.conf"
    chown postgres:postgres "$PG_DATA_DIR/postgresql.conf"
  fi
  
  # Start PostgreSQL temporarily to recreate database structure
  systemctl start postgresql
  
  # Wait for PostgreSQL to start
  sleep 5
  
  # Recreate database and user (same as in 013-postgresql.sh)
  echo "Recreating database structure..."
  sudo -u postgres psql <<EOF
CREATE ROLE coder LOGIN SUPERUSER PASSWORD 'coder';
CREATE DATABASE coder OWNER coder;
EOF
  
  # Stop PostgreSQL again
  systemctl stop postgresql
  
  # Clean up temp files
  rm -f "/tmp/pg_hba.conf.bak" "/tmp/postgresql.conf.bak"
fi

# Clean up Coder cache
rm -rf /home/coder/.config

# Securely erase the unused portion of the filesystem
GREEN='\033[0;32m'
NC='\033[0m'
printf "\n${GREEN}Writing zeros to the remaining disk space to securely
erase the unused portion of the file system.
Depending on your disk size this may take several minutes.
The secure erase will complete successfully when you see:${NC}
    dd: writing to '/zerofile': No space left on device\n
Beginning secure erase now\n"

dd if=/dev/zero of=/zerofile &
PID=$!
while [ -d /proc/$PID ]; do
    printf "."
    sleep 5
done
sync
rm /zerofile
sync
cat /dev/null >/var/log/lastlog
cat /dev/null >/var/log/wtmp
