#
# Purpose       : Unload Oracle tables data into S3. Script is meant to be used only for full load.
# Author        : Vishal Desai
# Change        : 8/28/2020 - MVC release
#
# Prereq        : 1 - Install python3
#                 2 - Install boto3, csv, argparse, sys, datetime, threading, cx_Oracle, os, logging, queue and subprocess python packages
#                 3 - Install awswrangler - https://pypi.org/project/awswrangler/
#                 4 - Install oracle instance client
#
# Assumptions   : 1 - Tables has latest stats or must be analyzed as code uses avg_row_len from dba_tables to determine rowid chunks
#
# Limitations   : 1 - Does not support CDC
#                 2 - All table columns are extracted.
#                 3 - Code is not tested for lob data types.
#
# Usage         : python3 unload_ora_to_s3.py \
#                    --p_schema_table_config oracle_schema_table.csv \
#                    --p_schema_table_lob_config oracle_schema_table_lob.csv \
#                    --p_username username \
#                    --p_oracle_host xx.xx.xx.xx \
#                    --p_service orcl \
#                    --p_port 1521 \
#                    --p_target_s3_bucket bucketname \
#                    --p_target_s3_chunk_mb 250 \
#                    --p_target_s3_compression snappy \
#                    --p_parallel_threads 32 \
#                    --p_child_code_file unload_ora_to_s3_sub.py \
#                    --p_child_code_lob_file unload_ora_to_s3_lob_sub.py \

import boto3
import os
import csv
import sys
import logging
import getpass
import argparse
import datetime
import threading
import cx_Oracle
from queue import Queue
import concurrent.futures
from subprocess import check_output


def get_args():
    """
    Uses argparse to get and set all the arguments for the script.
    """

    global p_username
    global p_oracle_host
    global p_service
    global p_port
    global p_schema_table_config
    global p_schema_table_lob_config
    global p_parallel_threads
    global p_target_s3_bucket
    global p_target_s3_lob_bucket
    global p_target_s3_chunk_mb
    global p_target_s3_compression
    global p_child_code_file
    global p_child_code_lob_file
    global logger

    parser = argparse.ArgumentParser(
        usage='%(prog)s <options>', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('--p_schema_table_config', required=True, type=str, help="Location for csv file containing schema table mapping.")
    parser.add_argument('--p_schema_table_lob_config', required=True, type=str, help="Location for csv file containing table lob metadata.")
    parser.add_argument('--p_username', required=True, help="Oracle database username to connect with." )
    parser.add_argument('--p_oracle_host', required=True, help="Oracle EC2 instance Public IP.")
    parser.add_argument('--p_service', required=True, help="Oracle service name.")
    parser.add_argument('--p_port', type=int, required=True, help="Oracle database listener port.")
    parser.add_argument('--p_target_s3_bucket', required=True, help="Target S3 bucket name.")
    parser.add_argument('--p_target_s3_lob_bucket', required=True, help="Target S3 lob bucket name.")
    parser.add_argument('--p_target_s3_chunk_mb', type=int, required=True, help="S3 file chunk size.")
    parser.add_argument('--p_target_s3_compression', type=str, default='snappy', choices=['snappy', 'gzip'], help="Parquet file compression type. Default: snappy")
    parser.add_argument('--p_parallel_threads', type=int, required=True, help="Number of parallel threads to read the Oracle table.")
    parser.add_argument('--p_child_code_file', required=True, help="Sub python code")
    parser.add_argument('--p_child_code_lob_file', required=True, help="Sub python code for lob")
    parser.add_argument('--p_verbose', default='info', choices=['info', 'debug'])

    options = parser.parse_args()

    p_schema_table_config = options.p_schema_table_config.strip()
    p_schema_table_lob_config = options.p_schema_table_lob_config.strip()
    p_username = options.p_username.strip()
    p_oracle_host = options.p_oracle_host.strip()
    p_service = options.p_service.strip()
    p_port = options.p_port
    p_target_s3_bucket = options.p_target_s3_bucket.strip().lower()
    p_target_s3_lob_bucket = options.p_target_s3_lob_bucket.strip().lower()
    p_target_s3_chunk_mb = options.p_target_s3_chunk_mb
    p_target_s3_compression = options.p_target_s3_compression.strip().lower()
    p_parallel_threads = options.p_parallel_threads
    p_child_code_file = options.p_child_code_file.strip()
    p_child_code_lob_file = options.p_child_code_lob_file.strip()
    log_mode = options.p_verbose.strip().lower()

    log_file_name = '/tmp/oracle_unload_lob_to_s3_' + (datetime.datetime.now()).strftime("%b_%d_%Y-%H_%M_%S") + '.log'
    logger = set_logging(log_mode, log_file_name)

    logger.info("Arguments specified..")
    for arg in vars(options):
        logger.info("Input value specified for {} is - {}".format(arg, getattr(options, arg)))


            
def set_logging(log_mode, log_file_name=None):
    """
    Enables logging.
    """

    logger = logging.getLogger(__name__)
    console = logging.StreamHandler()
    
    # set to debug or info
    if log_mode == 'debug':
        logger.setLevel(logging.DEBUG)
        console.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)
        console.setLevel(logging.INFO)
    formatter = logging.Formatter(
        '%(asctime)s - %(funcName)20s - %(levelname)s - %(message)s')
    console.setFormatter(formatter)
    # add the handlers to the logger
    logger.addHandler(console)
    if log_file_name:
        filehandler = logging.FileHandler(log_file_name)
        filehandler.setLevel(logging.INFO)
        filehandler.setFormatter(formatter)
        logger.addHandler(filehandler)

    return logger

def process_tasks(task):
    """
    :param task: task from DBA_PARALLEL_EXECUTE_CHUNKS
    :calls p_child_code_file script to write the data to S3 in parquet format
    """

    startTime = datetime.datetime.now()
    #task = task.split(":",2)
    table = task.split(":",2)[1].split(".")
    logger.info('Starting chunk %s for %s.%s', task.split(":")[0],table[0],table[1])
    s3path = "s3://" + p_target_s3_bucket + "/" +  table[0] + "/" + table[1] + "/" + "part" + task.split(":",2)[0] + "." + p_target_s3_compression + ".parquet"
    pythonscript = 'python3 ' + os.path.abspath(os.getcwd()) + '/' + p_child_code_file + ' "' + s3path + '" "' + \
        task.split(":",2)[2] + '" "' + p_username + '" "' + password + '" "' + p_oracle_host + '" "' + \
        p_service + '" "' + str(p_port) + '" "' + \
        p_target_s3_compression + '" &> /dev/null; echo $?'
    #logger.info(pythonscript)
    o = check_output(pythonscript, stderr=None, shell=True)

    if int(o.decode("utf-8")) == 0:
        logger.info('Finished chunk %s for %s.%s', task.split(":")[0],table[0],table[1])
    else:
        logger.error('Error processing chunk %s for %s.%s', task.split(":")[0],table[0],table[1])

def process_lob_tasks(task):
    """
    :param task: task from DBA_PARALLEL_EXECUTE_CHUNKS
    :calls p_child_code_file script to write the data to S3 in parquet format
    """

    startTime = datetime.datetime.now()
    table = task.split(":")[1].split(".")
    logger.info('Starting lob chunk %s for %s.%s column %s', task.split(":")[0],table[0],table[1], task.rsplit(":",3)[1])
    s3path = "test"

    pythonscript = 'python3 ' + os.path.abspath(os.getcwd()) + '/' + p_child_code_lob_file + ' "' + s3path + '" "' + \
        task.split(":")[2] + '" "' + p_username + '" "' + password + '" "' + p_oracle_host + '" "' + \
        p_service + '" "' + str(p_port) + '" "' + \
        p_target_s3_lob_bucket + '" "' + table[0] + '" "' + table[1] + '" "' + task.rsplit(":",3)[1] + '" "' + task.rsplit(":",2)[1] + '" "' + \
        task.rsplit(":",1)[1] + '" &> /dev/null; echo $?'
    #logger.info(pythonscript)
    o = check_output(pythonscript, stderr=None, shell=True)

    if int(o.decode("utf-8")) == 0:
        logger.info('Finished lob chunk %s for %s.%s column %s', task.split(":")[0],table[0],table[1],task.rsplit(":",3)[1])
    else:
        logger.error('Error processing lob chunk %s for %s.%s column %s', task.split(":")[0],table[0],table[1],task.rsplit(":",3)[1])


def get_result(conn, sql, result=False):
    """
    :param conn: oracle database connection
    :param sql: sql to be executed
    :param result: True if return result else False
    :return: If result parameter is true then returns result else pass
    """

    dbcursor = conn.cursor()
    if dbcursor:
        try:
            dbcursor.execute(sql)
            if result:
                result = dbcursor.fetchall()
                return result
        except Exception as x:
            logger.error("Received error in get_result function -- {}".format(str(x)))
        finally:
            try:
                dbcursor.close()
            except:
                pass
    else:
        pass

def main():


    global password

    #Global Variables
    #USER = {}
    task_list = []
    all_chunks = []
    lob_chunks = []

    # Initialize the input arguments
    get_args()

    #prompt for oracle user password
    userid = p_username
    password = getpass.getpass("\nEnter password for %s        : " % (userid))
    #USER[userid] = password

    # Create Oracle Database connection and cursors
    logger.info('Establish Oracle Connection')
    ora_conn = cx_Oracle.connect(user=p_username, password=password, dsn=p_oracle_host+"/"+p_service+":"+str(p_port))

    # read the schema table csv file
    schema_table_config = os.path.abspath(os.getcwd()) + '/' + p_schema_table_config
    logger.info('Process list of Schema/Table from input csv config file')
    with open(schema_table_config) as csv_file:
        csv.register_dialect('strip', skipinitialspace=True)
        reader = csv.DictReader(csv_file, dialect='strip')
        #for each schema,table in csv file create the parallel_execute task and chunks by rowid
        for row in reader:
            owner = row['OWNER'].strip()
            segment_name = row['SEGMENT_NAME'].strip()

            #create task with DBMS_PARALLEL_EXECUTE. This package allows a workload associated with a base table to be broken down into smaller chunks which can be run in parallel.
            logger.info('Creating task for schema.table: %s%s%s', owner, '.' ,segment_name)
            #get the task name
            task_name = owner + "." + segment_name
            #verify if task already exists. If not then create the tasks, else exit the script.
            check_task_sql = "SELECT count(*) FROM dba_parallel_execute_tasks WHERE task_name = '%s'" % (task_name)
            logger.info("Executing SQL to verify for pre-existing task name: %s" % (task_name))
            check_task_exists = get_result(
                conn=ora_conn, sql=check_task_sql, result=True)
            if check_task_exists[0][0] == 0:
                #create the task
                logger.info("No pre-exisitng task found, creating a new task.")
                create_task_sql = "BEGIN DBMS_PARALLEL_EXECUTE.CREATE_TASK (TASK_NAME => '%s'); END;" % (task_name)
                #logger.info("Executing - %s" % (sqltext1))
                get_result(conn=ora_conn, sql=create_task_sql)
                #verify if the task was created
                created_task_check_sql = "SELECT count(*) FROM dba_parallel_execute_tasks WHERE task_name='%s' and status='CREATED'" % (task_name)
                check_task_created = get_result(
                    conn=ora_conn, sql=created_task_check_sql, result=True)
                if check_task_created[0][0] == 1:
                    logger.info("New task %s created successfully" % (task_name))
                else:
                    logger.error("Unable to create new %s task , exiting..." % (task_name))
                    sys.exit(1)
                #append task name with owner and segment_name to task_list
                task_list.append({'owner': owner,
                                    'segment_name':segment_name, 'task_name': task_name})
                #calculate average row length
                avg_row_length_sql = "SELECT round(" + str((p_target_s3_chunk_mb)*1024*1024) + "/" + "nvl(avg_row_len,500),-1) FROM dba_tables where owner='%s' and table_name='%s'" % (owner, segment_name)
                #logger.info("Executing - %s" % (sqltext2))
                arl_resp = get_result(
                    conn=ora_conn, sql=avg_row_length_sql, result=True)
                #create chunks by rowid using DBMS_PARALLEL_EXECUTE based on avg_row_length
                logger.info('Creating rowid chunks for schema.table: %s%s%s', owner, '.' ,segment_name)
                create_chunk_sql = "BEGIN DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(TASK_NAME   => '" + owner + "." + segment_name + "'," \
                                    + "TABLE_OWNER => '" + owner + "',"  \
                                    + "TABLE_NAME  => '" + segment_name + "',"  \
                                    + "BY_ROW      => TRUE,"              \
                                    + "CHUNK_SIZE  => " + str(arl_resp[0][0]) + ");"  \
                                    + " END;"
                #logger.info("Executing - %s" % (create_chunk_sql))
                get_result(
                    conn=ora_conn, sql=create_chunk_sql, result=False)
            else:
                logger.error("Pre-exisitng task %s found.Clean up before re-running the script." % (task_name))
                sys.exit(1)

        # Populate Queue with all the chunks to process
        logger.info('Reading chunks from DBA_PARALLEL_EXECUTE_CHUNKS to execute task in parallel.')
        query_chunks = "SELECT chunk_id, task_name, start_rowid, end_rowid FROM dba_parallel_execute_chunks order by chunk_id"
        chunks_resp = get_result(
            conn=ora_conn, sql=query_chunks, result=True)
            

        for dbrow in chunks_resp:
            query_cols = " select  column_name,data_type " \
                          + " from dba_tab_cols where owner='"  + dbrow[1].split('.')[0] + "' and table_name='" + dbrow[1].split('.')[1] + "' order by column_id";
            #logger.info("query_cols - %s" % (query_cols) )
            table_cols = get_result(
                conn=ora_conn, sql=query_cols, result=True)
                
            alldbcols = ''
            for tablecols in table_cols:
                if tablecols[1] == 'CLOB' or tablecols[1] == 'BLOB':
                    schema_table_lob_config = os.path.abspath(os.getcwd()) + '/' + p_schema_table_lob_config
                    with open(schema_table_lob_config) as csv_lob_file:
                        csv.register_dialect('strip', skipinitialspace=True)
                        lobreader = csv.DictReader(csv_lob_file, dialect='strip')
                        
                        for lobrow in lobreader:

                            owner = row['OWNER'].strip()
                            segment_name = row['SEGMENT_NAME'].strip()
                            if owner == lobrow['OWNER'].strip() and  segment_name == lobrow['SEGMENT_NAME'].strip() and lobrow['LOB_COLUMN'].strip() == tablecols[0]:
                                alldbcols = alldbcols + "case when dbms_lob.getlength(" + lobrow['LOB_COLUMN'].strip() + ")>0 then " + "'https://" + p_target_s3_lob_bucket + "/" + owner + "/" + segment_name + "/" + lobrow['LOB_COLUMN'].strip() + "/'" + "||" + lobrow['S3_FILENAME_PREFIX'].strip() + " || '." + lobrow['S3_FILENAME_EXT'].strip() + "' else NULL end as " + lobrow['LOB_COLUMN'].strip() + ','
                                lobtask=str(dbrow[0]) + ":" + dbrow[1] + ":SELECT  rowid FROM " + dbrow[1] + " WHERE ROWID BETWEEN " + "CHARTOROWID('" + str(dbrow[2]) + "')" + " and " + "CHARTOROWID('" + str(dbrow[3]) + "')" + ":" + lobrow['LOB_COLUMN'].strip() + ":" + lobrow['S3_FILENAME_PREFIX'].strip() + ":" + lobrow['S3_FILENAME_EXT'].strip()
                                lob_chunks.append(lobtask)
                    
                else:
                    alldbcols = alldbcols + tablecols[0] + ','

                
            alldbcols = alldbcols[::-1].replace(','[::-1], '', 1)[::-1]  
            #logger.info(alldbcols)
            task=str(dbrow[0]) + ":" + dbrow[1] + ":SELECT  " + alldbcols + " FROM " + dbrow[1] + " WHERE ROWID BETWEEN " + "CHARTOROWID('" + str(dbrow[2]) + "')" + " and " + "CHARTOROWID('" + str(dbrow[3]) + "')" 
            all_chunks.append(task)
                   

        with concurrent.futures.ThreadPoolExecutor(max_workers=p_parallel_threads) as executor:
            executor.map(process_tasks, all_chunks)

        logger.info('Processed table data queue')

        with concurrent.futures.ThreadPoolExecutor(max_workers=p_parallel_threads) as executor:
            executor.map(process_lob_tasks, lob_chunks)

        logger.info('Processed table LOB data queue')       

        # Drop Oracle parallel tasks
        for row in task_list:
            logger.info("Dropping the tasks %s" % (row['task_name']))
            drop_task = "BEGIN DBMS_PARALLEL_EXECUTE.DROP_TASK(TASK_NAME => '%s'); END;" % (row['task_name'])
            get_result(conn=ora_conn, sql=drop_task)
            task_drop_verification = "SELECT count(*) FROM dba_parallel_execute_tasks WHERE task_name='%s'" % (row['task_name'])
            task_dropped = get_result(conn=ora_conn, sql=task_drop_verification, result=True)
            if task_dropped[0][0] == 0:
                logger.info("Task %s is dropped successfully" % (row['task_name']))
            else:
                logger.warning("Failed to drop task %s. Kindly cleanup manually, using DBMS_PARALLEL_EXECUTE.drop_task" % (row['task_name']))

        # Close Oracle connection
        ora_conn.close()

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        logger.error(str(e))
        sys.exit(1)