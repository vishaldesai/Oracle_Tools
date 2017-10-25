--
-- Perfsheet4_query_AWR_cache_transfer_stats.sql -> Extracts data from dba_hist_sysstat. This provides information on avg cr and current block transfer time. 
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
prompt Dumping AWR data to file Perfsheet4_AWR_cache_transfer_stats_&myfilesuffix..csv, please wait
prompt 
set termout off

spool Perfsheet4_AWR_cache_transfer_stats_&myfilesuffix..csv


SELECT
       snap_time
     , instance_number
     , instance
       || '->'
       || instance_number transfer
     , class
     , nvl(totcr,0)																				"CR Blocks Received"														
     , nvl(cr_block    /DECODE(totcr,0, to_number(NULL),totcr)*100,0) 							"CR Blocks %Immed"
     , nvl(cr_busy     /DECODE(totcr,0, to_number(NULL),totcr)*100,0) 							"CR Blocks %Busy"
     , nvl(cr_congested/DECODE(totcr,0, to_number(NULL),totcr)*100,0)  							"CR Blocks %Cngst"
     , nvl(totcu,0) 																			"CU Blocks Received"
     , nvl(current_block/DECODE(totcu,0, to_number(NULL),totcu)*100,0)        					"CU Blocks %Immed"
     , nvl(current_busy     /DECODE(totcu,0, to_number(NULL),totcu)*100,0)  					"CU Blocks %Busy"
     , nvl(current_congested/DECODE(totcu,0, to_number(NULL),totcu)*100,0)      				"CU Blocks %Cngst"
     , nvl(totcr_t/DECODE(totcr, 0, NULL, totcr)/1000,0)  										"CR Avg Time(ms) All"
     , nvl(cr_block_t/DECODE(cr_block, 0, NULL, cr_block)/1000,0)  								"CR Avg Time(ms) Immed"
     , nvl(cr_busy_t /DECODE(cr_busy , 0, NULL, cr_busy )/1000,0)  								"CR Avg Time(ms) Busy"
     , nvl(cr_congested_t/DECODE(cr_congested, 0, NULL, cr_congested)/1000,0)  					"CR Avg Time(ms) Cngst"
     , nvl(totcu_t/DECODE(totcu, 0, NULL, totcu)/1000,0)  										"CU Avg Time(ms) All"
     , nvl(current_block_t/ DECODE(current_block, 0, NULL, current_block)/1000,0)  				"CU Avg Time(ms) All"
     , nvl(current_busy_t / DECODE(current_busy , 0, NULL, current_busy )/1000,0)  				"CU Avg Time(ms) All"
     , nvl(current_congested_t/ DECODE(current_congested, 0, NULL,current_congested)/1000,0)  	"CR Avg Time(ms) All"
FROM
       (
              SELECT
                     snap_time
                   ,instance_number
                   ,instance
                   ,class
                   ,SUM(cr_block) cr_block
                   ,SUM(cr_busy) cr_busy
                   ,SUM(cr_congested) cr_congested
                   ,SUM(current_block) current_block
                   ,SUM(current_busy) current_busy
                   ,SUM(current_congested) current_congested
                   ,SUM(cr_block     +cr_busy+cr_congested) totcr
                   ,SUM(current_block+current_busy+current_congested)
                     totcu
                   ,SUM(cr_block_time) cr_block_t
                   ,SUM(cr_busy_time) cr_busy_t
                   ,SUM(cr_congested_time) cr_congested_t
                   ,SUM(current_block_time) current_block_t
                   ,SUM(current_busy_time) current_busy_t
                   ,SUM(current_congested_time) current_congested_t
                   ,SUM(cr_block_time +cr_busy_time+cr_congested_time) totcr_t
                   ,SUM(current_block_time+current_busy_time+current_congested_time) totcu_t
              FROM
                     (
                            SELECT
                     CAST(MIN(sn.begin_interval_time) over (partition  BY sn.dbid,sn.snap_id) AS DATE) snap_time
                   , --workaround to uniform snap_time over all instances in RAC ss.dbid,
                     --uncomment if you have multipledbid in your AWR
                     ss.instance_number
                   , ss.instance
                   , CASE
                            WHEN ss.class IN ('data block',
                                   'undo header','undo block')
                            THEN ss.class
                            ELSE 'others'
                     END class
				  , ss.cr_block - lag(ss.cr_block) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls FIRST) 						cr_block
				  , ss.cr_busy - lag(ss.cr_busy) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id nulls FIRST)  						cr_busy
				  , ss.cr_congested - lag(ss.cr_congested) over (partition BY ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)          	cr_congested
				  , ss.current_block - lag(ss.current_block) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)       	current_block
				  , ss.current_busy - lag(ss.current_busy) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST) 			current_busy
				  , ss.current_congested - lag(ss.current_congested) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)   current_congested
				  , ss.cr_block_time - lag(ss.cr_block_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)   		cr_block_time 
				  , ss.cr_busy_time - lag(ss.cr_busy_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)         	cr_busy_time
				  , ss.cr_congested_time - lag(ss.cr_congested_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST) 	cr_congested_time		   
				  , ss.current_block_time - lag(ss.current_block_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST) current_block_time
				  , ss.current_busy_time - lag(ss.current_busy_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST)   current_busy_time
				  , ss.current_congested_time - lag(ss.current_congested_time) over (partition BY  ss.dbid,ss.instance_number,ss.instance,ss.class order by sn.snap_id  nulls FIRST) current_congested_time
                            FROM
                                   dba_hist_snapshot sn
                                 , dba_hist_inst_cache_transfer ss
                            WHERE
                                   sn.snap_id         = ss.snap_id
                               AND sn.dbid            = ss.dbid
                               AND sn.instance_number =
                                   ss.instance_number
                               AND sn.begin_interval_time
                                   &delta_time_where_clause
                     )
              GROUP BY
                     snap_time
                   ,instance_number
                   ,instance
                   ,class
       )
ORDER BY
       snap_time
     ,instance_number;


spool off

