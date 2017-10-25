--
-- Perfsheet4_query_AWR_global_cache_enqueue_messaging_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_global_cache_enqueue_messaging_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_global_cache_enqueue_messaging_stats_&myfilesuffix..csv
	
SELECT
       snap_time
     , instance_number
     , msgsqt /decode(msgsq,0,null,msgsq)                          "Que Time(ms) Sent"
     , msgsqtk/decode(msgsqk,0,null,msgsqk)                        "Que Time(ms) on ksxp"
     , msgrqt /decode(msgrq,0,null,msgrq)                          "Que Time(ms) Received"
     , pmpt   /decode(pmrv,0,null,pmrv)                            "Process Time GCS msgs"
     , npmpt  /decode(npmrv,0,null,npmrv)                          "Proces Time GES msgs"
     , 100*dmsd/decode((dmsd+dmsi+dmfc),0,null,(dmsd+dmsi+dmfc))   "%Message Sent Direct"
     , 100*dmsi/decode((dmsd+dmsi+dmfc),0,null,(dmsd+dmsi+dmfc))   "%Message Sent Indirect"
     , 100*dmfc/decode((dmsd+dmsi+dmfc),0,null,(dmsd+dmsi+dmfc))   "%Message Sent Flow Ctrl"
FROM
       (
              SELECT
                     CAST(MIN(sn.begin_interval_time) over (partition BY sn.dbid,sn.snap_id) AS DATE) snap_time
                   , --workaround to uniform snap_time over all instances in RAC ss.dbid,  
				   --uncomment if you have multipledbid in your AWR
                     sn.instance_number
        		   , ss.msgsq - lag(ss.msgsq) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) msgsq
                   , ss.msgsqt - lag(ss.msgsqt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id nulls FIRST) msgsqt
                   , ss.msgsqtk - lag(ss.msgsqtk) over (partition BY ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) msgsqtk
                   , ss.msgsqk - lag(ss.msgsqk) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) msgsqk
                   , ss.msgrqt - lag(ss.msgrqt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) msgrqt
                   , ss.msgrq - lag(ss.msgrq) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) msgrq
                   , ss.pmrv - lag(ss.pmrv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) pmrv				   
                   , ss.pmpt - lag(ss.pmpt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) pmpt				   
                   , ss.npmrv - lag(ss.npmrv) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) npmrv				   
                   , ss.npmpt - lag(ss.npmpt) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) npmpt				   
                   , ss.dmsd - lag(ss.dmsd) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) dmsd
                   , ss.dmsi - lag(ss.dmsi) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) dmsi
				   , ss.dmfc - lag(ss.dmfc) over (partition BY  ss.dbid,ss.instance_number order by sn.snap_id  nulls FIRST) dmfc
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
                                               , name
                                               , NVL(value,0) value
                                          FROM
                                                 dba_hist_dlm_misc
                                          WHERE
                                                 name IN (
                                                 'msgs sent queued', 'msgs sent queue time (ms)'
												, 'msgs sent queue time on ksxp (ms)', 'msgs sent queued on ksxp'
												, 'msgs received queue time (ms)', 'msgs received queued'
												, 'gcs msgs received', 'gcs msgs process time(ms)'
												, 'ges msgs received', 'ges msgs process time(ms)'
												, 'messages sent directly', 'messages sent indirectly'
												, 'messages flow controlled'
                                                 )
                                   )
                                   pivot (SUM(value) FOR name IN
                                               ('msgs sent queued'                        msgsq
											   , 'msgs sent queue time (ms)'              msgsqt
											   , 'msgs sent queue time on ksxp (ms)'     msgsqtk
											   , 'msgs sent queued on ksxp'               msgsqk
											   , 'msgs received queue time (ms)'          msgrqt
											   , 'msgs received queued'                    msgrq
											   , 'gcs msgs received'                        pmrv
											   , 'gcs msgs process time(ms)'                pmpt
											   , 'ges msgs received'                       npmrv
											   , 'ges msgs process time(ms)'               npmpt
											   , 'messages sent directly'                   dmsd
											   , 'messages sent indirectly'                 dmsi
											   , 'messages flow controlled'                 dmfc
												)
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
			msgsq is not null 
		AND msgsqt is not null
		AND msgsqtk is not null
		AND msgsqk is not null
		AND msgrqt is not null
		ORDER BY snap_time, instance_number;

spool off

