--
-- Perfsheet4_query_AWR_current_blocks_served_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_current_blocks_served_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_current_blocks_served_stats_&myfilesuffix..csv

SELECT
      snap_time
     ,instance_number
     , pins
     , nvl(pin1    /DECODE(pins,0,NULL,pins)*100,0) "Pins%<1ms"
     , nvl(pin10   /DECODE(pins,0,NULL,pins)*100,0) "Pins%<10ms"
     , nvl(pin100  /DECODE(pins,0,NULL,pins)*100,0) "Pins%<100ms"
     , nvl(pin1000 /DECODE(pins,0,NULL,pins)*100,0) "Pins%<1000ms"
     , nvl(pin10000/DECODE(pins,0,NULL,pins)*100,0) "Pins%<10000ms"
     , flushes
     , nvl(flush1    /DECODE(flushes,0,NULL,flushes)*100,0) "Flushes%<1ms"
     , nvl(flush10   /DECODE(flushes,0,NULL,flushes)*100,0) "Flushes%<10ms"
     , nvl(flush100  /DECODE(flushes,0,NULL,flushes)*100,0) "Flushes%<100ms"
     , nvl(flush1000 /DECODE(flushes,0,NULL,flushes)*100,0) "Flushes%<1000ms"
     , nvl(flush10000/DECODE(flushes,0,NULL,flushes)*100,0) "Flushes%<10000ms"
     , writes
     , nvl(write1    /DECODE(writes,0,NULL,writes)*100,0) "Writes%<1ms"
     , nvl(write10   /DECODE(writes,0,NULL,writes)*100,0) "Writes%<10ms"
     , nvl(write100  /DECODE(writes,0,NULL,writes)*100,0) "Writes%<100ms"
     , nvl(write1000 /DECODE(writes,0,NULL,writes)*100,0) "Writes%<1000ms"
     , nvl(write10000/DECODE(writes,0,NULL,writes)*100,0) "Writes%<10000ms"
	 FROM
       (
              SELECT
                     snap_time
                   ,instance_number
                   ,pin1
                   ,pin10
                   ,pin100
                   ,pin1000
                   ,pin10000
                   ,pin1+pin10+pin100+pin1000+pin10000 pins
                   ,flush1
                   ,flush10
                   ,flush100
                   ,flush1000
                   ,flush10000
                   ,flush1+flush10+flush100+flush1000+flush10000
                     flushes
                   ,write1
                   ,write10
                   ,write100
                   ,write1000
                   ,write10000
                   ,write1+write10+write100+write1000+write10000
                     writes
              FROM
                     (
                            SELECT
                                   CAST(MIN(sn.begin_interval_time)  over (partition BY sn.dbid, sn.snap_id) AS DATE) snap_time
                                  , --workaround to uniform snap_time over all instances in RAC ss.dbid,
                                    --uncomment if you have multipledbid in your AWR
                                   sn.instance_number
								  , ss.pin1 - lag(ss.pin1) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			        	pin1
								  , ss.pin10 - lag(ss.pin10) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    	pin10
								  , ss.pin100 - lag(ss.pin100) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    	pin100
								  , ss.pin1000 - lag(ss.pin1000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 				pin1000
								  , ss.pin10000 - lag(ss.pin10000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 				pin10000
								  , ss.flush1 - lag(ss.flush1) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			        flush1
								  , ss.flush10 - lag(ss.flush10) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    flush10
								  , ss.flush100 - lag(ss.flush100) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    flush100
								  , ss.flush1000 - lag(ss.flush1000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			flush1000
								  , ss.flush10000 - lag(ss.flush10000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			flush10000
								  , ss.write1 - lag(ss.write1) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			        write1
								  , ss.write10 - lag(ss.write10) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    write10
								  , ss.write100 - lag(ss.write100) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			    write100
								  , ss.write1000 - lag(ss.write1000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			write1000
								  , ss.write10000 - lag(ss.write10000) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) 			write10000
                            FROM
                                   dba_hist_snapshot sn
                                 , dba_hist_current_block_server ss
                            WHERE
                                   sn.snap_id         = ss.snap_id
                               AND sn.dbid            = ss.dbid
                               AND sn.instance_number =
                                   ss.instance_number
                               AND sn.begin_interval_time
                                   &delta_time_where_clause
                     )
       )
ORDER BY
       snap_time
     ,instance_number ;

spool off

