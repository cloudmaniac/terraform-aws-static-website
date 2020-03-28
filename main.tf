## Providers definition
# Default provider will be inherited from the enclosing configuration.

# The provider below is required to handle ACM and Lambda in a CloudFront context
provider "aws" {
  alias                   = "us-east-1"
  version                 = "~> 2.0"
  region                  = "us-east-1"
  shared_credentials_file = "../.aws/credentials"
  profile                 = "romain"
}

## Route 53
# Provides details about the zone
data "aws_route53_zone" "main" {
  name         = var.website-domain-main
  private_zone = false
}

## ACM (AWS Certificate Manager)
# Creates the wildcard certificate *.<yourdomain.com>
resource "aws_acm_certificate" "wildcard_website" {
  provider = aws.us-east-1 # Wilcard certificate used by CloudFront requires this specific region (https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html)

  domain_name               = var.website-domain-main
  subject_alternative_names = ["*.${var.website-domain-main}"]
  validation_method         = "DNS"

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Validates the ACM wildcard by creating a Route53 record (as `validation_method` is set to `DNS` in the aws_acm_certificate resource)
resource "aws_route53_record" "wildcard_validation" {
  name    = aws_acm_certificate.wildcard_website.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.wildcard_website.domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.main.zone_id
  records = [aws_acm_certificate.wildcard_website.domain_validation_options[0].resource_record_value]
  ttl     = "60"
}

# Triggers the ACM wildcard certificate validation event
resource "aws_acm_certificate_validation" "wildcard_cert" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.wildcard_website.arn
  validation_record_fqdns = [aws_route53_record.wildcard_validation.fqdn]
}


# Get the ARN of the issued certificate
data "aws_acm_certificate" "wildcard_website" {
  provider = aws.us-east-1

  depends_on = [
    aws_acm_certificate.wildcard_website,
    aws_route53_record.wildcard_validation,
    aws_acm_certificate_validation.wildcard_cert,
  ]

  domain      = var.website-domain-main
  statuses    = ["ISSUED"]
  most_recent = true
}

## S3
# Creates bucket to store logs
resource "aws_s3_bucket" "website_logs" {
  bucket = "${var.website-domain-main}-logs"
  acl    = "log-delivery-write"

  # Comment the following line if you are uncomfortable with Terraform destroying the bucket even if this one is not empty 
  force_destroy = true

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Creates bucket to store the static website
resource "aws_s3_bucket" "website_root" {
  bucket = "${var.website-domain-main}-root"

  # Comment the following line if you are uncomfortable with Terraform destroying the bucket even if not empty 
  force_destroy = true

  logging {
    target_bucket = aws_s3_bucket.website_logs.bucket
    target_prefix = "${var.website-domain-main}/"
  }

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Creates bucket for the website handling the redirection (if required), e.g. from https://www.example.com to https://example.com
resource "aws_s3_bucket" "website_redirect" {
  bucket        = "${var.website-domain-main}-redirect"
  force_destroy = true

  logging {
    target_bucket = aws_s3_bucket.website_logs.bucket
    target_prefix = "${var.website-domain-main}-redirect/"
  }

  website {
    redirect_all_requests_to = "https://${var.website-domain-main}"
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

## CloudFront
# Creates an Amazon CloudFront origin access identity (will be used in the distribution origin configuration)
resource "aws_cloudfront_origin_access_identity" "origin_access_identity_website" {
  comment = "CloudfrontOriginAccessIdentity - ${var.website-domain-main}"
}

# Creates the CloudFront distribution to serve the static website
resource "aws_cloudfront_distribution" "website_cdn_root" {
  enabled     = true
  price_class = "PriceClass_All" # Select the correct PriceClass depending on who the CDN is supposed to serve (https://docs.aws.amazon.com/AmazonCloudFront/ladev/DeveloperGuide/PriceClass.html)
  aliases     = [var.website-domain-main]

  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.website_root.id}"
    domain_name = "${var.website-domain-main}-root.s3.${var.aws-region-default}.amazonaws.com"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity_website.cloudfront_access_identity_path
    }
  }

  default_root_object = "index.html"

  logging_config {
    bucket = aws_s3_bucket.website_logs.bucket_domain_name
    prefix = "${var.website-domain-main}/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.website_root.id}"
    min_ttl          = "0"
    default_ttl      = "300"
    max_ttl          = "1200"

    viewer_protocol_policy = "redirect-to-https" # Redirects any HTTP request to HTTPS
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "origin-request" # To use the url redirection Lambda@Edge, the trigger must be defined for the origin-request event
      lambda_arn = aws_lambda_function.website_lambda_redirect_folder_index.qualified_arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.wildcard_website.arn
    ssl_support_method  = "sni-only"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_page_path    = "/404.html"
    response_code         = 404
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [
      tags,
      viewer_certificate,
    ]
  }
}

# Creates the DNS record to point on the main CloudFront distribution ID
resource "aws_route53_record" "website_cdn_root_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.website-domain-main
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_cdn_root.domain_name
    zone_id                = aws_cloudfront_distribution.website_cdn_root.hosted_zone_id
    evaluate_target_health = false
  }
}


# Creates policy to limit access to the S3 bucket to CloudFront Origin
resource "aws_s3_bucket_policy" "update_website_root_bucket_policy" {
  bucket = aws_s3_bucket.website_root.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "PolicyForCloudFrontPrivateContent",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOriginAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_cloudfront_origin_access_identity.origin_access_identity_website.iam_arn}"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.website_root.arn}/*",
        "${aws_s3_bucket.website_root.arn}"
      ]
    }
  ]
}
POLICY
}

# Creates the CloudFront distribution to serve the redirection website (if redirection is required)
resource "aws_cloudfront_distribution" "website_cdn_redirect" {
  enabled     = true
  price_class = "PriceClass_All" # Select the correct PriceClass depending on who the CDN is supposed to serve (https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html)
  aliases     = [var.website-domain-redirect]

  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.website_redirect.id}"
    domain_name = "${var.website-domain-main}-redirect.s3.${var.aws-region-default}.amazonaws.com"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity_website.cloudfront_access_identity_path
    }
  }

  default_root_object = "index.html"

  logging_config {
    bucket = aws_s3_bucket.website_logs.bucket_domain_name
    prefix = "${var.website-domain-redirect}/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.website_redirect.id}"
    min_ttl          = "0"
    default_ttl      = "300"
    max_ttl          = "1200"

    viewer_protocol_policy = "redirect-to-https" # Redirects any HTTP request to HTTPS
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.wildcard_website.arn
    ssl_support_method  = "sni-only"
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [
      tags,
      viewer_certificate,
    ]
  }
}

# Creates the DNS record to point on the CloudFront distribution ID that handles the redirection website
resource "aws_route53_record" "website_cdn_redirect_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.website-domain-redirect
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_cdn_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.website_cdn_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

## Lambda
# Generates IAM policy in JSON format for the IAM role that will be attached to the Lambda Function
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

# Create the IAM role that will be attached to the Lambda Function and associate it with the previously created policy
resource "aws_iam_role" "lambda_exec_role_cloudfront_redirect" {
  name = "LambdaExecRoleCloudFrontRedirect"
  path = "/services-roles/"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Attach the predefined AWSLambdaBasicExecutionRole to grant permission to the Lambda execution role to see the CloudWatch logs generated when CloudFront triggers the function.
resource "aws_iam_role_policy_attachment" "lambda_exec_role_cloudwatch_policy" {
  role       = aws_iam_role.lambda_exec_role_cloudfront_redirect.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Generates a ZIP archive from the Javascript script
data "archive_file" "cloudfront_folder_index_redirect_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/cloudfront_folder_index_redirect.js"
  output_path = "${path.module}/lambda/cloudfront_folder_index_redirect.js.zip"
}

# Creates the Lambda Function
resource "aws_lambda_function" "website_lambda_redirect_folder_index" {
  provider         = aws.us-east-1 # Lambda@Edge invoked by CloudFront must reside in us-east-1
  function_name    = "cloudfront-folder-index-redirect"
  description      = "Implements Default Directory Indexes in Amazon S3-backed Amazon CloudFront Origins"
  handler          = "cloudfront_folder_index_redirect.handler"
  filename         = data.archive_file.cloudfront_folder_index_redirect_code.output_path
  source_code_hash = data.archive_file.cloudfront_folder_index_redirect_code.output_base64sha256
  role             = aws_iam_role.lambda_exec_role_cloudfront_redirect.arn
  runtime          = "nodejs10.x"
  timeout          = "30" # 30 seconds is the MAXIMUM allowed for functions triggered by a CloudFront event
  publish          = true

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Please note that `terraform destroy` may fail as it is not possible to delete a Lambda replicated function. If that's the case, the error message will be similar to:
# Error: Error deleting Lambda Function: InvalidParameterValueException: Lambda was unable to delete arn:aws:lambda:us-east-1:<redacted>:function:cloudfront-folder-index-redirect:4 because it is a replicated function. Please see our documentation for Deleting Lambda@Edge Functions and Replicas.
# { Message_: "Lambda was unable to delete arn:aws:lambda:us-east-1:<redacted>:function:cloudfront-folder-index-redirect:4 because it is a replicated function. Please see our documentation for Deleting Lambda@Edge Functions and Replicas."}

# The function will be automatically deleted a few hours after you have removed the last association for the function from all of your CloudFront distributions
# Documentation: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-delete-replicas.html