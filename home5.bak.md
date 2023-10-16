# Установка и настройка PostgreSQL #
## Цель: ##
- создавать дополнительный диск для уже существующей виртуальной машины, размечать его и делать на нем файловую систему
- переносить содержимое базы данных PostgreSQL на дополнительный диск
- переносить содержимое БД PostgreSQL между виртуальными машинами

# Описание/Пошаговая инструкция выполнения домашнего задания: #
- [x] создайте виртуальную машину c Ubuntu 20.04/22.04 LTS в GCE/ЯО/Virtual Box/докере
```sh
cat > Dockerfile<<EOF
from ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow
ENV LANG="ru_RU.UTF-8"
ENV LC_ALL="ru_RU.UTF-8"
RUN apt update && apt install locales && sed -i '/ru_RU.UTF-8/s/^# //g' /etc/locale.gen && locale-gen && apt install postgresql -y && apt clean all 
EXPOSE 5433
USER postgres
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/postgresql/14/bin"
ENV PGDATA=/etc/postgresql/14/main/
VOLUME /var/lib/postgresql/14/main/
CMD ["/usr/lib/postgresql/14/bin/postgres"]
ARG pgdb:22.04.14
RUN sed -i 's/127.0.0.1\/32/0.0.0.0\/0/g' /etc/postgresql/14/main/pg_hba.conf && echo "listen_addresses = '*'">> /etc/postgresql/14/main/postgresql.conf
EOF

cat > compose.yaml <<EOF
version: "3.8"

networks:
  testnet:
    external: true

services:
 pgdb6:
  image: pgdb:22.04.14
  build: .
  networks:
    - testnet
  ports:
    - "5433:5432"
  volumes:
    - /var/lib/postgresql/data6:/var/lib/postgresql/data
EOF
docker-compose up -d
docker exec  `docker ps -q -f name=pgdb6` psql -c "alter role postgres password 'test1234'"
docker exec  `docker ps -q -f name=pgdb6` psql -c "create database testdb"
docker exec -it `docker ps -q` psql testdb -c "create table testtab as select x from string_to_table('1,2,3,4,5,6,7,8,9',',')x;  create table test(c1 text); insert into test values('1')"
```
- [x] поставьте на нее PostgreSQL 15 через _sudo apt_
- [x] проверьте что кластер запущен через _sudo -u postgres pg_lsclusters_
- [x]  зайдите из под пользователя postgres в _psql_ и сделайте произвольную таблицу с произвольным содержимым
>  _postgres=# create table test(c1 text); postgres=# insert into test values('1');_

```
root@DESKTOP-QNEC4IV:~# docker exec -it `docker ps -q` psql
psql (14.9 (Ubuntu 14.9-0ubuntu0.22.04.1))
Type "help" for help.

postgres=# \l+
                                                                List of databases
   Name    |  Owner   | Encoding | Collate |  Ctype  |   Access privileges   |  Size   | Tablespace |                Description
-----------+----------+----------+---------+---------+-----------------------+---------+------------+--------------------------------------------
 postgres  | postgres | UTF8     | C.UTF-8 | C.UTF-8 |                       | 8553 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres          +| 8401 kB | pg_default | unmodifiable empty database
           |          |          |         |         | postgres=CTc/postgres |         |            |
 template1 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres          +| 8401 kB | pg_default | default template for new databases
           |          |          |         |         | postgres=CTc/postgres |         |            |
 testdb    | postgres | UTF8     | C.UTF-8 | C.UTF-8 |                       | 8601 kB | pg_default |
(4 rows)

postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# \dt+
                                    List of relations
 Schema |  Name   | Type  |  Owner   | Persistence | Access method | Size  | Description
--------+---------+-------+----------+-------------+---------------+-------+-------------
 public | test    | table | postgres | permanent   | heap          | 16 kB |
 public | testtab | table | postgres | permanent   | heap          | 16 kB |
(2 rows)

testdb=#
```

- [+] остановите postgres например через sudo -u postgres pg_ctlcluster 15 main stop
_docker-compose down_
```
Stopping t6_pgdb6_1 ... done
Removing t6_pgdb6_1 ... done
Network testnet is external, skipping
```
- [+] создайте новый диск к ВМ размером 10GB
```
#dd if=/dev/zero of=disk.img bs=1M count=10000
fallocate -l 10G disk.img
mkfs.ext4 disk.img
losetup /dev/loop0 disk.img
mount /dev/loop0 /media/
```
- [+] добавьте свеже-созданный диск к виртуальной машине - надо зайти в режим ее редактирования и дальше выбрать пункт attach existing disk
```
cat > compose.yaml <<EOF
version: "3.8"

networks:
  testnet:
    external: true

services:
 pgdb6:
  image: pgdb:22.04.14
  build: .
  networks:
    - testnet
  ports:
    - "5433:5432"
  volumes:
    - /var/lib/postgresql/data6:/var/lib/postgresql/data
    - /media:/home
EOF
docker-compose up -d

```
- [+] проинициализируйте диск согласно инструкции и подмонтировать файловую систему, только не забывайте менять имя диска на актуальное, в вашем случае это скорее всего будет /dev/sdb - 
- [+] перезагрузите инстанс и убедитесь, что диск остается примонтированным (если не так смотрим в сторону fstab)
docker exec  `docker ps -a -q -f name=pgdb6` mount
- [+] сделайте пользователя postgres владельцем /mnt/data - chown -R postgres:postgres /mnt/data/
```
docker stop  `docker ps -a -q -f name=pgdb6`
docker run   `docker ps -q -f name=pgdb6` --entrypoint bash

```
- [ ] перенесите содержимое /var/lib/postgres/15 в /mnt/data - mv /var/lib/postgresql/15/mnt/data
- [ ] попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
> ## напишите получилось или нет и почему ##
### . ###
- [ ]   - задание: найти конфигурационный параметр в файлах раположенных в /etc/postgresql/15/main который надо поменять и поменяйте его
```
```
> ## напишите что и почему поменяли ##
### . ###
```
```
- [ ] попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
>  ##  напишите получилось или нет и почему ##
### . ###

- [ ] зайдите через через psql и проверьте содержимое ранее созданной таблицы
 
```
```

> ## задание со звездочкой * ##
> не удаляя существующий инстанс ВМ сделайте новый, поставьте на его PostgreSQL, удалите файлы с данными из /var/lib/postgres, перемонтируйте внешний диск который сделали ранее от первой виртуальной машины ко второй и запустите PostgreSQL на второй машине так чтобы он работал с данными на внешнем диске, расскажите как вы это сделали и что в итоге получилось.
### . ###
