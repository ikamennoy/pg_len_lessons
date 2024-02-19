#!/bin/bash
test `whoami` = "root" || exit 0
hostname
localip=`ip addr show eth0|grep -Po 'inet ([0-9.]*)'|grep -Po '[0-9.]*'|head -n 1`
cat >/dev/null <<EON
sysctl net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sed -i 's/keepcache=0/keepcache=1/g' /etc/yum.conf
cat <<EOI >> /usr/share/doc/glibc-common-2.17/gai.conf
precedence ::ffff:0:0/96  100
precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence ::/96          20
EOI
EON

cd /home/uuu
setenforce 0
sed -i 's/=enforcing/=permissive/g' /etc/selinux/config
#rm -f squid*
#grep -e no_proxy /etc/environment || echo -e 'http_proxy=http://vb:55558\nhttps_proxy=http://vb:55558\nno_proxy=127.0.0.1,vb,va,vd,*.internal,localhost,*.testnet.tech' >> /etc/environment
ls -1 *.rpm | xargs yum -y localinstall
test -f /usr/bin/consul || exit 1
#( cd / ; tar -xpf /home/uuu/yum.tar )
consul -autocomplete-install
echo '{"server": true,"data_dir": "/var/lib/consul","log_level": "INFO","ui_config":{"enabled":true},"rejoin_after_leave": true,"leave_on_terminate": false,"retry_join": ["va","vb","vd"],"bootstrap": false, "bootstrap_expect": 3 }' > /etc/consul.d/consul.json
chown consul.consul /etc/consul.d/consul.json
sudo systemctl enable --now consul

mv consul-template /usr/bin/
#cp {/home/uuu,/etc/haproxy}/haproxy.conf.ctmpl
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
#yum install -C -y epel-release deltarpm $disablereps || yum install -y epel-release deltarpm $disablereps
#yum install -C -y postgresql13-server postgres13-agent haproxy epel-release python-psycopg2 chrony wget zip unzip jq vim curl lsof git keepalived patroni-consul $disablereps || yum install -y postgresql13-server postgres13-agent haproxy epel-release python-psycopg2 chrony wget zip unzip jq vim curl lsof git keepalived patroni-consul $disablereps
test -f /usr/bin/zip || exit 1
sed "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g" /home/uuu/keepalived.conf.0 > /etc/keepalived/keepalived.conf
echo -e 'Requires=consul.service\nRequires=patroni.service' >> /usr/lib/systemd/system/keepalived.service
systemctl daemon-reload
cp {/home/uuu/,/etc/patroni/}patroni.yml
chown postgres.postgres /etc/patroni/patroni.yml
sed "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g" /home/uuu/patroni.yml > /etc/patroni/patroni.yml
cp /home/uuu/haproxy.cfg /etc/haproxy/
cat /etc/keepalived/keepalived.conf /etc/patroni/patroni.yml /etc/consul.d/consul.json /etc/haproxy/haproxy.cfg /etc/environment


