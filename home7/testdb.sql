create schema testnm;
create table testnm.t1 as
  SELECT (x * (1000 + 500*random())*log(row_number() over()))::varchar(1000) as c1
  FROM generate_series( 1, 1000000, 1) x ;
