
## Environment details:

1. Oracle Database running on EC2 r5n.2xlarge.
2. Table with LOB data is generated using [Script](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_lob_to_s3/example/generate_lob_data.sql)

```
SQL> select segment_name,bytes/1024/1024 "SizeMB" from dba_segments where owner='SH' and segment_name in ('T1','T1_CL_SEG');

SEGMENT_NAME                                 SizeMB
---------------------------------------- ----------
T1                                              752
T1_CL_SEG                                147758.188

```

3. Client on EC2 r5n.8xlarge (Keep client and Database server in same subnet to reduce network latency)

### Logfile and Validation

[Full logfile](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_lob_to_s3/example/oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log)

Check for errors in log file:
```
cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | grep -i error
```
How many chunks were created for SH.T1?

```

cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | egrep -i "Starting chunk" | grep "SH.T1" | wc -l
22

cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | egrep -i "Finished chunk" | grep "SH.T1" | wc -l
22

cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | egrep -i "Starting lob chunk" | grep "SH.T1" | wc -l
44

cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | egrep -i "Finished lob chunk" | grep "SH.T1" | wc -l
44

```

How long it took to extract table SH.T1?
```
cat oracle_unload_lob_to_s3_Sep_29_2020-16_56_23.log | egrep "Starting|Finished"  | grep "SH.T1" | sed '1!{$!d;}'
2020-09-29 16:56:25,179 -        process_tasks - INFO - Starting chunk 17929 for SH.T1
2020-09-29 17:06:54,026 -    process_lob_tasks - INFO - Finished lob chunk 17944 for SH.T1 column CL
```

How much data was generated on S3?

```
aws s3 ls --summarize --human-readable --recursive  s3://oracletos3demo/SH/ | grep "Total" | tail -3
Total Objects: 21
   Total Size: 103.4 MiB

aws s3 ls --summarize --human-readable --recursive  s3://oracletos3demo1/SH/ | grep "Total" | tail -3
Total Objects: 48237
   Total Size: 70.8 GiB

```
