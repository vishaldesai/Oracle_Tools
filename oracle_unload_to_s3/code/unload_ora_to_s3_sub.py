#
# Purpose       : Unload Oracle tables data into S3
# Author        : Vishal Desai and Anand Prakash
# Change        : 8/28/2020 - MVC release

import argparse
import sys
import cx_Oracle
import pandas as pd
import awswrangler as wr

con = cx_Oracle.connect(user=str(sys.argv[3]), password=str(sys.argv[4]), dsn=str(sys.argv[5])+"/"+str(sys.argv[6])+":"+str(sys.argv[7]))

df = pd.read_sql(str(sys.argv[2]), con)
s3path = str(sys.argv[1])

wr.s3.to_parquet(
    df,
    path=s3path,
    compression=str(sys.argv[8])
)

