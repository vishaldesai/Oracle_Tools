## Environment details:

1. Oracle Database running on EC2 r5n.2xlarge.
2. Application schema SH. Data generated using [Datagenerator](http://www.dominicgiles.com/datagenerator.html)

```
SQL> select segment_name, sum(bytes)/1024/1024 "SizeMB" from dba_segments
  2   where owner='SH'
  3  and segment_type like '%TABLE%'
  4  group by segment_name;

SEGMENT_NAME                       SizeMB
------------------------------ ----------
COUNTRIES                           .0625
CUSTOMERS1                           5952
SALES                              209385
CUSTOMERS                            5952
PRODUCTS                            .0625
PROMOTIONS                           .125
SUPPLEMENTARY_DEMOGRAPHICS          87125
CHANNELS                            .0625

8 rows selected.
```

3. Client on EC2 r5n.8xlarge (Keep client and Database server in same subnet to reduce network latency)


## Runtime screenshots

### Screenshot of CPU, memory and network bandwidth utilization on Database server.

![](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_to_s3/example/snip1.PNG)

### Top output from Client virtual machine.

![](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_to_s3/example/snip2.PNG)

### Logfile and Validation

[Full logfile](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_to_s3/example/unload_ora_to_s3__Aug_28_2020-16_57_13.log)

Check for errors in log file:
```
cat unload_ora_to_s3_Aug_28_2020-16_57_13.log | grep -i error
```

How long entire job took? Job took 35 minutes to unload ~308 GB Oracle to S3.
```
head -1 unload_ora_to_s3_Aug_28_2020-16_57_13.log
08-28 16:57 root         INFO     Establish Oracle Connection
tail -1 unload_ora_to_s3_Aug_28_2020-16_57_13.log
08-28 17:32 root         INFO     Dropping task for schema.table: SH.PROMOTIONS
```

How many chunks were created for SH.SALES?
```
cat unload_ora_to_s3_Aug_28_2020-16_57_13.log | egrep "Starting chunk"  | grep "SH.SALES" | wc -l
636
cat unload_ora_to_s3_Aug_28_2020-16_57_13.log | egrep "Finished chunk"  | grep "SH.SALES" | wc -l
636
```

How long it took to extract large table SH.SALES?
```
cat unload_ora_to_s3_Aug_28_2020-16_57_13.log | egrep "Starting chunk|Finished chunk"  | grep "SH.SALES" | sed '1!{$!d;}'
08-28 16:57 root         INFO     Starting chunk 8336 for SH.SALES
08-28 17:23 root         INFO     Finished chunk 8968 for SH.SALES
```

How much data was generated on S3?
```
aws s3 ls --summarize --human-readable --recursive  s3://vishalemrfs/SH/ | grep "Total
Total Objects: 940
Total Size: 95.5 GiB
```

What is the average size of parquet files?
```
aws s3 ls --human-readable --recursive s3://vishalemrfs/SH/ | awk '{ total += $3; count++ } END { print total/count }'
104.114 MB
```

