# Домашнее задание: Секционирование таблицы #

# DO: Секционировать большую таблицу из демо базы flights #

## запускаем машину p1 из [home_16.md](home_16.md), получаем переменные, разрешаем доступ ##
```sh
mip=`curl -s https://ipinfo.io/json|jq .ip|sed 's/"//g'`
yc compute instance start p1
hostip=`yc compute instance show p1 --format json |  jq '.network_interfaces[0].primary_v4_address.one_to_one_nat.address'|sed 's/"//g'`
ssh -o "VerifyHostKeyDNS no" -i .ssh/yc_serialssh_key uuu@$hostip "sudo -u postgres psql -c \"alter database demo set search_path=bookings, public, postgres\" ; sudo firewall-cmd --zone=work --add-source=$mip --permanent ; echo -e \"\\nhost    all     all             $mip/32                 scram-sha-256\\n\" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf ; sudo systemctl restart postgresql@15-main "
```
## выбираем цель
```sql
select 
schemaname,
relname,
pg_size_pretty(pg_table_size(relname::varchar(1000)))as table_size,
pg_size_pretty(pg_total_relation_size(relname::varchar(1000)))as total_size
from pg_catalog.pg_stat_user_tables  where schemaname ='bookings' order by pg_table_size(relname::varchar(1000)) desc
```
|schemaname|relname|table_size|total_size|
|--|---|--|-------|
|bookings|ticket_flights|547 MB|1125 MB|
|bookings|boarding_passes|455 MB|1102 MB|
|bookings|tickets|386 MB|475 MB|
|bookings|bookings|105 MB|150 MB|
|bookings|flights|21 MB|33 MB|
|bookings|routes|152 kB|152 kB|
|bookings|seats|96 kB|144 kB|
|bookings|airports|48 kB|64 kB|
|bookings|aircrafts|16 kB|32 kB|

## изучаем ##
```sql
select * from pg_stats where tablename='ticket_flights'
```
|schemaname|tablename|attname|inherited|null_frac|avg_width|n_distinct|most_common_vals|most_common_freqs|histogram_bounds|correlation|most_common_elems|most_common_elem_freqs|elem_count_histogram|
|----------|---------|-------|---------|---------|---------|----------|----------------|-----------------|----------------|-----------|-----------------|----------------------|--------------------|
|bookings|ticket_flights|fare_conditions|false|0.0|8|3.0|{Economy,Business,Comfort}|{0,8829666376,0,1001000032,0,0169333331}||0.8780906||||
|bookings|ticket_flights|ticket_no|false|0.0|14|-0.29970634|||{0005432000983,0005432105706,0005432190152,0005432291759,0005432328135,0005432370016,0005432391624,0005432421604,0005432453362,0005432504103,0005432548624,0005432595849,0005432624886,0005432660182,0005432688117,0005432724495,0005432769350,0005432794024,0005432829051,0005432880896,0005432918345,0005432949037,0005432999396,0005433051809,0005433107274,0005433131414,0005433176249,0005433213723,0005433249791,0005433285702,0005433321199,0005433341613,0005433373552,0005433398825,0005433438295,0005433477018,0005433523929,0005433558658,0005433593469,0005433612578,0005433642257,0005433689775,0005433740642,0005433778959,0005433809407,0005433859776,0005433904329,0005433945581,0005433971261,0005434007573,0005434049600,0005434073228,0005434116177,0005434139258,0005434182177,0005434213374,0005434242582,0005434275410,0005434332875,0005434370814,0005434404354,0005434438528,0005434466427,0005434506563,0005434544090,0005434577699,0005434625471,0005434684562,0005434725954,0005434758449,0005434816545,0005434859494,0005434888997,0005434916831,0005434959560,0005434992161,0005435036884,0005435068187,0005435103864,0005435124846,0005435157978,0005435213471,0005435246861,0005435292494,0005435337250,0005435400177,0005435443271,0005435489740,0005435517977,0005435548394,0005435601510,0005435640437,0005435677044,0005435713952,0005435753251,0005435785890,0005435837239,0005435885406,0005435924473,0005435972652,0005435999803}|0.08494676||||
|bookings|ticket_flights|flight_id|false|0.0|4|81426.0|{63860,63955}|{0,0002,0,0002}|{2,1614,1862,2270,2993,6762,8164,9409,10360,12034,13899,15001,15553,18498,20941,22036,22726,25023,27894,30598,32381,33695,34221,34495,34721,35531,36122,38825,41084,42246,44456,46223,47987,49963,50289,51370,53125,54378,55827,60169,60768,62718,63959,64249,65477,69368,70706,71069,72567,75093,77004,78679,81973,83081,84360,87456,89854,94369,94788,96516,99318,100402,105692,110659,112109,116875,120492,125551,130413,131614,135216,136313,138696,141316,146261,149568,153655,157204,159548,162594,163961,166471,168213,169935,170661,173208,174955,177298,180012,185543,186605,189045,191254,195056,197809,198418,198676,199966,203193,208125,214833}|0.21292554||||
|bookings|ticket_flights|amount|false|0.0|6|323.0|{6300.00,14400.00,14000.00,6000.00,27900.00,6700.00,28000.00,11700.00,12200.00,7200.00,3300.00,61500.00,4000.00,6200.00,11000.00,9800.00,14800.00,11600.00,10900.00,7900.00,11800.00,12100.00,13600.00,10200.00,3200.00,44300.00,13400.00,13000.00,19100.00,8200.00,3700.00,16400.00,35300.00,62100.00,3400.00,16600.00,17600.00,17000.00,7700.00,3000.00,12700.00,13700.00,5400.00,6900.00,10700.00,28700.00,33300.00,6600.00,9300.00,16200.00,16700.00,9000.00,20400.00,3100.00,18000.00,4200.00,7100.00,23500.00,8900.00,3600.00,15000.00,41500.00,3800.00,24400.00,9200.00,16100.00,17400.00,38300.00,22400.00,23100.00,15700.00,16800.00,47400.00,8800.00,15400.00,23200.00,66400.00,4400.00,9500.00,18800.00,9900.00,19000.00,10100.00,29900.00,8100.00,29000.00,23900.00,15100.00,21500.00,5200.00,22600.00,66600.00,19900.00,7600.00,47600.00,20000.00,42100.00,64400.00,83700.00,67800.00}|{0,0312666669,0,0285333339,0,026866667,0,0258333329,0,0249666665,0,023,0,0198666658,0,0188666675,0,0180333331,0,0175000001,0,0159666669,0,0156666674,0,0151333334,0,0138333337,0,0135333333,0,0132999998,0,0124666663,0,0123666665,0,0121333329,0,0120000001,0,0119333332,0,0118666664,0,0115999999,0,0113666663,0,0110999998,0,0108666662,0,0108333332,0,0107333334,0,0106333336,0,0100999996,0,0098000001,0,0094999997,0,0094333338,0,0084333336,0,0081666671,0,0078333337,0,0077666668,0,0076666665,0,0073000002,0,0072666667,0,0068666665,0,0067333332,0,0065666665,0,0065666665,0,0065666665,0,0065333336,0,0065333336,0,0065000001,0,0065000001,0,0062333331,0,0062333331,0,0060333335,0,0060333335,0,0057999999,0,0057999999,0,0056333332,0,0055666668,0,0054666665,0,0054000001,0,0052,0,0050333333,0,0050333333,0,0048000002,0,0047333334,0,0043000001,0,0043000001,0,0043000001,0,0042666667,0,0041333335,0,0040333332,0,0040000002,0,0040000002,0,0039666668,0,0039333333,0,0039333333,0,0038000001,0,0038000001,0,0036333334,0,0036333334,0,0035333333,0,0035000001,0,0035000001,0,0034666667,0,0034,0,0033333334,0,0033333334,0,0033,0,0030666667,0,0030666667,0,003,0,003,0,0028333333,0,0027333333,0,0026666666,0,0026666666,0,0026333334,0,0025666666,0,0025333334,0,0025333334,0,0024666667}|{3500.00,3900.00,4100.00,4900.00,5300.00,5800.00,6800.00,7000.00,7300.00,7400.00,7500.00,7800.00,8700.00,9700.00,10300.00,10500.00,11100.00,11300.00,11900.00,12300.00,12400.00,12500.00,12900.00,13900.00,13900.00,14300.00,14700.00,14900.00,15500.00,15600.00,16300.00,17200.00,17900.00,18100.00,18200.00,18500.00,18700.00,18900.00,19300.00,19700.00,20200.00,20300.00,20900.00,21400.00,21700.00,22800.00,23600.00,23800.00,24500.00,24700.00,24900.00,25700.00,25700.00,26400.00,26900.00,27800.00,28400.00,28900.00,29100.00,29200.00,29400.00,30200.00,30600.00,30700.00,32000.00,32800.00,33000.00,33700.00,34700.00,35000.00,35600.00,36400.00,36600.00,37200.00,38900.00,40900.00,40900.00,43100.00,43300.00,44500.00,48400.00,48700.00,49700.00,50000.00,51100.00,57200.00,61300.00,67700.00,70400.00,84000.00,86000.00,88300.00,99800.00,105900.00,115000.00,132900.00,145300.00,184500.00,186200.00,199300.00,203300.00}|-0.2586179||||

```sql
alter table ticket_flights rename to ticket_flights0;
create table ticket_flights ( like ticket_flights0 including all ) partition by hash(ticket_no);
```
```sql
do $$
begin for i in 0 .. 15
	loop
		execute format('create table ticket_flights_hash_%s partition of ticket_flights for values with (modulus 16, remainder %s);', i, i);
	end loop;
end;
$$ language plpgsql;
```
```sql
insert into ticket_flights
select * from ticket_flights0;
truncate table ticket_flights0;

select schemaname, relname,
pg_size_pretty(pg_table_size(relname::varchar(1000)))as table_size,
pg_size_pretty(pg_total_relation_size(relname::varchar(1000)))as total_size
from pg_catalog.pg_stat_user_tables  where relname like 'ticket_flights%' 
```

```sql
select * from pg_catalog.pg_stat_user_tables where relname = 'boarding_passes' or relname like 'ticket_flights%';
```
|relid|schemaname|relname|seq_scan|seq_tup_read|idx_scan|idx_tup_fetch|n_tup_ins|n_tup_upd|n_tup_del|n_tup_hot_upd|n_live_tup|n_dead_tup|n_mod_since_analyze|n_ins_since_vacuum|last_vacuum|last_autovacuum|last_analyze|last_autoanalyze|vacuum_count|autovacuum_count|analyze_count|autoanalyze_count|
|-----|----------|-------|--------|------------|--------|-------------|---------|---------|---------|-------------|----------|----------|-------------------|------------------|-----------|---------------|------------|----------------|------------|----------------|-------------|-----------------|
|16403|bookings|boarding_passes|35|198443936|69708|1|7925812|0|0|0|7925688|0|0|0||2023-12-15 02:46:41.917 +0300||2023-12-15 02:47:52.234 +0300|0|1|0|1|
|16432|bookings|ticket_flights0|157|728235294|83590|29881499|8391852|5229769|859656|0|6794630|0|0|0||2023-12-15 04:27:54.784 +0300|2023-12-15 03:32:23.487 +0300|2023-12-15 02:44:41.899 +0300|0|2|1|1|
|17094|bookings|ticket_flights|0|0|0|0|0|0|0|0|0|0|0|0|||||0|0|0|0|
|17102|bookings|ticket_flights_hash_0|3|0|0|0|525699|0|0|0|525699|0|0|0||2023-12-20 01:32:51.690 +0300||2023-12-20 01:32:52.113 +0300|0|1|0|1|
|17110|bookings|ticket_flights_hash_1|2|0|0|0|522631|0|0|0|522631|0|0|0||2023-12-20 01:32:53.272 +0300||2023-12-20 01:32:53.605 +0300|0|1|0|1|
|17118|bookings|ticket_flights_hash_2|2|0|0|0|524148|0|0|0|524148|0|0|0||2023-12-20 01:32:54.766 +0300||2023-12-20 01:32:55.102 +0300|0|1|0|1|
|17126|bookings|ticket_flights_hash_3|2|0|0|0|524860|0|0|0|524860|0|0|0||2023-12-20 01:32:56.266 +0300||2023-12-20 01:32:56.592 +0300|0|1|0|1|
|17134|bookings|ticket_flights_hash_4|2|0|0|0|523019|0|0|0|523018|1|0|0||2023-12-20 01:32:57.761 +0300||2023-12-20 01:32:58.083 +0300|0|1|0|1|
|17142|bookings|ticket_flights_hash_5|2|0|0|0|523241|0|0|0|523241|0|0|0||2023-12-20 01:32:59.245 +0300||2023-12-20 01:32:59.587 +0300|0|1|0|1|
|17150|bookings|ticket_flights_hash_6|2|0|0|0|526672|0|0|0|526672|0|0|0||2023-12-20 01:33:00.797 +0300||2023-12-20 01:33:01.186 +0300|0|1|0|1|
|17158|bookings|ticket_flights_hash_7|2|0|0|0|525876|0|0|0|525876|0|0|0||2023-12-20 01:33:02.394 +0300||2023-12-20 01:33:02.785 +0300|0|1|0|1|
|17166|bookings|ticket_flights_hash_8|2|0|0|0|522466|0|0|0|522466|0|0|0||2023-12-20 01:33:03.967 +0300||2023-12-20 01:33:04.342 +0300|0|1|0|1|
|17174|bookings|ticket_flights_hash_9|2|0|0|0|524471|0|0|0|524471|0|0|0||2023-12-20 01:33:05.526 +0300||2023-12-20 01:33:05.905 +0300|0|1|0|1|
|17182|bookings|ticket_flights_hash_10|2|0|0|0|523748|0|0|0|523748|0|0|0||2023-12-20 01:33:07.076 +0300||2023-12-20 01:33:07.449 +0300|0|1|0|1|
|17190|bookings|ticket_flights_hash_11|2|0|0|0|523678|0|0|0|523678|0|0|0||2023-12-20 01:33:08.631 +0300||2023-12-20 01:33:08.983 +0300|0|1|0|1|
|17198|bookings|ticket_flights_hash_12|2|0|0|0|525415|0|0|0|525415|0|0|0||2023-12-20 01:33:10.168 +0300||2023-12-20 01:33:10.545 +0300|0|1|0|1|
|17206|bookings|ticket_flights_hash_13|2|0|0|0|525267|0|0|0|525267|0|0|0||2023-12-20 01:33:11.748 +0300||2023-12-20 01:33:12.141 +0300|0|1|0|1|
|17214|bookings|ticket_flights_hash_14|2|0|0|0|524931|0|0|0|524931|0|0|0||2023-12-20 01:33:14.127 +0300||2023-12-20 01:33:14.493 +0300|0|1|0|1|
|17222|bookings|ticket_flights_hash_15|2|0|0|0|525731|0|0|0|525731|0|0|0||2023-12-20 01:33:15.747 +0300||2023-12-20 01:33:16.175 +0300|0|1|0|1|


```sql
update pg_constraint set confrelid=17094 where confrelid=16432;
truncate table ticket_flights0;
select * from pg_constraint where confrelid=17094;
```

|oid|conname|connamespace|contype|condeferrable|condeferred|convalidated|conrelid|contypid|conindid|conparentid|confrelid|confupdtype|confdeltype|confmatchtype|conislocal|coninhcount|connoinherit|conkey|confkey|conpfeqop|conppeqop|conffeqop|confdelsetcols|conexclop|conbin|
|---|-------|------------|-------|-------------|-----------|------------|--------|--------|--------|-----------|---------|-----------|-----------|-------------|----------|-----------|------------|------|-------|---------|---------|---------|--------------|---------|------|
|16467|boarding_passes_ticket_no_fkey|16390|f|false|false|true|16403|0|16463|0|17094|a|a|s|true|0|true|{1,2}|{1,2}|{1 054,96}|{1 054,96}|{1 054,96}||||

## итог - разделили ticket_flights на партиции через создание промежуточной таблицы с парцициями и перепривязку ограничений ##



# Попробуем по RANGE другую и не по уникальному полю: #
```
select min(boarding_no),avg(boarding_no)::int4,max(boarding_no) from boarding_passes
```
|min|avg|max|
|---|---|---|
|1|59|381|

```sql
alter table boarding_passes rename to boarding_passes0;
create index boarding_passes_x1 on boarding_passes0 using btree(boarding_no);
create table boarding_passes ( like boarding_passes0  ) partition by RANGE(boarding_no);
--select relid,schemaname,relname from pg_catalog.pg_stat_user_tables where relname in ('boarding_passes0','boarding_passes') -- пригодится когда дропнем boarding_passes0 и есть constraints
--update pg_constraint set confrelid=17254 where confrelid=16403; -- нет constraint
```
|relid|schemaname|relname|
|-----|----------|-------|
|16403|bookings|boarding_passes0|
|17254|bookings|boarding_passes|


смотрим ddl
```sql
CREATE TABLE bookings.boarding_passes ( ticket_no bpchar(13) NOT NULL, flight_id int4 NOT NULL, boarding_no int4 NOT NULL, seat_no varchar(4) NOT NULL ) PARTITION BY RANGE (boarding_no);

CREATE TABLE bookings.boarding_passes0 (	ticket_no bpchar(13) NOT NULL, flight_id int4 NOT NULL, boarding_no int4 NOT NULL, seat_no varchar(4) NOT NULL,
CONSTRAINT boarding_passes_flight_id_boarding_no_key UNIQUE (flight_id, boarding_no),
CONSTRAINT boarding_passes_flight_id_seat_no_key UNIQUE (flight_id, seat_no),
CONSTRAINT boarding_passes_pkey PRIMARY KEY (ticket_no, flight_id),
CONSTRAINT boarding_passes_ticket_no_fkey FOREIGN KEY (ticket_no,flight_id) REFERENCES bookings.ticket_flights(ticket_no,flight_id));
```

```sql
CREATE TABLE boarding_passes_100 PARTITION OF boarding_passes FOR VALUES from (1) to (100); -- так как среднее 59 - стоило делить скорее первый отрезок на 3 части похоже... но задачи делить равномерно нет...
CREATE TABLE boarding_passes_200 PARTITION OF boarding_passes FOR VALUES from (100) to (200);
CREATE TABLE boarding_passes_300 PARTITION OF boarding_passes FOR VALUES from (200) to (300);
CREATE TABLE boarding_passes_400 PARTITION OF boarding_passes default;


with q as (delete from boarding_passes0 where boarding_no<10 and boarding_no>=0  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<20 and boarding_no>=10  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<30 and boarding_no>=20  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<50 and boarding_no>=30  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<70 and boarding_no>=50  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<100 and boarding_no>=70  returning * ) insert into boarding_passes select * from q ;
with q as (delete from boarding_passes0 where boarding_no<500 and boarding_no>=100  returning * ) insert into boarding_passes select * from q ;
--insert into boarding_passes select * from boarding_passes0;

alter table boarding_passes add CONSTRAINT boarding2_passes_flight_id_boarding_no_key UNIQUE (flight_id, boarding_no);
alter table  boarding_passes add CONSTRAINT boarding2_passes_flight_id_seat_no_key UNIQUE (flight_id, seat_no,boarding_no);
alter table  boarding_passes add CONSTRAINT boarding2_passes_pkey PRIMARY KEY (ticket_no, flight_id,boarding_no);
alter table  boarding_passes add CONSTRAINT boarding2_passes_ticket_no_fkey FOREIGN KEY (ticket_no,flight_id) REFERENCES bookings.ticket_flights(ticket_no,flight_id) ;




drop table boarding_passes0 ;


```

|tab|zt|z_total|
|---|--|-------|
|boarding_passes|0 bytes|0 bytes|
|boarding_passes_100|379 MB|1268 MB|
|boarding_passes_200|54 MB|182 MB|
|boarding_passes_300|19 MB|63 MB|
|boarding_passes_400|3920 kB|14 MB|
|-|456 MB|1526 MB|
|boarding_passes0|455 MB|1154 MB|
-- неээфективно...
