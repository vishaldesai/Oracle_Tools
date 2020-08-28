
## Problem Statement
Unloading large Oracle schemas/tables to S3 in shortest possible time is challening task. There are various database replication tools that does the job but requires engineering effort to discover schema/tables, learn replication tool, create configuration and automation, size replication instances etc. When tables are large, engineers have to create multiple parallel tasks based on primary key range filters. If these ranges are too big, Oracle CBO may decide to do full table scan for parallel threads that will impact performance of existing application workload and full load.

## What does this script do?

Python script unload Oracle tables to S3 in parquet format with little to no iteration and other challenges mentioned above.

## Implementation

# Pre-requisites

1. Create EC2 instance with r5n type
2. Install python3
3. Install boto3, csv, argparse, sys, datetime, threading, cx_Oracle, os, logging, queue and subprocess python packages
4. Install oracle instance client
5. Oracle database user must have read table privileges and execute permission on DBMS_PARALLEL_EXECUTE

# Create configuration file

Create configuration file and list all schema tables.

# Run code

```python
python3 unload_ora_to_s3.py \
             --p_schema_table_config oracle_schema_table.csv \
             --p_username sh \
             --p_password sh \
             --p_oracle_host 18.213.128.132 \
             --p_service orcl --p_port 1521 \
             --p_target_s3_bucket vishalemrfs \
             --p_target_s3_chunk_mb 250 \
             --p_target_s3_compression snappy \
             --p_parallel_threads 32 \
             --p_child_code_file unload_ora_to_s3_sub.py \
             --p_logging_level INFO \
             --p_logfile_location /root
 ```

