output "instance_id" {
  value = aws_instance.valheim.id
}

output "bucket_id" {
  value = aws_s3_bucket.valheim.id
}