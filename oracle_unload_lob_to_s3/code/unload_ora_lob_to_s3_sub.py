#
# Purpose       : Unload Oracle tables data into S3
# Author        : Vishal Desai and Anand Prakash
# Change        : 8/28/2020 - MVC release

import boto3
import argparse
import sys
import cx_Oracle
import pandas as pd
import awswrangler as wr

s3 = boto3.resource('s3')

def OutputTypeHandler(cursor, name, defaultType, size, precision, scale):
    if defaultType == cx_Oracle.DB_TYPE_CLOB:
        return cursor.var(cx_Oracle.DB_TYPE_LONG, arraysize=cursor.arraysize)
    if defaultType == cx_Oracle.DB_TYPE_BLOB:
        return cursor.var(cx_Oracle.DB_TYPE_LONG_RAW, arraysize=cursor.arraysize)

con = cx_Oracle.connect(user=str(sys.argv[3]), password=str(sys.argv[4]), dsn=str(sys.argv[5])+"/"+str(sys.argv[6])+":"+str(sys.argv[7]))

df = pd.read_sql(str(sys.argv[2]), con)


if len(df) > 0:

    s3path = str(sys.argv[1])
    con.outputtypehandler = OutputTypeHandler
    cursor = con.cursor()
    lobsql = "select " + str(sys.argv[12]) + "," + str(sys.argv[11]) + " from " + str(sys.argv[9]) + '.' + str(sys.argv[10]) + " where rowid = :1"

    for index, row in df.iterrows():
        rowid=row['ROWID']

        cursor.execute(lobsql, [rowid])
        uniqueval, lobData = cursor.fetchone()
        if lobData is not None:
            key =  str(sys.argv[9]) + '/' + str(sys.argv[10]) + '/' + str(sys.argv[11]) + '/' + str(uniqueval) + '.' + str(sys.argv[13])
            object = s3.Object(str(sys.argv[8]), key)
            object.put(Body=lobData)

            