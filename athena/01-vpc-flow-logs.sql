-- Replace <LOG_BUCKET> and <ACCOUNT_ID>. Run in the Athena query editor.
CREATE DATABASE IF NOT EXISTS ir_lab;

CREATE EXTERNAL TABLE IF NOT EXISTS ir_lab.vpc_flow_logs (
  version int,
  account_id string,
  interface_id string,
  srcaddr string,
  dstaddr string,
  srcport int,
  dstport int,
  protocol bigint,
  packets bigint,
  bytes bigint,
  `start` bigint,
  `end` bigint,
  action string,
  log_status string
)
PARTITIONED BY (`date` string)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ' '
LOCATION 's3://<LOG_BUCKET>/AWSLogs/<ACCOUNT_ID>/vpcflowlogs/eu-north-1/'
TBLPROPERTIES (
  'skip.header.line.count'='1',
  'projection.enabled'='true',
  'projection.date.type'='date',
  'projection.date.format'='yyyy/MM/dd',
  'projection.date.range'='2026/01/01,NOW',
  'projection.date.interval'='1',
  'projection.date.interval.unit'='DAYS',
  'storage.location.template'='s3://<LOG_BUCKET>/AWSLogs/<ACCOUNT_ID>/vpcflowlogs/eu-north-1/${date}'
);
