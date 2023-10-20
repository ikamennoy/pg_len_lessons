# _Домашнее задание_ #
# Работа с базами данных, пользователями и правами #

## Цель: ##
- создание новой базы данных, схемы и таблицы
- создание роли для чтения данных из созданной схемы созданной базы данных
- создание роли для чтения и записи из созданной схемы созданной базы данных

## Описание/Пошаговая инструкция выполнения домашнего задания: ##
 - [x] 1. создайте новый кластер PostgresSQL 14

### testdb.sql ###
```sql
create schema testnm;
create table testnm.t1 (c1 int4);
insert into testnm.t1 select 1 as c1 ;
create role readonly;
grant usage on schema testnm to readonly;
grant select on all tables in schema testnm to readonly ;
create role testread password 'test123' in role readonly LOGIN ;
```

### once.sh ###
```sh
#!/bin/bash
dpkg -l|grep postgres && exit 0
grep -e '^ru_RU.UTF-8' /etc/locale.gen && exit 0
apt update
timedatectl set-timezone Europe/Moscow
sed -i "/ru_RU.UTF-8/s/^# //g" /etc/locale.gen
locale-gen
echo 'LC_ALL=ru_RU.UTF-8'>>/etc/environment
apt install postgresql -y
echo 'Install complete'
systemctl enable postgresql
systemctl start postgresql
sleep 2s
sudo -u postgres psql -c "create database testdb"
sudo -u postgres psql testdb -f /tmp/testdb.sql
rm /etc/cron.d/once
```

### получаем base64 строки для мета данных ВМ ###
```sh
# get base64 sql
x=`cat testdb.sql|base64`;x=`echo $x|sed 's/ //g'`;echo $x

# get base64 string for shell-script
x=`cat once.sh|base64`;x=`echo $x|sed 's/ //g'`;echo $x
```

### Делаем meta.yaml ###
```yaml
#cloud-config
users:
  - name: uuu
    groups: sudo
    password: test123
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    lock_passwd: false
    passwd: $6$rounds=4096$cqmfub.dYCnZmyQb$wNrGtu3PP6A52owXADP8Bn00TohzMXQYJ11KahSryoEGl6uo6TDrs2K/NhhBeUSPycEeKz8147EUEP9i6ijkE.
    ssh-authorized-keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD1+72sIJ4TmXAvHCUCbMb+IwsdVh6dG1KR6xhd3q6Bimm3QwbhGtfGvs+Wp//0Z3CBIFepEriRKc2Nj0+c0M6qHAmyL1SeCHVz9+078XBlI1YWQs4vf6N4HBQ5i6euRYCJ1u8TouRlkNBaEc3C/BvXSwZ0O8gQfSd2bBtjQS4p7f8zp8Mgk2Yn4Ly9b5NlpreZTPQ1vYOfGs3Z3UrXGDkhW9a2DkCgA2ldHAwACzYvr3lipMtsPVTf+V9daMrVDB/rPSyW/1d/APFyt/7qgJncUSTMPyNqOzsy5RqIJdZV4LOKpk3NqtlIH35E03QKFOXW0zRBdjLMu/AQ6viudKHH

bootcmd:
  - whoami
  - apt update
  - echo IyEvYmluL2Jhc2gKZHBrZyAtbHxncmVwIHBvc3RncmVzICYmIGV4aXQgMApncmVwIC1lICdecnVfUlUuVVRGLTgnIC9ldGMvbG9jYWxlLmdlbiAmJiBleGl0IDAKYXB0IHVwZGF0ZQp0aW1lZGF0ZWN0bCBzZXQtdGltZXpvbmUgRXVyb3BlL01vc2NvdwpzZWQgLWkgIi9ydV9SVS5VVEYtOC9zL14jIC8vZyIgL2V0Yy9sb2NhbGUuZ2VuCmxvY2FsZS1nZW4KZWNobyAnTENfQUxMPXJ1X1JVLlVURi04Jz4+L2V0Yy9lbnZpcm9ubWVudAphcHQgaW5zdGFsbCBwb3N0Z3Jlc3FsIC15CmVjaG8gJ0luc3RhbGwgY29tcGxldGUnCnN5c3RlbWN0bCBlbmFibGUgcG9zdGdyZXNxbApzeXN0ZW1jdGwgc3RhcnQgcG9zdGdyZXNxbApzbGVlcCAycwpzdWRvIC11IHBvc3RncmVzIHBzcWwgLWMgImNyZWF0ZSBkYXRhYmFzZSB0ZXN0ZGIiCnN1ZG8gLXUgcG9zdGdyZXMgcHNxbCB0ZXN0ZGIgLWYgL3RtcC90ZXN0ZGIuc3FsCnJtIC9ldGMvY3Jvbi5kL29uY2UKCg== | base64 -d > /tmp/once.sh
  - echo Y3JlYXRlIHNjaGVtYSB0ZXN0bm07CmNyZWF0ZSB0YWJsZSB0ZXN0bm0udDEgKGMxIGludDQpOwppbnNlcnQgaW50byB0ZXN0bm0udDEgc2VsZWN0IDEgYXMgYzEgOwpjcmVhdGUgcm9sZSByZWFkb25seTsKZ3JhbnQgdXNhZ2Ugb24gc2NoZW1hIHRlc3RubSB0byByZWFkb25seTsKZ3JhbnQgc2VsZWN0IG9uIGFsbCB0YWJsZXMgaW4gc2NoZW1hIHRlc3RubSB0byByZWFkb25seSA7CmNyZWF0ZSByb2xlIHRlc3RyZWFkIHBhc3N3b3JkICd0ZXN0MTIzJyByb2xlIHJlYWRvbmx5IExPR0lOIDsK | base64 -d > /tmp/testdb.sql
  - chmod a+x /tmp/once.sh
  - echo '* * * * * root /tmp/once.sh' > /etc/cron.d/once
```

### Создаем ВМ, сеть, подсеть ###
```sh
yc vpc network create --name testnetb
yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.10/24'
yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 2G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2
yc compute instance add-one-to-one-nat tu22p --network-interface-index 0
yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu
```
```console
id: enppqdluuetgaqd1e7ql
created_at: "2023-10-19T19:34:01Z"
name: testnetb
```
```console
id: e2lmaqnnqod3dob6q9re
created_at: "2023-10-19T19:35:35Z"
name: subnetb
network_id: enppqdluuetgaqd1e7ql
zone_id: ru-central1-b
v4_cidr_blocks:
  - 10.0.130.0/24
```

```console
done (59s)
id: epdgqtq57oa6ot761l1l
created_at: "2023-10-19T19:37:08Z"
name: tu22p
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "2147483648"
  cores: "2"
  core_fraction: "20"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epdkc7p3v685mhrh1nas
  auto_delete: true
  disk_id: epdkc7p3v685mhrh1nas
network_interfaces:
  - index: "0"
    mac_address: d0:0d:10:d7:74:53
    subnet_id: e2lmaqnnqod3dob6q9re
    primary_v4_address:
      address: 10.0.130.31
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy:
  preemptible: true
network_settings:
  type: STANDARD
placement_policy: {}
```
```console
done (11s)
id: epdgqtq57oa6ot761l1l
created_at: "2023-10-19T19:37:08Z"
name: tu22p
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "2147483648"
  cores: "2"
  core_fraction: "20"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epdkc7p3v685mhrh1nas
  auto_delete: true
  disk_id: epdkc7p3v685mhrh1nas
network_interfaces:
  - index: "0"
    mac_address: d0:0d:10:d7:74:53
    subnet_id: e2lmaqnnqod3dob6q9re
    primary_v4_address:
      address: 10.0.130.31
      one_to_one_nat:
        address: 84.201.140.125
        ip_version: IPV4
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy:
  preemptible: true
network_settings:
  type: STANDARD
placement_policy: {}
```

- [x] 2. зайдите в созданный кластер под пользователем postgres
- [x] 3. создайте новую базу данных testdb
- [x] 4. зайдите в созданную базу данных под пользователем postgres
- [x] 5. создайте новую схему testnm
- [x] 6. создайте новую таблицу t1 с одной колонкой c1 типа integer
- [x] 7. вставьте строку со значением c1=1
- [x] 8. создайте новую роль readonly
- [x] 9. дайте новой роли право на подключение к базе данных testdb
- [x] 10. дайте новой роли право на использование схемы testnm
- [x] 11. дайте новой роли право на select для всех таблиц схемы testnm
- [x] 12. создайте пользователя testread с паролем test123
- [x] 13. дайте роль readonly пользователю testread
- [x] 14 зайдите под пользователем testread в базу данных testdb
```sh
echo 'localhost:5432:testdb:testread:test123'>/home/uuu/.pgpass
chmod 600 /home/uuu/.pgpass
psql -h localhost testdb -U testread
```
- [x] 15. сделайте select * from t1;
```console
psql -h localhost testdb -U testread -c "select * from testnm.t1"
 c1
----
  1
(1 row)
```
> ### 16. получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже) ###
#### получилось ####
> 17. ### напишите что именно произошло в тексте домашнего задания ###
#### Авторизовались под ролью, которая добавлена в роль с доступом и получили содержимое таблицы.  ####
> 18. ### у вас есть идеи почему? ведь права то дали? ###
- [x]  19. посмотрите на список таблиц
```console
$ psql -h localhost testdb -U testread -c "select * from pg_catalog.pg_tables where tablename not similar to 'pg_[^ ]*|sql_[^ ]*'"|cat
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 testnm     | t1        | postgres   |            | f          | f        | f           | f
```
при создании указал явно схему, поэтому не попал в такую ловушку.

> 20. подсказка в шпаргалке под пунктом 20

> 21. а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)
#### явное задание схемы - облегчает жизнь ####
- [x] 22. вернитесь в базу данных testdb под пользователем postgres
- [x] 23. удалите таблицу t1
- [x] 24. создайте ее заново но уже с явным указанием имени схемы testnm
- [x] 25. вставьте строку со значением c1=1
- [x] 26. зайдите под пользователем testread в базу данных testdb
- [x] 27. сделайте select * from testnm.t1;
> ### 28. получилось? ###
> 29. ### есть идеи почему? если нет - смотрите шпаргалку ###
#### получилось ####

> 30. ### как сделать так чтобы такое больше не повторялось? если нет идей - смотрите шпаргалку ###
#### явно задавать схему. Добавлять право логин. Помнить синтаксис. Практика. Переопределение search_path  ###
- [x] 31. сделайте select * from testnm.t1;
####  в п 15. ###
> ### 32. получилось? ###
####  в п 15. ###
> ### 33. есть идеи почему? если нет - смотрите шпаргалку ###
####  в п 30. ###

- [x] 34. сделайте select * from testnm.t1;
> ### 35. получилось? ###
####  в п 15. ###
> ### 36 ура! ###
####  в п 15. ###
- [x] 37. теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
```console
$ psql -h localhost testdb -U testread -c "create table t2(c1 integer); insert into t2 values (2);"
CREATE TABLE
INSERT 0 1
```
> ### 38. а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly? ###
Потому что по умолчанию схема public, там по умолчанию права
- [x] 39. есть идеи как убрать эти права? если нет - смотрите шпаргалку
```sh
sudo -u postgres psql testdb -c " revoke create on schema public from public ; alter table t2 owner to postgres ;  "
```
```console
psql -h localhost testdb -U testread -c "create table t111 (c1 integer)"
ERROR:  permission denied for schema public
psql -h localhost testdb -U testread -c "insert into t2 values (2)"
ERROR:  permission denied for table t2
```
> ### 40. если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды ###
#### убрал право CREATE в базе testdb от Public (Каждый пользователь) // https://postgrespro.ru/docs/postgrespro/9.6/ddl-schemas#ddl-schemas-priv ###
#### Сменил владельца - так как права owner дают полные полномочия к таблице  ###
####  еще можно сменить  search_path ###
```console
testdb=> SET search_path TO testnm;
SET
testdb=> select * from t2;
ERROR:  relation "t2" does not exist
LINE 1: select * from t2;
```
- [x] 41. теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
```console
testdb=>  create table t3(c1 integer);
ERROR:  permission denied for schema testnm
LINE 1: create table t3(c1 integer);
                     ^
testdb=> insert into t2 values (2);
ERROR:  relation "t2" does not exist
LINE 1: insert into t2 values (2);
                    ^
testdb=>  create table public.t3(c1 integer);
ERROR:  permission denied for schema public
LINE 1: create table public.t3(c1 integer);
                     ^
testdb=> insert into public.t2 values (2);
ERROR:  permission denied for table t2
```
> ### 42. расскажите что получилось и почему ###
#### первая и вторая команда - потому что схема по умолчанию в search_path только testnm была. А последние 2 - потому что нет доступа даже при явном указании к схеме public ####


#### end ####
```sh
yc compute instance delete tu22p ; yc vpc subnet list|grep central|cut -d "|" -f 2 |xargs -n 1 yc vpc subnet delete; yc vpc network delete testnetb; 
```
