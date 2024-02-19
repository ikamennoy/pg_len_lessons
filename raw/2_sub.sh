#!/bin/bash
hostname
grep -e no_proxy /etc/environment || echo -e 'http_proxy=http://vb:55555\nhttps_proxy=http://vb:55555\nno_proxy=127.0.0.1,vb,va,vd,*.internal,localhost,*.testnet.tech' >> /etc/environment
rpm -i ~uuu/*.rpm
( cd / ; tar -xpf ~uuu/yum.tar )
consul -autocomplete-install
echo '{"server": true,"data_dir": "/var/lib/consul","log_level": "INFO","ui_config":{"enabled":true},"rejoin_after_leave": true,"leave_on_terminate": false,"retry_join": ["va","vb","vd"],"bootstrap": false, "bootstrap_expect": 3 }' > /etc/consul.d/consul.json
chown consul.consul /etc/consul.d/consul.json
sudo systemctl enable --now consul

mv ~uuu/consul-template /usr/bin/
cp {~uuu,/etc/haproxy}/haproxy.conf.ctmpl
timedatectl set-timezone Europe/Moscow
#yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sed -i "s/en_US/ru_RU/g" /etc/locale.conf
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
export LC_ALL=ru_RU.UTF8

cat >> /etc/environment <<EOC
LC_ALL=ru_RU.UTF8
PGDATA=/var/lib/pgsql/13/data
PATH="/usr/pgsql-13/bin:$PATH"
EOC

disablereps="--disablerepo=pgdg15 --disablerepo=pgdg14 --disablerepo=pgdg12"
yum install -y postgresql13-server postgres13-agent haproxy epel-release python-psycopg2 chrony wget zip unzip jq vim curl lsof git $disablereps
yum install -y patroni-consul $disablereps # postgresql13-plpython3

cp {~uuu/,/etc/patroni/}patroni.yml
chown postgres.postgres /etc/patroni/patroni.yml
localip=`ip addr show eth0|grep -Po 'inet ([0-9.]*)'|grep -Po '[0-9.]*'`
sed -i "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g"

