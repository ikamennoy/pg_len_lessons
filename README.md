# Тема: Миграция сервера PostgreSQL в кластер с минимизацией времени простоя #

Цели проекта
- Резервирование данных с помощью репликации
- Автоматическое решение с failover, quorum
- Надежность и высокодоступность как бонус опции

Что планировалось
```
1 Анализ вариантов кластера, выбор оптимального решения – на этом этап ушло больше всего времени
2 Реализация в виде скрипта – для развертывания тестового окружения и выполнения работ на нем
3 Проведение исптытаний
4 По позможности эксперименты, самописные скрипты с возможностью оценки доступности. ApacheSuperset или свое решение
   - https://superset.apache.org/docs/installation/installing-superset-from-scratch
   - https://superset.apache.org/docs/installation/installing-superset-from-scratch  
```

Используемые технологии
```
1. Postgres и физическая репликация + Patroni – мейнстрим
для оранизации высокодоступных кластеров.
2. Consul – функционален, быстр и надежен благодаря
протоколу Gossip фокусируется на обнаружении сервисов
и сегментации сети. Простой и понятный HTTP REST API
(простые данные, не более 20 разных API функций), либо
DNS сервисы с SRV записями, компилируется на Go в 1
бинарник
3. Haproxy – балансировка
4. Keepalived – виртуальный IP для тупых приложений – но
честно говоря достаточно и Haproxy в целом то
```

В результате   1 скрипт: развертывание машин, создание инстанса Postgresql – и на базесуществующего – создание кластераPatroni
    1 мастер, 2 реплики - в случае вывода машины - все равнозначны.

`vb(haproxy,patroni+consul,postgresql) <--> va(haproxy,patroni+consul,postgresql) <--> vd(haproxy,patroni+consul,postgresql) <-->`

Выводы и планы по развитию
```
1.Можно внедрить watchdog,
2. более глубо разобрать consul, postgres, patroni, https://github.com/kelseyhightower/confd/blob/master/docs/quick-start-guide.md or consul-template
  - https://github.com/hashicorp/consul-template/blob/main/examples/haproxy.md
  - https://developer.hashicorp.com/consul/tutorials/load-balancing/load-balancing-haproxy
  - https://www.haproxy.com/blog/consul-service-discovery-for-haproxy
  - https://gist.github.com/yunano/c27eb679a29ab70178ca /etc/systemd/system/consul.service

  - https://github.com/zalando/spilo `Spilo: HA PostgreSQL Clusters with Docker`
  - https://github.com/zalando/patroni
  - https://patroni.readthedocs.io/en/latest/yaml_configuration.html#postgresql-settings
  - https://github.com/zalando/spilo `Spilo: HA PostgreSQL Clusters with Docker`
  - https://patroni.readthedocs.io/en/latest/existing_data.html
  - https://www.dmosk.ru/miniinstruktions.php?mini=patroni-consul-ubuntu
  - https://habr.com/ru/articles/674020/ Алгоритм работы HA кластера PostgreSQL с помощью Patroni
  - https://habr.com/ru/articles/512768/ Patroni Failure Stories or How to crash your PostgreSQL cluster. Алексей Лесовский !!! 
                - https://habr.com/ru/companies/vk/articles/452846/ Блог компании VK - хороший тест на python
                - https://habr.com/ru/articles/530506/ Patroni и stolon инсталляция и отработка падений. Максим Милютин
                - https://pgconf.ru/talk/1588646 Как мы выбирали среди patroni, stolon, repmgr Андрей Фефелов Mastery.pro
  - https://habr.com/ru/articles/754168/ docker.io/bitnami/postgresql-repmgr , prometheuscommunity/postgres-exporter:v0.11.1

  - https://selectel.ru/blog/tutorials/how-to-install-pgbouncer-connection-pooler-for-postgresql/

  - https://interface31.ru/tech_it/2023/02/uluchshaem-proizvoditelnost-linux-pri-pomoshhi-zram.html - попробовать с etcd RAM диск
  - https://habr.com/ru/articles/482314/ etcd example
    

3 .Попробовать pypgsql
4. Добавить мониторинг
5. попробовать тоже самое на K8s ... 
  - https://github.com/citusdata/citus
  - https://github.com/bishoybassem/k8s-ha-postgres/tree/master
  - https://docs.openshift.com/container-platform/3.11/install_config/http_proxies.html https://gist.github.com/leighghunt/843184c8447972638e9ae6e33097e553 
              - dns_nameservers 8.8.8.8 208.67.222.222 - можно попробовать указать DNS сервер!
  - deprecated: https://phoenixnap.com/kb/how-to-install-kubernetes-on-centos
          - можно использовать штатный kubeadm,kubectl в epel
  - https://github.com/patrickdappollonio/intro-to-openshift/blob/master/Installing%20OpenShift%20Origin%20on%20CentOS%207.md
  - https://github.com/hashicorp/consul-k8s/tree/main/charts/consul/test/terraform/openshift
  - https://github.com/kubernetes-sigs/kubespray
  - https://github.com/kubernetes/kops
  - https://github.com/helm/charts/tree/master/incubator/patroni

  - https://github.com/terraform-yc-modules/terraform-yc-postgresql/blob/master/examples/2-multi-node/main.tf
  
  
6. внедрить pgbouncer - несколько потоков 
7. метрики или проверки в consul
```


## CONSUL ##
```
https://habr.com/ru/articles/266139/ -- хвалебная ода про consul + примеры dig,checks,etc
  - https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-deploy
  - https://developer.hashicorp.com/consul/tutorials/production-deploy/backup-and-restore
      - consul snapshot save backup.snap
      - consul snapshot restore backup.snap
  - https://github.com/hashicorp/consul/issues/4306 bind_addr
  - https://developer.hashicorp.com/consul/tutorials/datacenter-operations/add-remove-servers
  - https://github.com/hashicorp/consul-k8s
  - https://developer.hashicorp.com/consul/install
  - https://www.dbi-services.com/blog/how-to-setup-a-consul-cluster-on-rhel-8-rocky-linux-8-almalinux-8/ красивое, безопасное и простое руководство по настройке консула
```

``` try
https://www.zabbix.com/ru/integrations/postgresql
https://gitlab.com/aerian/zabbix/patroni_http/-/blob/main/template_app_patroni_http.json?ref_type=heads

https://www.postgresql.org/docs/current/monitoring-stats.html

pg_stat_activity	One row per server process, showing information related to the current activity of that process, such as state and current query. See pg_stat_activity for details.
pg_stat_replication	One row per WAL sender process, showing statistics about replication to that sender's connected standby server. See pg_stat_replication for details.
pg_stat_wal_receiver	Only one row, showing statistics about the WAL receiver from that receiver's connected server. See pg_stat_wal_receiver for details.
pg_stat_recovery_prefetch	Only one row, showing statistics about blocks prefetched during recovery. See pg_stat_recovery_prefetch for details.
pg_stat_subscription	At least one row per subscription, showing information about the subscription workers. See pg_stat_subscription for details.
pg_stat_ssl	One row per connection (regular and replication), showing information about SSL used on this connection. See pg_stat_ssl for details.
pg_stat_gssapi	One row per connection (regular and replication), showing information about GSSAPI authentication and encryption used on this connection. See pg_stat_gssapi for details.
pg_stat_progress_analyze	One row for each backend (including autovacuum worker processes) running ANALYZE, showing current progress. See Section 28.4.1.
pg_stat_progress_create_index	One row for each backend running CREATE INDEX or REINDEX, showing current progress. See Section 28.4.4.
pg_stat_progress_vacuum	One row for each backend (including autovacuum worker processes) running VACUUM, showing current progress. See Section 28.4.5.
pg_stat_progress_cluster	One row for each backend running CLUSTER or VACUUM FULL, showing current progress. See Section 28.4.2.
pg_stat_progress_basebackup	One row for each WAL sender process streaming a base backup, showing current progress. See Section 28.4.6.
pg_stat_progress_copy	One row for each backend running COPY, showing current progress. See Section 28.4.3.

Collected Statistics Views

View Name	Description
pg_stat_archiver	One row only, showing statistics about the WAL archiver process's activity. See pg_stat_archiver for details.
pg_stat_bgwriter	One row only, showing statistics about the background writer process's activity. See pg_stat_bgwriter for details.
pg_stat_database	One row per database, showing database-wide statistics. See pg_stat_database for details.
pg_stat_database_conflicts	One row per database, showing database-wide statistics about query cancels due to conflict with recovery on standby servers. See pg_stat_database_conflicts for details.
pg_stat_io	One row for each combination of backend type, context, and target object containing cluster-wide I/O statistics. See pg_stat_io for details.
pg_stat_replication_slots	One row per replication slot, showing statistics about the replication slot's usage. See pg_stat_replication_slots for details.
pg_stat_slru	One row per SLRU, showing statistics of operations. See pg_stat_slru for details.
pg_stat_subscription_stats	One row per subscription, showing statistics about errors. See pg_stat_subscription_stats for details.
pg_stat_wal	One row only, showing statistics about WAL activity. See pg_stat_wal for details.
pg_stat_all_tables	One row for each table in the current database, showing statistics about accesses to that specific table. See pg_stat_all_tables for details.
pg_stat_sys_tables	Same as pg_stat_all_tables, except that only system tables are shown.
pg_stat_user_tables	Same as pg_stat_all_tables, except that only user tables are shown.
pg_stat_xact_all_tables	Similar to pg_stat_all_tables, but counts actions taken so far within the current transaction (which are not yet included in pg_stat_all_tables and related views). The columns for numbers of live and dead rows and vacuum and analyze actions are not present in this view.
pg_stat_xact_sys_tables	Same as pg_stat_xact_all_tables, except that only system tables are shown.
pg_stat_xact_user_tables	Same as pg_stat_xact_all_tables, except that only user tables are shown.
pg_stat_all_indexes	One row for each index in the current database, showing statistics about accesses to that specific index. See pg_stat_all_indexes for details.
pg_stat_sys_indexes	Same as pg_stat_all_indexes, except that only indexes on system tables are shown.
pg_stat_user_indexes	Same as pg_stat_all_indexes, except that only indexes on user tables are shown.
pg_stat_user_functions	One row for each tracked function, showing statistics about executions of that function. See pg_stat_user_functions for details.
pg_stat_xact_user_functions	Similar to pg_stat_user_functions, but counts only calls during the current transaction (which are not yet included in pg_stat_user_functions).
pg_statio_all_tables	One row for each table in the current database, showing statistics about I/O on that specific table. See pg_statio_all_tables for details.
pg_statio_sys_tables	Same as pg_statio_all_tables, except that only system tables are shown.
pg_statio_user_tables	Same as pg_statio_all_tables, except that only user tables are shown.
pg_statio_all_indexes	One row for each index in the current database, showing statistics about I/O on that specific index. See pg_statio_all_indexes for details.
pg_statio_sys_indexes	Same as pg_statio_all_indexes, except that only indexes on system tables are shown.
pg_statio_user_indexes	Same as pg_statio_all_indexes, except that only indexes on user tables are shown.
pg_statio_all_sequences	One row for each sequence in the current database, showing statistics about I/O on that specific sequence. See pg_statio_all_sequences for details.
pg_statio_sys_sequences	Same as pg_statio_all_sequences, except that only system sequences are shown. (Presently, no system sequences are defined, so this view is always empty.)
pg_statio_user_sequences	Same as pg_statio_all_sequences, except that only user sequences are shown.

https://hypothesis.readthedocs.io/en/latest/
https://faker.readthedocs.io/en/master/
https://www.kaggle.com/datasets
https://postgrespro.ru/docs/postgresql/13/warm-standby
https://postgrespro.ru/docs/postgresql/13/app-pgbasebackup
https://github.com/egno/flas/blob/master/CHANGELOG.md + https://habr.com/ru/articles/310040/ Вы не любите триггеры?

```
