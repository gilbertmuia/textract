import boto3

# ---- Configuration ----
file_path = "invoice.pdf"          # Local path to your file
bucket = "file-processing-bucket-bdabf31a"
s3_key = "uploads/invoice.pdf"

table_name = "IncomingFiles"
pk = s3_key                        # DynamoDB primary key

# ---- Upload to S3 ----
s3 = boto3.client("s3")
print(f"Uploading {file_path} to s3://{bucket}/{s3_key}...")
s3.upload_file(file_path, bucket, s3_key)
print("Upload complete.")

# ---- Insert to DynamoDB ----
dynamodb = boto3.client("dynamodb", region_name="us-east-1")  # Adjust region as needed
item = {
    "pk": {"S": pk},
    "bucket": {"S": bucket},
    "s3Key": {"S": s3_key}
}
print(f"Inserting trigger record into DynamoDB table {table_name}...")
dynamodb.put_item(
    TableName=table_name,
    Item=item
)
print("Done. Your Step Function pipeline should now trigger!")
