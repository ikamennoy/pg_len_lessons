#!/bin/bash
test `whoami` = "root" || exit 0
cd /home/uuu
test -f .env && source .env
echo $mip

cat >/dev/null <<EON
cat <<EOI >> /usr/share/doc/glibc-common-2.17/gai.conf
precedence ::ffff:0:0/96  100
precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence ::/96          20
EOI
sysctl net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.all.disable_ipv6=0
EON

mv -f ~/.ssh/known_hosts{,2}
sed -i 's/keepcache=0/keepcache=1/g' /etc/yum.conf
usermod -aG wheel -G systemd-journal -G adm uuu
localip=`ip addr show eth0|grep -Po 'inet ([0-9.]*)'|grep -Po '[0-9.]*'|head -n 1`
yum install -y wget deltarpm --downloaddir=/home/uuu/
wget https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ls -hs /home/uuu/*.rpm
ls -1 *.rpm | xargs yum -y localinstall
echo '{"server": true,"data_dir": "/var/lib/consul","log_level": "INFO","ui_config":{"enabled":true},"rejoin_after_leave": true,"leave_on_terminate": false,"retry_join": ["va","vb","vd"],"bootstrap": false, "bootstrap_expect": 3 }' > /etc/consul.d/consul.json
chown consul.consul /etc/consul.d/consul.json
gunzip consul-template.gz
cp consul-template /usr/bin/
test -f /usr/bin/consul || exit 1
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
yum install -y firewalld epel-release chrony wget zip unzip jq vim curl lsof git telnet keepalived haproxy $disablereps --downloaddir=/home/uuu/
test -f /usr/bin/vim || exit 1
consul -autocomplete-install
mkdir /etc/squid/
cat <<EOSQ > /etc/squid/squid.conf
dns_v4_first on
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
acl good2 dstdomain .rbc.ru
acl block_port port 443
acl block_port port 80
acl CONNECT method CONNECT
http_access allow good
http_access allow good2
http_access deny all
http_access deny block_port
http_port 55558
coredump_dir /var/spool/squid
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern (\.xml|xml\.gz)$      0       20%     2880
refresh_pattern ((sqlite.bz2)*)$      0       20%     2880
refresh_pattern (\.deb|\.udeb)$   1296000 100% 1296000
refresh_pattern (\.rpm|\.srpm)$   1296000 100% 1296000
refresh_pattern .        0    20%    4320
EOSQ
sed -ie "s/IPADDR/$localip/g" /etc/squid/squid.conf
systemctl enable chronyd firewalld consul --now
#grep -e no_proxy /etc/environment || echo -e 'http_proxy=http://vb:55558\nhttps_proxy=http://vb:55558\nno_proxy=127.0.0.1,vb,va,vd,*.internal,localhost,*.testnet.tech' >> /etc/environment
#. /etc/environment
firewall-cmd --zone=work --add-source=$mip --permanent
firewall-cmd --zone=work --add-source=10.0.130.0/24 --permanent
firewall-cmd --zone=work --add-port={5432,55432,6432,8300,8301,8302,8500,8600,80,443,55558,3128,8008,55700,5000,5001}/tcp --permanent
firewall-cmd --zone=work --add-port=1194/udp --permanent
firewall-cmd --reload


yum install -y postgresql13-server postgres13-agent python-psycopg2 $disablereps --downloaddir=/home/uuu/
test -f /var/lib/pgsql/13/data/pg_hba.conf || /usr/pgsql-13/bin/postgresql-13-setup initdb

sudo -i -u postgres <<EOG
grep -Pv '^[\s]*#|^$' /var/lib/pgsql/13/data/postgresql.conf
echo -e "listen_addresses = '*'\nwal_level = 'replica'\n"| tee -a /var/lib/pgsql/13/data/postgresql.conf
export PATH="/usr/pgsql-13/bin:$PATH"
echo 'source /etc/bashrc;[ -f /etc/profile ] && source /etc/profile;export PGDATA=/var/lib/pgsql/13/data;export PATH="/usr/pgsql-13/bin:$PATH";[ -f /var/lib/pgsql/.pgsql_profile ] && source /var/lib/pgsql/.pgsql_profile' >> ~/.bashrc
EOG
systemctl enable --now postgresql-13

cat >> /var/lib/pgsql/13/data/pg_hba.conf <<EOI
host    replication     all     10.0.130.0/24                 scram-sha-256
host    all     all             10.0.130.0/24                 scram-sha-256
EOI
test ! -z "$mip" && echo "host    all     all    $mip/32                 scram-sha-256" >> /var/lib/pgsql/13/data/pg_hba.conf
(
cd /tmp
sudo -u postgres psql -c "select pg_reload_conf() "

sudo -u postgres psql -c "alter role postgres password 'test123Rs'; CREATE USER rewind_user LOGIN password 'testReW1nd'; GRANT EXECUTE ON function pg_catalog.pg_ls_dir(text, boolean, boolean) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_stat_file(text, boolean) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text) TO rewind_user; GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO rewind_user; CREATE USER patroni WITH SUPERUSER PASSWORD 'ParTest123' ; create user patronr with replication password 'ReplTest123' ; "
)

yum install -y patroni-consul $disablereps --downloaddir=/home/uuu/ # postgresql13-plpython3 #sudo patroni --generate-sample-config /etc/patroni/patroni.conf

cp /etc/haproxy/haproxy.cfg{,.1}
cat <<EOH > /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    maxconn     90
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    retries                 5
    timeout connect         5s
    timeout client          30m
    timeout server          30m
    timeout check           1s

listen stats
    mode http
    bind 0.0.0.0:55700
    stats enable
    stats uri /

listen batman
    bind *:5000
    option tcplog
    option httpchk OPTIONS /master
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 4 on-marked-down shutdown-sessions
    server vb vb:5432 maxconn 90 check port 8008
    server va va:5432 maxconn 90 check port 8008
    server vd vd:5432 maxconn 90 check port 8008

listen replicas
    bind *:5001
    option tcplog
    option httpchk OPTIONS /replica
    balance roundrobin
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 2 on-marked-down shutdown-sessions
    server va va:5432 check port 8008
    server vb vb:5432 check port 8008
    server vd vd:5432 check port 8008
EOH
cp /etc/haproxy/haproxy.cfg /home/uuu/haproxy.cfg

cp /etc/keepalived/keepalived.conf{,.1}
cat <<EOK > /home/uuu/keepalived.conf.0
global_defs {
   router_id HOSTNAME
}

vrrp_script chk_haproxy {
        script "killall -0 haproxy"
        interval 1
        weight -20
        debug
        fall 2
        rise 2
}

vrrp_instance HOSTNAME {
        interface eth0
        state BACKUP
        virtual_router_id 150
        priority 1
        authentication {
            auth_type PASS
            auth_pass VeryTestSecret_for_vrrp_auth
        }
        track_script {
                chk_haproxy weight 20
        }
        virtual_ipaddress {
                10.0.130.200/24 dev eth0
        }
        notify_master "/usr/bin/logger 'warn HOSTNAME became MASTER'"
        notify_backup "/usr/bin/logger 'info HOSTNAME became BACKUP'"
        notify_fault "/usr/bin/logger 'error HOSTNAME became FAULT'"

}
EOK
sed "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g;s/BACKUP/MASTER/" /home/uuu/keepalived.conf.0 > /etc/keepalived/keepalived.conf
echo -e 'TYPE=Ethernet\nDEVICE=eth0:1' > /etc/sysconfig/network-scripts/ifcfg-eth0:1
systemctl enable keepalived --now

cp /etc/consul.d/consul.json /home/uuu
cp {/etc/haproxy/,/home/uuu/}haproxy.cfg
sudo chown uuu /home/uuu/*
#tar -cf yum.tar /var/cache/yum/;ls -hs yum.tar
SSHOPS="-o StrictHostKeyChecking=no -i /home/uuu/.ssh/id_rsa"
cd /home/uuu
scp $SSHOPS 2_sub.sh *.rpm consul-template 1_run_master.sh patroni.yml .env consul.json pgdg-redhat-repo-latest.noarch.rpm haproxy.cfg keepalived.conf.0 uuu@va:~
ssh $SSHOPS uuu@va sudo ./2_sub.sh 
scp $SSHOPS 2_sub.sh *.rpm consul-template 1_run_master.sh patroni.yml .env consul.json pgdg-redhat-repo-latest.noarch.rpm haproxy.cfg keepalived.conf.0 uuu@vd:~
ssh $SSHOPS uuu@vd sudo ./2_sub.sh
consul members
tail -n 30 /var/log/messages

cp /home/uuu/patroni.yml /etc/patroni/patroni.yml
chown postgres.postgres /etc/patroni/patroni.yml
sed -i "s/IPADDR/$localip/g;s/HOSTNAME/`hostname`/g" /etc/patroni/patroni.yml

#sudo yum -y install go $disablereps ; git clone https://github.com/hashicorp/consul-template.git; cd consul-template ; make dev 
## https://github.com/hashicorp/consul-template/blob/main/examples/haproxy.md
systemctl disable postgres-13
(cd /tmp
sudo -u postgres psql -c "SELECT pg_postmaster_start_time();"
test "`consul members|grep server |wc -l`" -ge 2 || exit 1 
systemctl enable --now patroni
patronictl -c /etc/patroni/patroni.yml list 
sudo -u postgres psql -c "SELECT pg_postmaster_start_time();"
)
systemctl status patroni && ssh va sudo systemctl enable patroni haproxy keepalived --now
systemctl status patroni && ssh vd sudo systemctl enable patroni haproxy keepalived --now

