
output "bucket_name" {
  value = aws_s3_bucket.file_bucket.bucket
}

output "incoming_files_table" {
  value = aws_dynamodb_table.incoming_files.name
}

output "processed_files_table" {
  value = aws_dynamodb_table.processed_files.name
}

output "step_function_arn" {
  value = aws_sfn_state_machine.file_pipeline.arn
}