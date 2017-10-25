--
-- Perfsheet4_query_AWR_global_cache_efficiency.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_global_cache_efficiency_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_global_cache_efficiency_&myfilesuffix..csv
	
SELECT
       snap_time
     , instance_number
     , (100*(1-(phyrc + gccrrv + gccurv)/(cgfc+dbfc))) "Local%"
     , (100*(gccurv+gccrrv)/(cgfc+dbfc)) "Remote%"
     , (100*phyrc/(cgfc+dbfc)) "Disk%"
FROM
       (
              SELECT
                     CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) snap_time
                   , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
				   --uncomment if you have multipledbid in your AWR
                     sn.instance_number
        		   , ss.gccrrv - lag(ss.gccrrv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) gccrrv
                   , ss.gccurv - lag(ss.gccurv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) gccurv
                   , ss.phyrc - lag(ss.phyrc) over (partition BY ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) phyrc
                   , ss.cgfc - lag(ss.cgfc) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) cgfc
                   , ss.dbfc - lag(ss.dbfc) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) dbfc
              FROM
                     dba_hist_snapshot sn
                   , (
                            SELECT
                                   *
                            FROM
                                   (
                                          SELECT
                                                 snap_id
                                               , dbid
                                               , instance_number
                                               , stat_name
                                               , NVL(value,0) value
                                          FROM
                                                 dba_hist_sysstat
                                          WHERE
                                                 stat_name IN (
                                                 'gc cr blocks received'
                                                 ,'gc current blocks received'
                                                 ,'physical reads cache'
                                                 ,'consistent gets from cache'
                                                 ,'db block gets from cache'
                                                 )
                                   )
                                   pivot (SUM(value) FOR stat_name IN
                                   ( 'gc cr blocks received' gccrrv ,
                                   'gc current blocks received' gccurv , 
								   'physical reads cache'   phyrc ,
                                   'consistent gets from cache' cgfc
                                   , 'db block gets from cache' dbfc)
                                   )
                     )
                     ss
              WHERE
                     sn.snap_id         = ss.snap_id
                 AND sn.dbid            = ss.dbid
                 AND sn.instance_number = ss.instance_number
                 AND sn.begin_interval_time
                     &delta_time_where_clause
              ORDER BY
                     sn.snap_id
       ) 
	   WHERE 
			gccrrv is not null 
		AND gccurv is not null
		AND phyrc is not null
		AND cgfc is not null
		AND dbfc is not null
		ORDER BY instance_number, snap_time;

spool off

