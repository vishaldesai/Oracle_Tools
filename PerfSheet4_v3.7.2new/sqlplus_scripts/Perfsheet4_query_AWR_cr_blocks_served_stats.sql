--
-- Perfsheet4_query_AWR_cr_blocks_served_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_cr_blocks_served_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_cr_blocks_served_stats_&myfilesuffix..csv

SELECT * from (	
SELECT
        CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) snap_time
       , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
         --uncomment if you have multipledbid in your AWR
        sn.instance_number
      , ss.cr_requests - lag(ss.cr_requests) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			"Blocks Req CR"
      , ss.current_requests - lag(ss.current_requests) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  "Blocks Req CU"
      , ss.data_requests - lag(ss.data_requests) over (partition BY ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)        "Blocks Req Data"
      , ss.undo_requests - lag(ss.undo_requests) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)       "Blocks Req Undo"
      , ss.tx_requests - lag(ss.tx_requests) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		    "Blocks Req TX"
      , ss.current_results - lag(ss.current_results) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)   "Results Current"
      , ss.private_results - lag(ss.private_results) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)   "Results Private"  
      , ss.zero_results - lag(ss.zero_results) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)         "Results Zero"
      , ss.disk_read_results - lag(ss.disk_read_results) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) "Results Dsk Rd"		   
      , ss.fail_results - lag(ss.fail_results) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		"Results Fail" 
      , ss.fairness_down_converts - lag(ss.fairness_down_converts) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) "Fairness Down Conv"
      , ss.fairness_clears - lag(ss.fairness_clears) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 	"Fairness Clears"
     , ss.free_gc_elements - lag(ss.free_gc_elements) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 	"FreeGC Elems"
	 , ss.flushes - lag(ss.flushes) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 					"Flushes Total"
	 , ss.flushes_queued - lag(ss.flushes_queued) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		"Flushes Queued"
	 , ss.flush_queue_full - lag(ss.flush_queue_full) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 	"Flushes QFull"
	 , ss.flush_max_time - lag(ss.flush_max_time) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		"Flushes MaxTm"
	 , ss.light_works - lag(ss.light_works) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 			"Light Works"
	 , ss.errors - lag(ss.errors) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 						"Total Errors"
FROM
    dba_hist_snapshot sn
  , dba_hist_cr_block_server  ss
WHERE
    sn.snap_id         = ss.snap_id
AND sn.dbid            = ss.dbid
AND sn.instance_number = ss.instance_number
AND sn.begin_interval_time
    &delta_time_where_clause )
WHERE "Blocks Req CR" is not null
ORDER BY
    snap_time,instance_number;

spool off

