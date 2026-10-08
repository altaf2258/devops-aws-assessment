output "app_bucket_name" { value = aws_s3_bucket.app.id }
output "app_bucket_arn" { value = aws_s3_bucket.app.arn }
output "logs_bucket_name" { value = aws_s3_bucket.logs.id }
output "logs_bucket_arn" { value = aws_s3_bucket.logs.arn }
output "logs_prefix" { value = local.logs_prefix }
