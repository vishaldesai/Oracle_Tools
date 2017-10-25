--
-- Perfsheet4's query to extract data in html format
-- Perfsheet4_query_AWR_sysmetric.sql -> Extracts data from dba_hist_sysmetric_summary 
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
prompt Dumping AWR data to file Perfsheet4_AWR_sysmetric_&myfilesuffix..csv, please wait
prompt 
set termout off

col METRIC_NAME_UNIT for a75
-- reduce white space waste by sql*plus, the calculated max length for this on 11.2.0.3 is 73

spool Perfsheet4_AWR_sysmetric_&myfilesuffix..csv

select distinct to_char(first.snap_time,'MM/DD HH24:MI') || '-' || to_char(second.snap_time,'MM/DD HH24:MI') RN,
	   first.instance_number,
	   first.metric_name_unit,
	   round(first.maxval,2)				first_maxval,
	   round(first.average,2) 				first_average,
	   round(first.standard_deviation,2) 	first_stddev,
	   round(second.maxval,2)				second_maxval,
	   round(second.average,2)				second_average,
	   round(second.standard_deviation,2) 	second_stddev
from (select   rownum rn,cast(min(sn.begin_interval_time) over (partition by sn.dbid,sn.snap_id) as date) snap_time,
 sn.instance_number,
 ss.metric_name||' - '||ss.metric_unit metric_name_unit,
 ss.maxval,
 ss.average,
 ss.standard_deviation
from dba_hist_sysmetric_summary ss,
     dba_hist_snapshot sn
where
  sn.snap_id = ss.snap_id
 and sn.dbid = ss.dbid
 and sn.instance_number = ss.instance_number
 and sn.snap_id &first_delta_snap_where_clause
order by sn.snap_id,sn.instance_number) first,
	 (select  rownum rn, cast(min(sn.begin_interval_time) over (partition by sn.dbid,sn.snap_id) as date) snap_time,
 sn.instance_number,
 ss.metric_name||' - '||ss.metric_unit metric_name_unit,
 ss.maxval,
 ss.average,
 ss.standard_deviation
from dba_hist_sysmetric_summary ss,
     dba_hist_snapshot sn
where
  sn.snap_id = ss.snap_id
 and sn.dbid = ss.dbid
 and sn.instance_number = ss.instance_number
 and sn.snap_id &second_delta_snap_where_clause
order by sn.snap_id,sn.instance_number) second
where first.instance_number = second.instance_number
and   first.metric_name_unit = second.metric_name_unit
and   first.rn = second.rn
and   first.metric_name_unit = 'Response Time Per Txn - CentiSeconds Per Txn'
order by 1,2;

spool off
