--
-- Perfsheet4_query_AWR_ping_statistics.sql -> Extracts data from dba_hist_interconnect_pings. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_ping_statistics_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_ping_statistics_&myfilesuffix..csv

select cast(min(sn.begin_interval_time) over (partition by sn.dbid,sn.snap_id) as date) snap_time,  --workaround to uniform snap_time over all instances in RAC
	--ss.dbid,  --uncomment if you have multiple dbid in your AWR
	ss.instance_number,
	ss.instance_number || '->' || ss.target_instance SRC_TGT,
	(ss.cnt_500b - lag(ss.cnt_500b) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) PING_COUNT_500B,
	(ss.wait_500b - lag(ss.wait_500b) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) TIME_S_500B,
	case when (ss.cnt_500b - lag(ss.cnt_500b) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) = 0 then
		null
	else
		(ss.wait_500b - lag(ss.wait_500b) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first))/
		(ss.cnt_500b - lag(ss.cnt_500b) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first))/1000 
	end AVG_TIME_MS_500B,
	(ss.cnt_8k - lag(ss.cnt_8k) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) PING_COUNT_8K,
	(ss.wait_8k - lag(ss.wait_8k) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) TIME_S_8K,
	case when (ss.cnt_8k - lag(ss.cnt_8k) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first)) = 0 then
		null
	else
	(ss.wait_8k - lag(ss.wait_8k) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first))/
	(ss.cnt_8k - lag(ss.cnt_8k) over (partition by ss.dbid,ss.instance_number,ss.target_instance order by sn.snap_id nulls first))/1000 
	end AVG_TIME_MS_8K
from dba_hist_interconnect_pings ss,
     dba_hist_snapshot sn
where
    sn.snap_id = ss.snap_id
and sn.dbid = ss.dbid
and sn.instance_number = ss.instance_number
and sn.begin_interval_time &delta_time_where_clause
order by sn.snap_id;

spool off

