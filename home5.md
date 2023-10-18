# Установка и настройка PostgreSQL #
## Цель: ##
- создавать дополнительный диск для уже существующей виртуальной машины, размечать его и делать на нем файловую систему
- переносить содержимое базы данных PostgreSQL на дополнительный диск
- переносить содержимое БД PostgreSQL между виртуальными машинами

# Описание/Пошаговая инструкция выполнения домашнего задания: #
- [x] создайте виртуальную машину c Ubuntu 20.04/22.04 LTS в GCE/ЯО/Virtual Box/докере
```sh
echo > meta.yaml <<EOF
#cloud-config
users:
  - name: uuu
    groups: sudo
    password: test123
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    lock_passwd: false
    passwd: $6$rounds=4096$cqmfub.dYCnZmyQb$wNrGtu3PP6A52owXADP...
    ssh-authorized-keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD1+72sIJ4TmXAvHCUCbMb+...
EOF
```
```sh
yc compute instance create --name test-ubuntu-22 --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 2G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b ; yc compute instance add-one-to-one-nat epd1d2tdic1jli3of3hg --network-interface-index 0
```
```console
id: epd1d2tdic1jli3of3hg
created_at: "2023-10-18T18:34:11Z"
name: test-ubuntu-22
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "8589934592"
  cores: "2"
  core_fraction: "100"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epdmvnodslsn22kbcvtr
  auto_delete: true
  disk_id: epdmvnodslsn22kbcvtr
network_interfaces:
  - index: "0"
    mac_address: d0:0d:1c:fe:9a:67
    subnet_id: e2lsh3c20d5oj2qi5u59
    primary_v4_address:
      address: 10.129.0.14
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy: {}
network_settings:
  type: STANDARD
placement_policy: {}
```
```console
done (7s)
id: epd3c3t5itkatos00vbi
created_at: "2023-10-18T19:42:34Z"
name: test-vol1
type_id: network-hdd
zone_id: ru-central1-b
size: "10737418240"
block_size: "4096"
status: READY
disk_placement_policy: {}
```

- [x] поставьте на нее PostgreSQL 15 через sudo apt
```sh
yc compute connect-to-serial-port --instance-name test-ubuntu-22 --ssh-key .ssh/yc_serialssh_key --user uuu
## It ask login and pass from meta.yaml ##
```

```console
To exit terminal press Enter, and then '~' and '.' buttons
serial: Connected to instance epd1d2tdic1jli3of3hg (session ID: b091a7ac6cbcb2abe1ca55b47374425e4f7970ce3e843a23b914fdddc29568de)
545: Permissions for /etc/netplan/50-cloud-init.yaml are too open. Netplan configuration should NOT be accessible by others.
[   16.163565] cloud-init[577]: ** (process:592): WARNING **: 19:15:08.545: Permissions for /etc/netplan/50-cloud-init.yaml are too open. Netplan configuration should NOT be accessible by others.
[   16.166160] cloud-init[577]: Failed to connect system bus: No such file or directory
[  OK  ] Finished Wait for Network to be Configured.
[   16.168396] cloud-init[577]: WARNING:root:Falling back to a hard restart of systemd-networkd.service
[   16.205555] cloud-init[577]: 2023-10-18 19:15:08,734 - schema.py[WARNING]: Invalid cloud-config provided: Please run 'sudo cloud-init schema --system' to see the schema errors.
...
[   32.278461] cloud-init[927]: Cloud-init v. 23.3.1-0ubuntu1~22.04.1 finished at Wed, 18 Oct 2023 19:15:24 +0000. Datasource DataSourceEc2.  Up 32.27 seconds
[  OK  ] Finished Execute cloud user/final scripts.
[  OK  ] Reached target Cloud-init target.

Ubuntu 22.04.3 LTS upgtest ttyS0

upgtest login: uuu
Password:
```

```sh
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" |sudo tee /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-15

```

 - [x] проверьте что кластер запущен через sudo -u postgres pg_lsclusters

```sh
sudo -u postgres pg_lsclusters
```
```console
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5432 online postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
```
- [x]  зайдите из под пользователя postgres в psql и сделайте произвольную таблицу с произвольным содержимым
```sh
sudo -u postgres psql -c "create database testdb";echo -e "create table testtab as select x from string_to_table('1,2,3,4,5,6,7,8,9',',')x ;\n  create table test(c1 text); insert into test values('1');"> /tmp/1.sql;sudo -u postgres psql testdb -f /tmp/1.sql
```
```console
CREATE DATABASE
SELECT 9
CREATE TABLE
INSERT 0 1
```

- [x] остановите postgres например через sudo -u postgres pg_ctlcluster 15 main stop
```sh
sudo systemctl stop postgresql@15-main
```
- [x] создайте новый диск к ВМ размером 10GB
```sh
yc compute disk create --name test-vol1 --size 10G --zone ru-central1-b
# or # yc compute filesystem create --name test-vol1 -size 10G
```
```console
done (7s)
id: epd3c3t5itkatos00vbi
created_at: "2023-10-18T19:42:34Z"
name: test-vol1
type_id: network-hdd
zone_id: ru-central1-b
size: "10737418240"
block_size: "4096"
status: READY
disk_placement_policy: {}
```

- [x] добавьте свеже-созданный диск к виртуальной машине - надо зайти в режим ее редактирования и дальше выбрать пункт attach existing disk
```sh
yc compute instance attach-disk --disk-name test-vol1 --name test-ubuntu-22
```
```console
done (7s)
id: epd1d2tdic1jli3of3hg
created_at: "2023-10-18T19:14:07Z"
name: test-ubuntu-22
zone_id: ru-central1-b
platform_id: standard-v2
resources:
  memory: "2147483648"
  cores: "2"
  core_fraction: "100"
status: RUNNING
metadata_options:
  gce_http_endpoint: ENABLED
  aws_v1_http_endpoint: ENABLED
  gce_http_token: ENABLED
  aws_v1_http_token: DISABLED
boot_disk:
  mode: READ_WRITE
  device_name: epd9h2otf98l47podsnb
  auto_delete: true
  disk_id: epd9h2otf98l47podsnb
secondary_disks:
  - mode: READ_WRITE
    device_name: epd3c3t5itkatos00vbi
    disk_id: epd3c3t5itkatos00vbi
network_interfaces:
  - index: "0"
    mac_address: d0:0d:16:8b:ad:93
    subnet_id: e2lsh3c20d5oj2qi5u59
    primary_v4_address:
      address: 10.129.0.19
      one_to_one_nat:
        address: 62.84.123.225
        ip_version: IPV4
gpu_settings: {}
fqdn: upgtest.ru-central1.internal
scheduling_policy: {}
network_settings:
  type: STANDARD
placement_policy: {}
```

- [x] проинициализируйте диск согласно инструкции и подмонтировать файловую систему, только не забывайте менять имя диска на актуальное, в вашем случае это скорее всего будет /dev/sdb - https://www.digitalocean.com/community/tutorials/how-to-partition-and-format-storage-devices-in-linux
```
sudo -i
parted /dev/vdb mklabel msdos
parted -a opt /dev/vdb mkpart primary ext4 0% 100%
mkfs.ext4 /dev/vdb1 -m 0
e2label /dev/vdb1 testvol1
mkdir /opt/pgdata
echo 'LABEL=testvol1 /opt/pgdata ext4 defaults 0 0' |tee -a /etc/fstab
mount -a
```
- [x] перезагрузите инстанс и убедитесь, что диск остается примонтированным (если не так смотрим в сторону fstab)
```
shutdown -r now
mount |grep vdb|wc -l
```
```console
1
```

- [x] сделайте пользователя postgres владельцем /mnt/data - chown -R postgres:postgres /mnt/data/
```sh
sudo chown postgres /opt/pgdata/.
```
- [x] перенесите содержимое /var/lib/postgres/15 в /mnt/data - mv /var/lib/postgresql/15/mnt/data
```sh
sudo mv /var/lib/postgresql/15/main/ /opt/pgdata/
```
- [x] попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
```
sudo -u postgres pg_ctlcluster 15 main start
```
```console
Error: /var/lib/postgresql/15/main is not accessible or does not exist
```
> ## напишите получилось или нет и почему ##
### Потому что нет файлов базы данных - согласно конфигу ###

- [x]   - задание: найти конфигурационный параметр в файлах раположенных в /etc/postgresql/15/main который надо поменять и поменяйте его
```sh
grep -e '/var/lib/postgresql/15/main' /etc/postgresql/15/main/postgresql.conf; sudo sed -i 's/var\/lib\/postgresql\/15\/main/opt\/pgdata\/main/g' /etc/postgresql/15/main/postgresql.conf ; grep -e /opt/pgdata/main /etc/postgresql/15/main/postgresql.conf
```
```console
data_directory = '/opt/pgdata/main'             # use data in another directory
hba_file = '/opt/pgdata/main/pg_hba.conf'       # host-based authentication file
ident_file = '/opt/pgdata/main/pg_ident.conf'   # ident configuration file
```
> ## напишите что и почему поменяли ##
### Изменил путь к файлам баз данных на новом диске ###

- [x] попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
```sh
sudo -u postgres pg_ctlcluster 15 main startf
```
```console
Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@15-main
```
>  ##  напишите получилось или нет и почему ##
### Получилось ###

- [x] зайдите через через psql и проверьте содержимое ранее созданной таблицы
```sql
sudo -u postgres psql testdb -c "\dt+"
```
```console
                                    List of relations
 Schema |  Name   | Type  |  Owner   | Persistence | Access method | Size  | Description
--------+---------+-------+----------+-------------+---------------+-------+-------------
 public | test    | table | postgres | permanent   | heap          | 16 kB |
 public | testtab | table | postgres | permanent   | heap          | 16 kB |
(2 rows)
```

> ## задание со звездочкой * ##
> не удаляя существующий инстанс ВМ сделайте новый, поставьте на его PostgreSQL, удалите файлы с данными из /var/lib/postgres, перемонтируйте внешний диск который сделали ранее от первой виртуальной машины ко второй и запустите PostgreSQL на второй машине так чтобы он работал с данными на внешнем диске, расскажите как вы это сделали и что в итоге получилось.

### на первом инстансе нужно остановить базу и отключить дис ###
```sh
sudo systemctl stop postgresql@15-main; sudo umount /opt/pgdata
```

### идем в консоль с yc ###
```sh
yc compute instance detach-disk --disk-name test-vol1 --name test-ubuntu-22 # отключаем диск от ВМ1

yc compute instance create --name test-ubuntu-22x --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,size=10G,auto-delete,image-folder
-id=standard-images,image-family=ubuntu-2204-lts --memory 2G --cores 2 --hostname upgtest2 --metadata serial-port-enable=1 --zone ru-central1-b
yc compute instance add-one-to-one-nat test-
ubuntu-22x --network-interface-index 0
yc compute instance attach-disk --disk-name test-vol1 --name test-ubuntu-22x
yc compute connect-to-serial-port --instance-name test-ubuntu-22x --ssh-key .ssh/yc_serialssh_key --user uuu
```
### в консоли второй ВМ ###
```sh
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" |sudo tee /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-15
systemctl status postgresql@15-main
sudo systemctl stop postgresql@15-main
sudo rm -fr /var/lib/postgresql/
sudo mkdir /opt/pgdata
echo 'LABEL=testvol1 /opt/pgdata ext4 defaults 0 0' |sudo tee -a /etc/fstab
sudo mount -a
mount|grep vdb
sudo sed -i 's/var\/lib\/postgresql\/15\/main/opt\/pgdata\/main/g' /etc/postgresql/15/main/postgresql.conf
sudo systemctl start postgresql@15-main
sudo -u postgres psql testdb -c "\l+"|cat
```

```console
                                                                                   List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    | ICU Locale | Locale Provider |   Access privileges   |  Size   | Tablespace |                Description
-----------+----------+----------+-------------+-------------+------------+-----------------+-----------------------+---------+------------+--------------------------------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            |                       | 7297 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            | =c/postgres          +| 7297 kB | pg_default | unmodifiable empty database
           |          |          |             |             |            |                 | postgres=CTc/postgres |         |            |
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            | =c/postgres          +| 7525 kB | pg_default | default template for new databases
           |          |          |             |             |            |                 | postgres=CTc/postgres |         |            |
 testdb    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            |                       | 7565 kB | pg_default |
(4 rows)
```

### END ###
```sh
yc compute instance delete test-ubuntu-22 ; yc compute instance delete test-ubuntu-22x ; yc compute disk delete test-vol1

```
