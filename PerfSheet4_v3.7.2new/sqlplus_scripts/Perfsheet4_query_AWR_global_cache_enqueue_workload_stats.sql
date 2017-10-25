--
-- Perfsheet4_query_AWR_global_cache_enqueue_workload_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_global_cache_enqueue_workload_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_global_cache_enqueue_workload_stats_&myfilesuffix..csv

SELECT
       snap_time
     , instance_number
     , glgt*10/decode((glag+glsg),0,null,(glag+glsg))    "GE Get Time(ms)"
     , gccrrt*10/decode(gccrrv,0,null,gccrrv)            "CR Blocks Receive Time(ms)"
     , gccrbt*10/decode(gccrsv,0,null,gccrsv)            "CR Blocks Build Time(ms)"
     , gccrst*10/decode(gccrsv,0,null,gccrsv)            "CR Blocks Send Time(ms)"
     , gccrft*10/decode(gccrfl,0,null,gccrfl)            "CR Blocks Flush Time(ms)"
     , gccrfl        /decode(gccrsv,0,null,gccrsv)*100   "CR Blocks Log Flush CR Srvd%"
     , gccurt*10/decode(gccurv,0,null,gccurv)            "CU Blocks Receive Time(ms)"
     , gccupt*10/decode(gccusv,0,null,gccusv)            "CU Blocks Build Time(ms)"
     , gccust*10/decode(gccusv,0,null,gccusv)            "CU Blocks Send Time(ms)"
     , gccuft*10/decode(gccufl,0,null,gccufl)            "CU Blocks Flush Time(ms)"
     , gccufl        /decode(gccusv,0,null,gccusv)*100   "CU Blocks Log Flush CR Srvd%"
FROM
       (
              SELECT
                     CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) snap_time
                   , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
				   --uncomment if you have multipledbid in your AWR
                     sn.instance_number
        		   , ss.gccrrv - lag(ss.gccrrv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  gccrrv
                   , ss.gccrrt - lag(ss.gccrrt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  gccrrt
                   , ss.gccurv - lag(ss.gccurv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccurv
                   , ss.gccurt - lag(ss.gccurt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccurt
                   , ss.gccrsv - lag(ss.gccrsv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccrsv
				   , ss.gccrbt - lag(ss.gccrbt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccrbt
				   , ss.gccrst - lag(ss.gccrst) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccrst
				   , ss.gccrft - lag(ss.gccrft) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccrft
				   , ss.gccusv - lag(ss.gccusv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccusv
				   , ss.gccupt - lag(ss.gccupt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccupt
				   , ss.gccust - lag(ss.gccust) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccust
				   , ss.gccuft - lag(ss.gccuft) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccuft
				   , ss.glgt - lag(ss.glgt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) glgt
				   , ss.glsg - lag(ss.glsg) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) glsg
				   , ss.glag - lag(ss.glag) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) glag
				   , crfl.gccrfl - lag(crfl.gccrfl) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccrfl
				   , cufl.gccufl - lag(cufl.gccufl) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) gccufl
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
                                                 'gc cr blocks received', 'gc cr block receive time'
												, 'gc current blocks received', 'gc current block receive time'
												, 'gc cr blocks served', 'gc cr block build time'
												, 'gc cr block flush time', 'gc cr block send time'
												, 'gc current block pin time', 'gc current blocks served'
												, 'gc current block send time', 'gc current block flush time'
												, 'global enqueue get time'
												, 'global enqueue gets sync', 'global enqueue gets async'
                                                 )
                                   )
                                   pivot (SUM(value) FOR stat_name IN
                                   ( 
								    'gc cr blocks received'                gccrrv
								   , 'gc cr block receive time'            gccrrt
								   , 'gc current blocks received'          gccurv
								   , 'gc current block receive time'       gccurt
								   , 'gc cr blocks served'                 gccrsv
								   , 'gc cr block build time'              gccrbt
								   , 'gc cr block send time'               gccrst
								   , 'gc cr block flush time'              gccrft
								   , 'gc current blocks served'            gccusv
								   , 'gc current block pin time'           gccupt
								   , 'gc current block send time'          gccust
								   , 'gc current block flush time'         gccuft
								   , 'global enqueue get time'               glgt
								   , 'global enqueue gets sync'              glsg
								   , 'global enqueue gets async'             glag
								   )
                                   )
                     )
                     ss
					, ( SELECT 
					            snap_id
                                , dbid
                                , instance_number
								, flushes gccrfl
						FROM	dba_hist_cr_block_server
					   ) crfl
					, ( SELECT   snap_id
                                , dbid
                                , instance_number
								, ((flush1+flush10+flush100+flush1000+flush10000) - (flush1+flush10+flush100+flush1000+flush10000)) gccufl
						FROM	dba_hist_current_block_server
					  ) cufl
              WHERE
                     sn.snap_id         = ss.snap_id
                 AND sn.dbid            = ss.dbid
                 AND sn.instance_number = ss.instance_number
				 AND sn.snap_id         = crfl.snap_id
                 AND sn.dbid            = crfl.dbid
                 AND sn.instance_number = crfl.instance_number   
				 AND sn.snap_id         = cufl.snap_id
                 AND sn.dbid            = cufl.dbid
                 AND sn.instance_number = cufl.instance_number  				 
                 AND sn.begin_interval_time
                     &delta_time_where_clause
              ORDER BY
                     sn.snap_id
       ) 
	   WHERE 
			gccrrv is not null 
		AND gccrrt is not null
		AND gccurv is not null
		AND gccurt is not null
		AND gccrsv is not null
	ORDER BY instance_number, snap_time;

spool off

