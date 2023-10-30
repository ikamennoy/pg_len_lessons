#!/bin/bash
dpkg -l|grep postgres && exit 0
grep -e '^ru_RU.UTF-8' /etc/locale.gen && exit 0
apt update
timedatectl set-timezone Europe/Moscow
sed -i "/ru_RU.UTF-8/s/^# //g" /etc/locale.gen
locale-gen
echo 'LC_ALL=ru_RU.UTF-8'>>/etc/environment
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" |sudo tee /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-15

x=`systemctl -a|grep postgres|sed 's/.service.*//g;s/^.* postgres/postgres/g'`
systemctl enable $x
systemctl start $x
sleep 2s
sudo -u postgres psql -c "create database testdb"
sudo -u postgres psql testdb -f /tmp/testdb.sql
rm /etc/cron.d/once
