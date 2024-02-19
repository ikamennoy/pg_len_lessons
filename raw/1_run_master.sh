#!/bin/bash
test `whoami` = "root" || exit 0
test -f .env && source .env
echo $mip
usermod -aG wheel -G systemd-journal -G adm uuu

wget https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
rpm -i consul-1.17.2-1.el7.x86_64.rpm pgdg-redhat-repo-latest.noarch.rpm
echo '{"server": true,"data_dir": "/var/lib/consul","log_level": "INFO","ui_config":{"enabled":true},"rejoin_after_leave": true,"leave_on_terminate": false,"retry_join": ["va","vb","vd"],"bootstrap": false, "bootstrap_expect": 3 }' > /etc/consul.d/consul.json
chown consul.consul /etc/consul.d/consul.json
gunzip consul-template.gz
cp consul-template /usr/bin/
timedatectl set-timezone Europe/Moscow
yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm


sed -i "s/en_US/ru_RU/g" /etc/locale.conf
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
export LC_ALL=ru_RU.UTF8
cat >> /etc/environment <<EOC
LC_ALL=ru_RU.UTF8
PGDATA=/var/lib/pgsql/13/data
PATH="/usr/pgsql-13/bin:$PATH"
EOC
disablereps="--disablerepo=pgdg15 --disablerepo=pgdg14 --disablerepo=pgdg12"
yum install -y postgresql13-server postgres13-agent squid haproxy firewalld epel-release python-psycopg2 chrony wget zip unzip jq vim curl lsof git telnet $disablereps
consul -autocomplete-install
cat <<EOSQ > /etc/squid/squid.conf
acl good url_regex (Release|Packages(.gz)*)$
acl good url_regex (\.xml|xml\.gz)$
acl good url_regex (sqlite\.(bz2)*)$
acl good url_regex (\.deb|\.udeb)$
acl good url_regex (\.rpm|\.srpm)$
acl good url_regex (repomd\.xml)$
acl good2 dstdomain .postgresql.org
acl good2 dstdomain .microsoft.com
acl good2 dstdomain .centos.org
acl good2 dstdomain .fedoraproject.org
acl good2 dstdomain .yandex.ru
acl block_port port 443
acl block_port port 80
acl CONNECT method CONNECT
http_access allow good
http_access allow good2
http_access deny all
http_access deny block_port
http_port 55555
coredump_dir /var/spool/squid
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern (\.xml|xml\.gz)$      0       20%     2880
refresh_pattern ((sqlite.bz2)*)$      0       20%     2880
refresh_pattern (\.deb|\.udeb)$   1296000 100% 1296000
refresh_pattern (\.rpm|\.srpm)$   1296000 100% 1296000
refresh_pattern .        0    20%    4320
EOSQ

#echo -e 'acl good url_regex (Release|Packages(.gz)*)$\nacl good url_regex (\.xml|xml\.gz)$\nacl good url_regex (sqlite\.(bz2)*)$\nacl good url_regex (\.deb|\.udeb)$\nacl good url_regex (\.rpm|\.srpm)$\nacl good url_regex (repomd\.xml)$\nacl good2 dstdomain .postgresql.org\nacl good2 dstdomain .microsoft.com\nacl block_port port 443\nacl block_port port 80\nacl CONNECT method CONNECT\nhttp_access allow good\nhttp_access allow good2\nhttp_access deny all\nhttp_access deny block_port\nhttp_port 55555\ncoredump_dir /var/spool/squid\nrefresh_pattern (Release|Packages(.gz)*)$      0       20%     2880\nrefresh_pattern (\.xml|xml\.gz)$      0       20%     2880\nrefresh_pattern ((sqlite.bz2)*)$      0       20%     2880\nrefresh_pattern (\.deb|\.udeb)$   1296000 100% 1296000\nrefresh_pattern (\.rpm|\.srpm)$   1296000 100% 1296000\nrefresh_pattern .        0    20%    4320\n' > /etc/squid/squid.conf

test -f /var/lib/pgsql/13/data/pg_hba.conf || /usr/pgsql-13/bin/postgresql-13-setup initdb

systemctl enable chronyd squid firewalld consul --now

sudo -i -u postgres <<EOG
grep -Pv '^[\s]*#|^$' /var/lib/pgsql/13/data/postgresql.conf
echo -e "listen_addresses = '*'\nwal_level = 'replica'\n"| tee -a /var/lib/pgsql/13/data/postgresql.conf
export PATH="/usr/pgsql-13/bin:$PATH"
echo 'source /etc/bashrc;[ -f /etc/profile ] && source /etc/profile;export PGDATA=/var/lib/pgsql/13/data;export PATH="/usr/pgsql-13/bin:$PATH";[ -f /var/lib/pgsql/.pgsql_profile ] && source /var/lib/pgsql/.pgsql_profile' >> ~/.bashrc
EOG
systemctl enable --now postgresql-13

firewall-cmd --zone=work --add-source=$mip --permanent
firewall-cmd --zone=work --add-source=10.0.130.0/24 --permanent
firewall-cmd --zone=work --add-port={5432,55432,6432,8300,8301,8302,8500,8600,80,443,55555,3128,8008}/tcp --permanent
firewall-cmd --zone=work --add-port=1194/udp --permanent
firewall-cmd --reload

cat >> /var/lib/pgsql/13/data/pg_hba.conf <<EOI
host    replication     all     10.0.130.0/24                 scram-sha-256
host    all     all             10.0.130.0/24                 scram-sha-256
EOI
test ! -z "$mip" && echo "host    all     all    $mip/32                 scram-sha-256" >> /var/lib/pgsql/13/data/pg_hba.conf
cd /tmp
sudo -u postgres psql -c "select pg_reload_conf() "

sudo -u postgres psql -c "alter role postgres password 'test123Rs'; CREATE USER rewind_user LOGIN password 'testReW1nd'; GRANT EXECUTE ON function pg_catalog.pg_ls_dir(text, boolean, boolean) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_stat_file(text, boolean) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO rewind_user; CREATE USER patroni WITH SUPERUSER PASSWORD 'ParTest123' ; create user patronr with replication password 'ReplTest123' ; "

yum install -y patroni-consul $disablereps # postgresql13-plpython3 #sudo patroni --generate-sample-config /etc/patroni/patroni.conf

sleep 1m
sudo -u uuu -i <<EOS
sudo cp /etc/consul.d/consul.json ~uuu
sudo chown uuu ~uuu/*
tar -cf yum.tar /var/cache/yum/
scp -o "StrictHostKeyChecking=no" 2_sub.sh consul-1.17.2-1.el7.x86_64.rpm consul-template 1_run_master.sh patroni.yml .env consul.json pgdg-redhat-repo-latest.noarch.rpm yum.tar va:~
ssh va sudo ./2_sub.sh 
scp -o "StrictHostKeyChecking=no" 2_sub.sh consul-1.17.2-1.el7.x86_64.rpm consul-template 1_run_master.sh patroni.yml .env consul.json pgdg-redhat-repo-latest.noarch.rpm yum.tar vd:~
ssh vd sudo ./2_sub.sh
consul members
EOS

cp ~uuu/patroni.yml /etc/patroni/patroni.yml
chown postgres.postgres /etc/patroni/patroni.yml
localip=`ip addr show eth0|grep -Po 'inet ([0-9.]*)'|grep -Po '[0-9.]*'`
sed -i "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g" /etc/patroni/patroni.yml

#sudo yum -y install go $disablereps ; git clone https://github.com/hashicorp/consul-template.git; cd consul-template ; make dev 
## https://github.com/hashicorp/consul-template/blob/main/examples/haproxy.md
systemctl disable postgres-13
sudo -u postgres psql -c "SELECT pg_postmaster_start_time();"
test "`consul members|grep server |wc -l`" -ge 2 || exit 1 
systemctl enable --now patroni
patronictl -c /etc/patroni/patroni.yml list 
sudo -u postgres psql -c "SELECT pg_postmaster_start_time();"
systemctl status patroni && ssh va sudo systemctl enable patroni --now
systemctl status patroni && ssh vd sudo systemctl enable patroni --now

cp /etc/haproxy/haproxy.cfg{,.1}
cat > /etc/haproxy/haproxy.conf.ctmpl <<EOJ
global
    daemon
    maxconn {{key "service/haproxy/maxconn"}}

defaults
    mode {{key "service/haproxy/mode"}}{{range ls "service/haproxy/timeouts"}}
    timeout {{.Key}} {{.Value}}{{end}}

listen http-in
    bind *:8000{{range service "release.web"}}
    server {{.Node}} {{.Address}}:{{.Port}}{{end}}
EOJ



