output "bucket" {
  value = aws_s3_bucket.site.bucket
}

output "url" {
  value = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
