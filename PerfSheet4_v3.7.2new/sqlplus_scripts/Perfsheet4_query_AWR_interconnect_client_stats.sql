--
-- Perfsheet4_query_AWR_interconnect_client_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_interconnect_client_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_interconnect_client_stats_&myfilesuffix..csv

SELECT
       snap_time
     , instance_number
     , (cache_bs + ipq_bs + dlm_bs + ping_bs + diag_bs + cgs_bs + osm_bs + str_bs + int_bs + ksv_bs + ksxr_bs)/1048576  "Sent MB Total"
     , cache_bs/1048576                   																				"Sent MB Cache"
     , ipq_bs/1048576                       																			"Sent MB IPQ"
     , dlm_bs/1048576                       																			"Sent MB DLM"
     , ping_bs/1048576                     																				"Sent MB PING"
     , (diag_bs + cgs_bs + osm_bs + str_bs + int_bs + ksv_bs + ksxr_bs)/1048576 										"Sent MB Misc"
     , (cache_br + ipq_br + dlm_br + ping_br + diag_br + cgs_br + osm_br + str_br + int_br + ksv_br + ksxr_br)/1048576 	"Rcvd MB Total"
     , cache_br/1048576                   																				"Rcvd MB Cache"
     , ipq_br/1048576                       																			"Rcvd MB IPQ"
     , dlm_br/1048576                       																			"Rcvd MB DLM"
     , ping_br/1048576                     																				"Rcvd MB PING"
     , (diag_br + cgs_br + osm_br + str_br + int_br + ksv_br + ksxr_br)/1048576 										"Rcvd MB Misc"
FROM
       (
              SELECT
                     CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) 									snap_time
                   , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
					 --uncomment if you have multipledbid in your AWR
                     sn.instance_number
        		   , ss.dlm_bs - lag(ss.dlm_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  		dlm_bs
                   , ss.cache_bs - lag(ss.cache_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  	cache_bs
                   , ss.ping_bs - lag(ss.ping_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST)		ping_bs
                   , ss.diag_bs - lag(ss.diag_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		diag_bs
                   , ss.cgs_bs - lag(ss.cgs_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		cgs_bs
				   , ss.ksxr_bs - lag(ss.ksxr_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ksxr_bs
				   , ss.ipq_bs - lag(ss.ipq_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ipq_bs
				   , ss.osm_bs - lag(ss.osm_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		osm_bs
				   , ss.str_bs - lag(ss.str_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		str_bs
				   , ss.int_bs - lag(ss.int_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		int_bs
				   , ss.ksv_bs - lag(ss.ksv_bs) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ksv_bs
        		   , ss.dlm_br - lag(ss.dlm_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  		dlm_br
                   , ss.cache_br - lag(ss.cache_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST)  	cache_br
                   , ss.ping_br - lag(ss.ping_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ping_br
                   , ss.diag_br - lag(ss.diag_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		diag_br
                   , ss.cgs_br - lag(ss.cgs_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		cgs_br
				   , ss.ksxr_br - lag(ss.ksxr_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ksxr_br
				   , ss.ipq_br - lag(ss.ipq_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ipq_br
				   , ss.osm_br - lag(ss.osm_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		osm_br
				   , ss.str_br - lag(ss.str_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		str_br
				   , ss.int_br - lag(ss.int_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		int_br
				   , ss.ksv_br - lag(ss.ksv_br) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) 		ksv_br
              FROM
                     dba_hist_snapshot sn
                   , (
                                 SELECT
                                                 *
                                          FROM
                                                 dba_hist_ic_client_stats
                                   pivot (sum(bytes_sent) as bs,sum(bytes_received) as br for name in ('dlm' dlm
                                       ,'cache'    cache
                                       ,'ping'     ping
                                       ,'diag'     diag
                                       ,'cgs'      cgs
                                       ,'ksxr'     ksxr
                                       ,'ipq'      ipq
                                       ,'osmcache' osm
                                       ,'streams'  str
                                       ,'internal' int
                                       ,'ksv'      ksv)
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
	WHERE dlm_bs is not null
	ORDER BY snap_time,instance_number;

spool off

