import boto3, os, json

sfn = boto3.client('stepfunctions')
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']

def handler(event, context):
    for record in event['Records']:
        if record['eventName'] == 'INSERT':
            item = record['dynamodb']['NewImage']
            # You may want to extract fields more robustly for your input format.
            bucket = item['bucket']['S']
            s3Key = item['s3Key']['S']
            sfn.start_execution(
                stateMachineArn=STATE_MACHINE_ARN,
                input=json.dumps({"bucket": bucket, "s3Key": s3Key})
            )
