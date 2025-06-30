provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket
resource "aws_s3_bucket" "file_bucket" {
  bucket = "file-processing-bucket-${random_id.suffix.hex}"
  force_destroy = true
}

# DynamoDB: Incoming (triggers), and processed (results)
resource "aws_dynamodb_table" "incoming_files" {
  name           = "IncomingFiles"
  hash_key       = "pk"
  billing_mode   = "PAY_PER_REQUEST"
  attribute {
    name = "pk"
    type = "S"
  }
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

resource "aws_dynamodb_table" "processed_files" {
  name           = "ProcessedFiles"
  hash_key       = "pk"
  billing_mode   = "PAY_PER_REQUEST"
  attribute {
    name = "pk"
    type = "S"
  }
}

# Lambda Layers (point to your zipped output)
resource "aws_lambda_layer_version" "opencv" {
  layer_name          = "opencv"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/opencv.zip"
}

resource "aws_lambda_layer_version" "numpy" {
  layer_name          = "numpy"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/numpy.zip"
}

resource "aws_lambda_layer_version" "image_ocr" {
  layer_name          = "image_ocr"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/image_ocr.zip"
}

resource "aws_lambda_layer_version" "pymupdf" {
  layer_name          = "pymupdf"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/pymupdf.zip"
}

resource "aws_lambda_layer_version" "textract" {
  layer_name          = "textract"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/textract.zip"
}

resource "aws_lambda_layer_version" "utils_web" {
  layer_name          = "utils_web"
  compatible_runtimes = ["python3.12"]
  filename            = "${path.module}/layers/utils_web.zip"
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

# Attach policies for S3, DynamoDB, CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_ddb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Archive/zip each lambda function
data "archive_file" "convert_to_image_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/convert_to_image"
  output_path = "${path.module}/lambdas/convert_to_image.zip"
}
data "archive_file" "qr_scanner_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/qr_scanner"
  output_path = "${path.module}/lambdas/qr_scanner.zip"
}
data "archive_file" "ocr_text_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/ocr_text"
  output_path = "${path.module}/lambdas/ocr_text.zip"
}
data "archive_file" "validate_write_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/validate_write"
  output_path = "${path.module}/lambdas/validate_write.zip"
}
data "archive_file" "starter_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/starter"
  output_path = "${path.module}/lambdas/starter.zip"
}

# Lambda functions with correct layers
resource "aws_lambda_function" "convert_to_image" {
  function_name = "convert_to_image"
  filename      = data.archive_file.convert_to_image_lambda.output_path
  handler       = "app.handler"
  runtime       = "python3.12"
  source_code_hash = data.archive_file.convert_to_image_lambda.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  layers        = [
    aws_lambda_layer_version.pymupdf.arn,
    aws_lambda_layer_version.opencv.arn,
    aws_lambda_layer_version.numpy.arn
  ]
  environment {
    variables = {
      BUCKET = aws_s3_bucket.file_bucket.bucket
    }
  }
  timeout = 60
  memory_size = 1024
}

resource "aws_lambda_function" "qr_scanner" {
  function_name = "qr_scanner"
  filename      = data.archive_file.qr_scanner_lambda.output_path
  handler       = "app.handler"
  runtime       = "python3.12"
  source_code_hash = data.archive_file.qr_scanner_lambda.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  layers        = [
    aws_lambda_layer_version.opencv.arn,
    aws_lambda_layer_version.numpy.arn,
    aws_lambda_layer_version.image_ocr.arn
  ]
  environment {
    variables = {
      BUCKET = aws_s3_bucket.file_bucket.bucket
    }
  }
  timeout = 60
  memory_size = 1024
}

resource "aws_lambda_function" "ocr_text" {
  function_name = "ocr_text"
  filename      = data.archive_file.ocr_text_lambda.output_path
  handler       = "app.handler"
  runtime       = "python3.12"
  source_code_hash = data.archive_file.ocr_text_lambda.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  layers        = [
    aws_lambda_layer_version.opencv.arn,
    aws_lambda_layer_version.numpy.arn,
    aws_lambda_layer_version.image_ocr.arn
  ]
  environment {
    variables = {
      BUCKET = aws_s3_bucket.file_bucket.bucket
    }
  }
  timeout = 60
  memory_size = 1024
}

resource "aws_lambda_function" "validate_write" {
  function_name = "validate_write"
  filename      = data.archive_file.validate_write_lambda.output_path
  handler       = "app.handler"
  runtime       = "python3.12"
  source_code_hash = data.archive_file.validate_write_lambda.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  layers        = [
    aws_lambda_layer_version.utils_web.arn
  ]
  environment {
    variables = {
      PROCESSED_TABLE = aws_dynamodb_table.processed_files.name
    }
  }
  timeout = 60
  memory_size = 1024
}

# --- Step Functions role and definition ---
resource "aws_iam_role" "sfn_exec" {
  name = "sfn_exec_role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sfn_invoke_lambdas" {
  name = "SFNInvokeLambdas-${random_id.suffix.hex}"
  role = aws_iam_role.sfn_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          aws_lambda_function.convert_to_image.arn,
          aws_lambda_function.qr_scanner.arn,
          aws_lambda_function.ocr_text.arn,
          aws_lambda_function.validate_write.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = [
          aws_dynamodb_table.processed_files.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.file_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Step Function ASL definition
data "local_file" "sfn_definition" {
  filename = "${path.module}/infra/step_function.asl.json"
}

resource "aws_sfn_state_machine" "file_pipeline" {
  name     = "FileProcessingPipeline-${random_id.suffix.hex}"
  role_arn = aws_iam_role.sfn_exec.arn
  definition = data.local_file.sfn_definition.content
}

# --- "Starter" Lambda for DynamoDB stream -> Step Functions trigger ---
resource "aws_lambda_function" "starter" {
  function_name = "starter_trigger_lambda"
  filename      = data.archive_file.starter_lambda.output_path
  handler       = "app.handler"
  runtime       = "python3.12"
  source_code_hash = data.archive_file.starter_lambda.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.file_pipeline.arn
    }
  }
  timeout = 30
  memory_size = 256
}

resource "aws_lambda_event_source_mapping" "ddb_stream_to_starter" {
  event_source_arn = aws_dynamodb_table.incoming_files.stream_arn
  function_name    = aws_lambda_function.starter.arn
  starting_position = "TRIM_HORIZON"
  batch_size = 1
}
