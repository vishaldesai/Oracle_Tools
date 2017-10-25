--
-- Perfsheet4_query_AWR_osstat.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_osstat_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_osstat_&myfilesuffix..csv

SELECT
                 CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) snap_time
                 , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
					 --uncomment if you have multipledbid in your AWR
                   sn.instance_number
				 , num_cpus         "CPUs"
				 , num_cores        "CORES"
				 , num_socks        "SOCKETS"
				 , load             "Begin Load"
				 , load             "End Load"
				 , 100 * busy_time/decode(busy_time + idle_time,0,null,busy_time+idle_time)  "Busy %"
				 , 100 * user_time/decode(busy_time + idle_time,0,null,busy_time+idle_time)  "Usr %"
				 , 100 * sys_time/decode(busy_time + idle_time,0,null,busy_time+idle_time)   "Sys %"
				 , 100 * wio_time/decode(busy_time + idle_time,0,null,busy_time+idle_time)   "WIO %"
				 , 100 * idle_time/decode(busy_time + idle_time,0,null,busy_time+idle_time)  "Idl %"
				 , busy_time/100                            "Busy Time(s)"
				 , idle_time/100                            "Idle Time(s)"
				 , (busy_time + idle_time)/100              "Total Time(s)"
				 , mem/1048576                            "Memory(MB)"
						  FROM
                     dba_hist_snapshot sn
                   , (
                                 SELECT
                                        snap_id,
										instance_number,
										dbid,
										sum(num_cpus_v) 	num_cpus,
										sum(num_cores_v)	 num_cores,
										sum(num_socks_v) 	num_socks,
										sum(load_v) 		load,
										sum(busy_time_v) 	busy_time,
										sum(idle_time_v) 	idle_time,
										sum(user_time_v) 	user_time,
										sum(sys_time_v) 	sys_time,
										sum(wio_time_v) 	wio_time,
										sum(mem_v) 			mem
                                          FROM
                                                 dba_hist_osstat
                                   pivot (sum(value) as v for stat_name in ( 'NUM_CPUS'   		num_cpus
																		  ,'NUM_CPU_CORES'   	num_cores
																		  ,'NUM_CPU_SOCKETS' 	num_socks
																		  ,'LOAD'       		load
																		  ,'BUSY_TIME'  		busy_time
																		  ,'IDLE_TIME'  		idle_time
																		  ,'USER_TIME'  		user_time
																		  ,'SYS_TIME'   		sys_time
																		  ,'IOWAIT_TIME' 		wio_time
																		  ,'PHYSICAL_MEMORY_BYTES'  mem
																		  )
                                   )
								GROUP BY snap_id,instance_number,dbid
                     )
                     ss
              WHERE
                     sn.snap_id         = ss.snap_id
                 AND sn.dbid            = ss.dbid
                 AND sn.instance_number = ss.instance_number
                 AND sn.begin_interval_time
                     &delta_time_where_clause
              ORDER BY
                     snap_time,instance_number;

spool off

