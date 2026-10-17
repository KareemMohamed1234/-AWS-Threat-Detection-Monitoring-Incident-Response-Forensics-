-- Replace <LOG_BUCKET> and <ACCOUNT_ID>.
CREATE EXTERNAL TABLE IF NOT EXISTS ir_lab.cloudtrail_logs (
  eventversion STRING,
  useridentity STRUCT<
    type:STRING, principalid:STRING, arn:STRING, accountid:STRING, invokedby:STRING,
    accesskeyid:STRING, username:STRING,
    sessioncontext:STRUCT<
      attributes:STRUCT<mfaauthenticated:STRING, creationdate:STRING>,
      sessionissuer:STRUCT<type:STRING, principalid:STRING, arn:STRING, accountid:STRING, username:STRING>>>,
  eventtime STRING,
  eventsource STRING,
  eventname STRING,
  awsregion STRING,
  sourceipaddress STRING,
  useragent STRING,
  errorcode STRING,
  errormessage STRING,
  requestparameters STRING,
  responseelements STRING,
  additionaleventdata STRING,
  requestid STRING,
  eventid STRING,
  resources ARRAY<STRUCT<arn:STRING, accountid:STRING, type:STRING>>,
  eventtype STRING,
  apiversion STRING,
  readonly STRING,
  recipientaccountid STRING,
  serviceeventdetails STRING,
  sharedeventid STRING,
  vpcendpointid STRING
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://<LOG_BUCKET>/AWSLogs/<ACCOUNT_ID>/CloudTrail/';
