drop table t1 purge;
create table t1 (
    id number
  , num_small number (5, 0)
  , num_big number
  , vc2_short varchar2(200 byte)
  , vc2_long varchar2(4000 byte)
  , dt date
  , cl clob
)
  tablespace users
  lob (cl) store as securefile t1_cl_seg (
    tablespace users
    disable storage in row
    retention auto
    nocache logging
    chunk 32K)
;
  
  
alter table sh.t1
add constraint t1_pk 
primary key (id);

insert /*+ append */ into t1 (id, num_small, num_big, vc2_short, vc2_long, dt)
with datagen as (
  select --+ materialize
      rownum as id
  from
      dual
  connect by level <= 250000
)
select
    rownum as id
  , trunc(dbms_random.value(1, 100)) as num_small
  , round(dbms_random.value(10000, 1000000), 4) as num_big
  , dbms_random.string('L', trunc(dbms_random.value(10, 200))) as vc2_short
  , dbms_random.string('A', trunc(dbms_random.value(200, 4000))) as vc2_long
  , trunc(sysdate + dbms_random.value(0, 366)) as dt
from
    datagen dg1
;
  
commit;
  

set serveroutput on
<<populate_lob>>
declare
  num_rows number :=1;
  cl clob;
  chunk_size integer := 1024; -- 1 KB
  --max_cl_size integer := 16384; -- 32 KB
  max_cl_size integer := 1048576; -- 32 KB
begin


  for row_num in 1 .. num_rows loop
    dbms_lob.createtemporary(cl, false, dbms_lob.call);
  
    for idx in 1 .. trunc(dbms_random.value(1, (max_cl_size / chunk_size))) loop
      dbms_lob.writeappend(cl, chunk_size, dbms_random.string('A', chunk_size));
      null;
    end loop;
  
    dbms_output.put_line(length(populate_lob.cl));
  
    dbms_lob.freetemporary(cl);
  end loop;
end populate_lob;
/