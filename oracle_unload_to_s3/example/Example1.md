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

1. Screenshot of CPU, memory and network bandwidth utilization on Database server.

[](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_to_s3/example/snip1.PNG)

2. Top output from Client virtual machine.

[](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_to_s3/example/snip2.PNG)

3. Logfile



