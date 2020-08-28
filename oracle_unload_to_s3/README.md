
## Problem Statement
Unloading large Oracle schemas/tables to S3 in shortest possible time is challening task. There are various database replication tools that does the job but requires engineering effort to discover schema/tables, learn replication tool, create configuration and automation, size replication instances etc. When tables are large, engineers have to create multiple parallel tasks based on primary key range filters. If these ranges are too big, Oracle CBO may decide to do full table scan for parallel threads that will impact performance of existing application workload and full load.

## What does this script do?

Python script unload Oracle tables to S3 in parquet format with little to no iteration and other challenges mentioned above.

## Implementation

# 

