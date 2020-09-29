
# What does this script do?

Python script extracts Oracle tables with LOB data to S3 in parquet format. Script stores pointer in parquet file for CLOB and BLOB columns and original content of unstructured columns will be stored in different bucket/prefixes.

Example:
Oracle Table
| id | shortnum | longnum | cl                        |
|----|----------|---------|---------------------------|
| 1  | 50       | 9000    | Large clob content here   |
| 2  | 20       | 90000   | Another clob content here |

S3 Parquet file
| id | shortnum | longnum | cl                                                           |
|----|----------|---------|--------------------------------------------------------------|
| 1  | 50       | 9000    | https://<lobbucket>/<schema>/<tablename>/<columnname>/1.txt  |
| 2  | 20       | 90000   | https://<lobbucket>/<schema>/<tablename>/<columnname>/2.txt  |
  
https://<lobbucket>/<schema>/<tablename>/<columnname>/1.txt - Large clob content here
https://<lobbucket>/<schema>/<tablename>/<columnname>/2.txt - Another clob content here

# Implementation

## Pre-requisites

1. Create EC2 instance (r5n instance type recommended)
2. Install python3
3. Install boto3, csv, argparse, sys, datetime, threading, cx_Oracle, os, logging, queue and subprocess python packages
4. Install oracle instance client
5. Oracle database user must have read table privileges and execute permission on DBMS_PARALLEL_EXECUTE
6. Database Tables must be analyzed.

## Create configuration file

Create configuration file and list all schema tables.
[Example](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_lob_to_s3/code/oracle_schema_table.csv)
[Example](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_lob_to_s3/code/oracle_schema_lob_table.csv)

## Run code

Update input parameters and run code. p_target_s3_chunk_mb can be increased to create large parquet files. Due to compression S3 file sizes will be smaller than s3 chunk size setting. p_parallel_threads can be tuned depending on the client EC2 instance size and number of concurrent connections that you want to run on Oracle database.  

```python
python3 unload_ora_to_s3.py \
	--p_schema_table_config oracle_schema_table.csv \
	--p_schema_table_lob_config oracle_schema_table_lob.csv \
	--p_username username \
	--p_oracle_host xx.xx.xx.xx \
	--p_service orcl \
	--p_port 1521 \
	--p_target_s3_bucket bucketname \
	--p_target_s3_chunk_mb 250 \
	--p_target_s3_compression snappy \
	--p_parallel_threads 32 \
	--p_child_code_file unload_ora_to_s3_sub.py \
	--p_child_code_lob_file unload_ora_to_s3_lob_sub.py
 ```


## Example

[Example1](https://github.com/vishaldesai/Oracle_Tools/blob/master/oracle_unload_lob_to_s3/example/Example1.md)

# Limitations

1. Does not support CDC
2. If p_target_s3_chunk_mb is too high, number of actual parallel threads running for LOB data extract could be less than p_parallel_threads. 

