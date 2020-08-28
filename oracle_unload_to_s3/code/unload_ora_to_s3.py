#                 
# Purpose       : Unload Oracle tables data into S3. Script is meant to be used only for full load.
# Author        : Vishal Desai
# Change        : 8/28/2020 - MVC release
#
# Prereq        : 1 - Install python3
#                 2 - Install boto3, csv, argparse, sys, datetime, threading, cx_Oracle, os, logging, queue and subprocess python packages
#                 3 - Install oracle instance client
#           
# Assumptions   : 1 - Tables must be analyzed as code uses avg_row_len from dba_tables to determine rowid chunks
#
# Limitations   : 1 - Does not support CDC
#                 2 - All table columns are extracted.
#                 3 - Code is not tested for lob data types.
#
# Usage         : python3 unload_ora_to_s3.py \
#                    --p_schema_table_config oracle_schema_table.csv \
#                    --p_username username \
#                    --p_password password \
#                    --p_oracle_host xx.xx.xx.xx \
#                    --p_service orcl --p_port 1521 \
#                    --p_target_s3_bucket bucketname \
#                    --p_target_s3_chunk_mb 250 \
#                    --p_target_s3_compression snappy \
#                    --p_parallel_threads 32 \
#                    --p_child_code_file unload_ora_to_s3_sub.py \
#                    --p_logging_level INFO \
#                    --p_logfile_location /root 

import boto3
import csv
import argparse
import sys
import datetime
import threading
import cx_Oracle
import os
import logging
from queue import Queue
from subprocess import check_output, getoutput,STDOUT, CalledProcessError

jobs = Queue()
running = None
p_schema_table_config=None
p_username=None
p_password=None
p_oracle_host=None
p_service=None
p_port=None
p_target_s3_bucket=None
p_target_s3_chunk_mb=None
p_parallel_threads=None
p_child_code_file=None
p_schema_table_config=None
p_target_s3_compression=None

def items_queue_worker():
    while running:
        try:
            task = jobs.get()
            if task is None:
                continue
            try:
                process_tasks(task)
            finally:
                jobs.task_done()
            if jobs.empty():
                break
        except jobs.empty():
            pass
        except:
            logging.exception('Error while processing queue')


def process_tasks(task):

    startTime = datetime.datetime.now()
    task = task.split(":")
    table = task[1].split(".")
    logging.info('Starting chunk %s for %s.%s', task[0],table[0],table[1])
    s3path = "s3://" + p_target_s3_bucket + "/" +  table[0] + "/" + table[1] + "/" + "part" + task[0] + "." + p_target_s3_compression + ".parquet"
    pythonscript = 'python3 ' + os.path.abspath(os.getcwd()) + '/' + p_child_code_file + ' "' + s3path + '" "' + task[2] + '" "' + p_username + '" "' + p_password + '" "' + p_oracle_host + '" "' + p_service + '" "' + p_port + '" "' + p_target_s3_compression + '" &> /dev/null; echo $?'
    logging.debug(pythonscript)
    o = check_output(pythonscript , stderr=None, shell=True)

    if int(o.decode("utf-8")) == 0:
        logging.info('Finished chunk %s for %s.%s', task[0],table[0],table[1])
    else:
        logging.exception('Error processing chunk %s for %s.%s', task[0],table[0],table[1])
                
def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--p_schema_table_config', required=True)
    parser.add_argument('--p_username', required=True)
    parser.add_argument('--p_password', required=True)
    parser.add_argument('--p_oracle_host', required=True)
    parser.add_argument('--p_service',required=True)
    parser.add_argument('--p_port',required=True)
    parser.add_argument('--p_target_s3_bucket',required=True)
    parser.add_argument('--p_target_s3_chunk_mb',required=True)
    parser.add_argument('--p_target_s3_compression',required=True)
    parser.add_argument('--p_parallel_threads',required=True)
    parser.add_argument('--p_child_code_file',required=True)
    parser.add_argument('--p_logging_level',required=True)
    parser.add_argument('--p_logfile_location',required=True)
    args = parser.parse_args(arguments)
    
    global p_target_s3_bucket
    p_target_s3_bucket = args.p_target_s3_bucket
    global p_username
    p_username = args.p_username
    global p_password
    p_password = args.p_password
    global p_oracle_host
    p_oracle_host = args.p_oracle_host
    global p_service
    p_service = args.p_service
    global p_port
    p_port = args.p_port
    global p_child_code_file
    p_child_code_file = args.p_child_code_file
    global p_target_s3_compression
    p_target_s3_compression = args.p_target_s3_compression
    
    # Logging config
    
    logging.basicConfig(level=args.p_logging_level,
                    format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s',
                    datefmt='%m-%d %H:%M',
                    filename=args.p_logfile_location + '/' + str(sys.argv[0]).split('.')[0] + '_' + (datetime.datetime.now()).strftime("%b_%d_%Y-%H_%M_%S") + '.log',
                    filemode='w')
    try:
        global running
        running = True

        # Create Oracle Database connection and cursors
        logging.info('Establish Oracle Connection')
        con = cx_Oracle.connect(user=args.p_username, password=args.p_password, dsn=args.p_oracle_host+"/"+args.p_service+":"+args.p_port)
        cursor1 = con.cursor()
        cursor2 = con.cursor()
        cursor3 = con.cursor()
        cursor4 = con.cursor()
        cursor5 = con.cursor()
        
        # Create Oracle parallel tasks for all tables from input csv config
        p_schema_table_config = os.path.abspath(os.getcwd()) + '/' + args.p_schema_table_config
        logging.info('Process list of Schema/Table from input csv config file')
        with open(p_schema_table_config) as csv_file:
            csv.register_dialect('strip', skipinitialspace=True)
            reader = csv.DictReader(csv_file, dialect='strip')
            fieldnames = reader.fieldnames
            for row in reader:
                logging.info('Creating task for schema.table: %s%s%s', row['OWNER'], '.' ,row['SEGMENT_NAME'])
                sqltext1 = "BEGIN DBMS_PARALLEL_EXECUTE.CREATE_TASK (TASK_NAME => '" + row['OWNER'] + "." + row['SEGMENT_NAME'] +  "'); END;"
                logging.debug(sqltext1)
                cursor1.execute(sqltext1)
                sqltext2 = "select round(" + str(int(args.p_target_s3_chunk_mb)*1024*1024) + "/" + "nvl(avg_row_len,500),-1)  from dba_tables where owner='" + row['OWNER'] + "' and table_name='" + row['SEGMENT_NAME'] + "'"
                logging.debug(sqltext2)
                cursor2.execute(sqltext2)
                for dbrow in cursor2:
                    logging.info('Creating rowid chunks for schema.table: %s%s%s', row['OWNER'], '.' ,row['SEGMENT_NAME'])
                    sqltext3 = "BEGIN DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(TASK_NAME   => '" + row['OWNER'] + "." + row['SEGMENT_NAME'] + "'," \
                                      + "TABLE_OWNER => '" + row['OWNER'] + "',"  \
                                      + "TABLE_NAME  => '" + row['SEGMENT_NAME'] + "',"  \
                                      + "BY_ROW      => TRUE,"              \
                                      + "CHUNK_SIZE  => " + str(dbrow[0]) + ");"  \
                                      + " END;"
                    logging.debug(sqltext3)
                    cursor3.execute(sqltext3)

       
        
        # Populate Queue with all the chunks to process
        logging.info('Reading chunks from DBA_PARALLEL_EXECUTE_CHUNKS and updating python queue')
        cursor4.execute("SELECT CHUNK_ID, TASK_NAME, START_ROWID, END_ROWID FROM  DBA_PARALLEL_EXECUTE_CHUNKS ORDER BY CHUNK_ID")
        for dbrow in cursor4:
            task=str(dbrow[0]) + ":" + dbrow[1] + ":SELECT  * FROM " + dbrow[1] + " WHERE ROWID BETWEEN " + "CHARTOROWID('" + str(dbrow[2]) + "')" + " and " + "CHARTOROWID('" + str(dbrow[3]) + "')"
            jobs.put(task)
            
        # Create N threads
        logging.info('Creating threads')
        for i in range(int(args.p_parallel_threads)):
            threading.Thread(target=items_queue_worker).start()

        # Wait for all items to finish processing
        jobs.join()
        logging.info('Processed ETL scripts queue')
        
        # Drop Oracle parallel tasks
        with open(p_schema_table_config) as csv_file:
            csv.register_dialect('strip', skipinitialspace=True)
            reader = csv.DictReader(csv_file, dialect='strip')
            fieldnames = reader.fieldnames
            for row in reader:
                logging.info('Dropping task for schema.table: %s%s%s', row['OWNER'], '.' ,row['SEGMENT_NAME'])
                sqltext1 = "BEGIN DBMS_PARALLEL_EXECUTE.DROP_TASK(TASK_NAME => '" + row['OWNER'] + "." + row['SEGMENT_NAME'] +  "'); END;"
                logging.debug(sqltext1)
                cursor5.execute(sqltext1)

        # Close Oracle connection
        con.close()
        
        running = False
    except Exception as e:
        logging.error('Error: %s', e)
        sys.exit(1)

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
