## реализовать свой миникластер на 3 ВМ. - *миниотчет с описанием шагов и с какими проблемами столкнулись*. ##

- [x] На 1 ВМ создаем таблицы test для записи, test2 для запросов на чтение.
```sh
yc vpc network create --name testnetb; yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'

for nam in p{2,3,4,1} ; do yc compute instance create --name $nam --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2-$nam,type=network-ssd,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname u$nam --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat $nam --network-interface-index 0 ; done

mip=`curl -s https://ipinfo.io/json|jq .ip|sed 's/"//g'`
#hosts=`yc --format json compute instance list  |  jq '.[] | .network_interfaces[0].primary_v4_address.one_to_one_nat.address ' |sed 's/"//g'`"
hosts="51.250.110.101 51.250.106.238 158.160.27.37 158.160.21.250"
for hostaddr in $hosts ; do ssh -i .ssh/yc_serialssh_key uuu@$hostaddr "sudo apt install firewalld -y ; sudo firewall-cmd --zone=work --add-source=$mip --permanent ; sudo firewall-cmd --zone=work --add-source=10.0.130.0/24 --permanent ; sudo firewall-cmd --zone=work --add-port=5432/tcp --permanent;sudo firewall-cmd --reload ; sudo -u postgres psql -c \"alter role postgres password 'test123Rs'\" ; sudo -u postgres psql -c \"alter system set listen_addresses='*' \" ; sudo -u postgres psql -c \"alter system set wal_level=logical \" ; echo -e \"host    all     all             $mip                 scram-sha-256\\nhost    replication     all     10.0.130.0/24                 scram-sha-256\nhost    all     all             10.0.130.0/24                 scram-sha-256\" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf ; sudo systemctl restart postgresql@15-main " ; done

export PGPASSWORD=test123Rs
```
```console
yc compute instance list
+----------------------+------+---------------+---------+----------------+-------------+
|          ID          | NAME |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+------+---------------+---------+----------------+-------------+
| epd2ppo9i7fnqa6tpuau | p1   | ru-central1-b | RUNNING | 51.250.110.101 | 10.0.130.8  |
| epdt6dvghkfi8jrfvnh5 | p2   | ru-central1-b | RUNNING | 51.250.106.238 | 10.0.130.28 |
| epdrerbisdal32gjpu7q | p3   | ru-central1-b | RUNNING | 158.160.27.37  | 10.0.130.23 |
| epdhf19np31n0m6143ur | p4   | ru-central1-b | RUNNING | 158.160.21.250 | 10.0.130.30 |
+----------------------+------+---------------+---------+----------------+-------------+

```
```sh
psql -h 51.250.110.101 -U postgres -w <<EOF
create table test (c1 int4, c2 varchar(300) );
create table test2 (c1 int4, c2 varchar(300) );
EOF

psql -h 51.250.106.238 -U postgres -w <<EOF
create table test (c1 int4, c2 varchar(300) );
create table test2 (c1 int4, c2 varchar(300) );
EOF
```

- [x] Создаем публикацию таблицы test и подписываемся на публикацию таблицы test2 с ВМ №2.
```sh
psql -h 51.250.110.101 -U postgres -w -c "CREATE PUBLICATION p1test FOR TABLE test; "
psql -h 51.250.106.238 -U postgres -w -c "CREATE PUBLICATION p2test2 FOR TABLE test2; "
psql -h 51.250.110.101 -U postgres -w -c "CREATE SUBSCRIPTION  p2test2 CONNECTION 'host=up2 port=5432 user=postgres password=test123Rs dbname=postgres' PUBLICATION p2test2 WITH (copy_data = true); "
psql -h 51.250.106.238 -U postgres -w -c "CREATE SUBSCRIPTION   p1test CONNECTION 'host=up1 port=5432 user=postgres password=test123Rs dbname=postgres' PUBLICATION p1test WITH (copy_data = true); "
```

- [x] На 2 ВМ создаем таблицы test2 для записи, test для запросов на чтение.
См ранее/ Вначале логично создавать PUBLICATION, потом уже SUBSCRIPTION

- [x] Создаем публикацию таблицы test2 и подписываемся на публикацию таблицы test1 с ВМ №1.
См ранее

- [x] 3 ВМ использовать как реплику для чтения и бэкапов (подписаться на таблицы из ВМ №1 и №2 ).
```sh
# необходимо создавать уникальное имя слота репликации при подписке
psql -h 158.160.27.37 -U postgres -c "create table test (c1 int4, c2 varchar(300) );create table test2 (c1 int4, c2 varchar(300) );"
psql -h 158.160.27.37 -U postgres -w -c "CREATE SUBSCRIPTION  s3test2 CONNECTION 'host=up2 port=5432 user=postgres password=test123Rs dbname=postgres' PUBLICATION p2test2 WITH (copy_data = true); "
psql -h 158.160.27.37 -U postgres -w -c "CREATE SUBSCRIPTION   s3test CONNECTION 'host=up1 port=5432 user=postgres password=test123Rs dbname=postgres' PUBLICATION p1test WITH (copy_data = true); "
EOF
```

```sh
psql -h 51.250.110.101 -U postgres -w -c "insert into test (c1) values (1)"
psql -h 51.250.106.238 -U postgres -w -c "insert into test2 (c1) values (2)"
psql -h 51.250.110.101 -U postgres -w -c "select c1 from test union select c1 from test2"
psql -h 51.250.106.238 -U postgres -w -c "select c1 from test union select c1 from test2;"
psql -h 158.160.27.37 -U postgres -w -c "select c1 from test union select c1 from test2;"
```
Добавленные строки выводятся, репликация работает

```console
echo "select pid,usename,application_name,client_addr,state,sent_lsn,write_lsn,flush_lsn,replay_lsn ,sync_state  from pg_stat_replication" > pg_stat_replication.sql
echo "select slot_name,plugin,slot_type,database,active,active_pid,restart_lsn,confirmed_flush_lsn,wal_status from pg_replication_slots" > pg_replication_slots.sql
# hosts=`yc --format json compute instance list  |  jq '.[] | .network_interfaces[0].primary_v4_address.one_to_one_nat.address ' |sed 's/"//g' `
hosts=`echo 10.0.130.{8,28,23}`
for addr in $hosts; do psql -h $addr -U postgres -w -c "select inet_server_addr()"  ; psql -h $addr -U postgres -w -f pg_stat_replication.sql ; psql -h $addr -U postgres -w -f pg_replication_slots.sql ; done
 inet_server_addr
------------------
 10.0.130.8
(1 row)

 pid  | usename  | application_name | client_addr |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | sync_state
------+----------+------------------+-------------+-----------+-----------+-----------+-----------+------------+------------
 9023 | postgres | p1test           | 10.0.130.28 | streaming | 0/50004F0 | 0/50004F0 | 0/50004F0 | 0/50004F0  | async
 9113 | postgres | s3test           | 10.0.130.23 | streaming | 0/50004F0 | 0/50004F0 | 0/50004F0 | 0/50004F0  | async
(2 rows)

 slot_name |  plugin  | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+----------+-----------+----------+--------+------------+-------------+---------------------+------------
 p1test    | pgoutput | logical   | postgres | t      |       9023 | 0/50004B8   | 0/50004F0           | reserved
 s3test    | pgoutput | logical   | postgres | t      |       9113 | 0/50004B8   | 0/50004F0           | reserved
(2 rows)


 10.0.130.28
(1 row)

 pid  | usename  | application_name | client_addr |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | sync_state
------+----------+------------------+-------------+-----------+-----------+-----------+-----------+------------+------------
 8293 | postgres | p2test2          | 10.0.130.8  | streaming | 0/3000408 | 0/3000408 | 0/3000408 | 0/3000408  | async
 8356 | postgres | s3test2          | 10.0.130.23 | streaming | 0/3000408 | 0/3000408 | 0/3000408 | 0/3000408  | async
(2 rows)

 slot_name |  plugin  | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+----------+-----------+----------+--------+------------+-------------+---------------------+------------
 p2test2   | pgoutput | logical   | postgres | t      |       8293 | 0/30003D0   | 0/3000408           | reserved
 s3test2   | pgoutput | logical   | postgres | t      |       8356 | 0/30003D0   | 0/3000408           | reserved
(2 rows)


 inet_server_addr
------------------
 10.0.130.23
(1 row)

 pid | usename | application_name | client_addr | state | sent_lsn | write_lsn | flush_lsn | replay_lsn | sync_state
-----+---------+------------------+-------------+-------+----------+-----------+-----------+------------+------------
(0 rows)

 slot_name | plugin | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+--------+-----------+----------+--------+------------+-------------+---------------------+------------
(0 rows)

 inet_server_addr
------------------


```

- [x] реализовать горячее реплицирование для высокой доступности на 4ВМ. Источником должна выступать ВМ №3. Написать с какими проблемами столкнулись.

```sh
psql -h 158.160.27.37 -U postgres -w <<EOF
alter system set synchronous_commit = on;
select pg_reload_conf();
EOF

ssh uuu@158.160.21.250 -i .ssh/yc_serialssh_key <<EOF
sudo systemctl stop postgresql@15-main
sudo -i -u postgres
rm -fr /var/lib/postgresql/15/main
mkdir -p /var/lib/postgresql/15/main
chmod 700 /var/lib/postgresql/15/main # права на папку важны
export PGPASSWORD=test123Rs
pg_basebackup -h up3 -U postgres -R -D /var/lib/postgresql/15/main -w
# echo -e "host    replication     all     10.0.130.0/24                 scram-sha-256\nhost    all     all             10.0.130.0/24                 scram-sha-256">> /etc/postgresql/15/main/pg_hba.conf
echo 'listen_addresses=*' >> /etc/postgresql/15/main/postgresql.auto.conf # нужно заново задать listen_addresses
exit
sudo systemctl start postgresql@15-main
sudo systemctl status postgresql@15-main
EOF

psql -h 158.160.21.250 -U postgres -w <<EOF
alter system set hot_standby_feedback =off;
alter system set max_standby_streaming_delay = 0;
select pg_reload_conf();
EOF

```
```console
#hosts=`yc --format json compute instance list  |  jq '.[] | .network_interfaces[0].primary_v4_address.one_to_one_nat.address ' |sed 's/"//g'`"
hosts="51.250.110.101 51.250.106.238 158.160.27.37 158.160.21.250"
for addr in $hosts; do psql -h $addr -U postgres -w -c "select inet_server_addr()"  ; psql -h $addr -U postgres -w -f pg_stat_replication.sql ; psql -h $addr -U postgres -w -f pg_replication_slots.sql ; done

 inet_server_addr
------------------
 10.0.130.8
(1 row)

 pid  | usename  | application_name | client_addr |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | sync_state
------+----------+------------------+-------------+-----------+-----------+-----------+-----------+------------+------------
 9023 | postgres | p1test           | 10.0.130.28 | streaming | 0/50004F0 | 0/50004F0 | 0/50004F0 | 0/50004F0  | async
 9113 | postgres | s3test           | 10.0.130.23 | streaming | 0/50004F0 | 0/50004F0 | 0/50004F0 | 0/50004F0  | async
(2 rows)

 slot_name |  plugin  | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+----------+-----------+----------+--------+------------+-------------+---------------------+------------
 p1test    | pgoutput | logical   | postgres | t      |       9023 | 0/50004B8   | 0/50004F0           | reserved
 s3test    | pgoutput | logical   | postgres | t      |       9113 | 0/50004B8   | 0/50004F0           | reserved
(2 rows)

 inet_server_addr
------------------
 10.0.130.28
(1 row)

 pid  | usename  | application_name | client_addr |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | sync_state
------+----------+------------------+-------------+-----------+-----------+-----------+-----------+------------+------------
 8293 | postgres | p2test2          | 10.0.130.8  | streaming | 0/3000408 | 0/3000408 | 0/3000408 | 0/3000408  | async
 8356 | postgres | s3test2          | 10.0.130.23 | streaming | 0/3000408 | 0/3000408 | 0/3000408 | 0/3000408  | async
(2 rows)

 slot_name |  plugin  | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+----------+-----------+----------+--------+------------+-------------+---------------------+------------
 p2test2   | pgoutput | logical   | postgres | t      |       8293 | 0/30003D0   | 0/3000408           | reserved
 s3test2   | pgoutput | logical   | postgres | t      |       8356 | 0/30003D0   | 0/3000408           | reserved
(2 rows)

 inet_server_addr
------------------
 10.0.130.23
(1 row)

  pid  | usename  | application_name | client_addr |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | sync_state
-------+----------+------------------+-------------+-----------+-----------+-----------+-----------+------------+------------
 10434 | postgres | 15/main          | 10.0.130.30 | streaming | 0/9000148 | 0/9000148 | 0/9000148 | 0/9000148  | async
(1 row)

 slot_name | plugin | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+--------+-----------+----------+--------+------------+-------------+---------------------+------------
(0 rows)

 inet_server_addr
------------------
 10.0.130.30
(1 row)

 pid | usename | application_name | client_addr | state | sent_lsn | write_lsn | flush_lsn | replay_lsn | sync_state
-----+---------+------------------+-------------+-------+----------+-----------+-----------+------------+------------
(0 rows)

 slot_name | plugin | slot_type | database | active | active_pid | restart_lsn | confirmed_flush_lsn | wal_status
-----------+--------+-----------+----------+--------+------------+-------------+---------------------+------------
(0 rows)
```
