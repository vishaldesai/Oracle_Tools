--
-- Perfsheet4_query_AWR_cache_transfer.sql -> Extracts data from dba_hist_inst_cache_transfer_immediate. This provides information on avg cr and current block transfer time. 
-- The query computes delta values between snapshots and rates (i.e. delta values divided over delta time).
-- output is in csv format
-- Luca Canali, Oct 2012
--

-- Usage:
--   Run the script from sql*plus connected as a priviledged user (need to be able to read AWR tables)
--   Can run it over sql*net from client machine or locally on db server
--   Customize the file perfsheet4_definitions.sql before running this, in particular define there the interval of analysis

@@Perfsheet4_definitions.sql


set termout on
prompt 
prompt Dumping AWR data to file Perfsheet4_AWR_cache_transfer_immediate_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_cache_transfer_immediate_&myfilesuffix..csv

select cast(min(sn.begin_interval_time) over (partition by sn.dbid,sn.snap_id) as date) snap_time,  --workaround to uniform snap_time over all instances in RAC
	--ss.dbid,  --uncomment if you have multiple dbid in your AWR
	sn.instance_number,
	ss.instance || '->' || sn.instance_number   transfer,
	ss.class,
	(ss.lost - lag(ss.lost) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first)) BLOCKS_LOST,
	(ss.lost_time - lag(ss.lost_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	decode((ss.lost - lag(ss.lost) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first)),0,NULL,(ss.lost - lag(ss.lost) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first)))/1000 BLOCKS_LOST_TIME,
	(ss.cr_block - lag(ss.cr_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first)) CR_BLOCK_REC_IMMED,
	round((ss.cr_2hop - lag(ss.cr_2hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))*100/
	nullif(ss.cr_block - lag(ss.cr_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0),2) CR_2HOP_PCT,
	round((ss.cr_3hop - lag(ss.cr_3hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))*100/
	nullif(ss.cr_block - lag(ss.cr_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0),2) CR_3HOP_PCT,
	(ss.current_block - lag(ss.current_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first)) CU_BLOCK_REC_IMMED,
	round((ss.current_2hop - lag(ss.current_2hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))*100/
	nullif(ss.current_block - lag(ss.current_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0),2) CU_2HOP_PCT,
	round((ss.current_3hop - lag(ss.current_3hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))*100/
	nullif(ss.current_block - lag(ss.current_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0),2) CU_3HOP_PCT,
	--Time
	round((ss.cr_block_time - lag(ss.cr_block_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.cr_block - lag(ss.cr_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CR_MS,
	round((ss.cr_2hop_time - lag(ss.cr_2hop_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.cr_2hop - lag(ss.cr_2hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CR_2HOP_MS,
	round((ss.cr_3hop_time - lag(ss.cr_3hop_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.cr_3hop - lag(ss.cr_3hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CR_3HOP_MS,
	round((ss.current_block_time - lag(ss.current_block_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.current_block - lag(ss.current_block) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CU_MS,
	round((ss.current_2hop_time - lag(ss.current_2hop_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.current_2hop - lag(ss.current_2hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CU_2HOP_MS,
	round((ss.current_3hop_time - lag(ss.current_3hop_time) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first))/
	nullif(ss.current_3hop - lag(ss.current_3hop) over (partition by ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls first),0)/1000,2) AVG_CU_3HOP_MS
from dba_hist_inst_cache_transfer ss,
     dba_hist_snapshot sn
where
    sn.snap_id = ss.snap_id
and sn.dbid = ss.dbid
and sn.instance_number = ss.instance_number
and sn.begin_interval_time &delta_time_where_clause
and cr_block > 0
and current_block > 0
order by sn.snap_id;

spool off

