# AWS Static Website Terraform Module

Terraform module which provision required AWS resources to host a performant and secured static website.

## Features

This Terraform module creates the following AWS resources:

* **AWS Certificate Manager**: wildcard certificate for your domain.
* **S3**
  * Bucket #1: to store logs.
  * Bucket #2: to store the content (`example.com`).
  * Bucket #3: to redirect a different subdomain to the main domain (e.g., `www.example.com` redirected to `example.com`).
* **CloudFront**
  * Distribution #1: to frontend the website.
  * Distribution #2: to frontend the subdomain that will be redirected to the main domain.
* **Route53** record sets pointing to the two CloudFront distributions.

## Requirements

* This module is meant for use with [Terraform](https://www.terraform.io/downloads.html) 0.12+. It has not been tested with previous versions of Terraform.
* An AWS account and your credentials (`aws_access_key_id` and `aws_secret_access_key`) configured. There are several ways to do this (environment variables, shared credentials file, etc.); more information in the [AWS Provider](https://www.terraform.io/docs/providers/aws/index.html) documentation.
* Your domain already configured as a hosted zone on Route53.

## Usage

```HCL
provider "aws" {
  region                  = "eu-west-3"
  shared_credentials_file = "~/.aws/credentials"
}

module "aws_static_website" {
  source = "cloudmaniac/static-website/aws"

  domains-zone-root       = "example.com"
  website-domain-main     = "example.com"
  website-domain-redirect = "www.example.com"
}
```

Although AWS services are available in many locations, some of them require the `us-east-1` (N. Virginia) region to be configured:

* To use an ACM certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region. ACM certificates in this region associated with a CloudFront distribution are distributed to all the geographic locations configured for that distribution.

For that reason, the module includes an aliased provider definition to create supplemental resources in the `us-east-1` region when required. Remaining resources from the module will inherit default (un-aliased) provider configurations from the parent.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
| domains-zone-root | Root zone under which the domain should be registered in Route 53 | string | - | yes |
| website-domain-main | Domain for the website (e.g., `example.com`) | string | - | yes |
| website-domain-redirect | Alternate subdomain to redirect to the main website (e.g., `www.example.com`) | string | - | yes |
| support-spa | Determine if website is SPA (Single-Page Application) to direct 404 response to index.html | bool | `false` | no |
| website-additional-domains | Main website additional domains (e.g., `noredir.example.com`) that don't need redirection | list(string) | [] | no |
| cloudfront_lambda_function_arn | ARN of optional AWS Lambda Function that can be associated with the CloudFront distribution to provide custom behaviour | string | - | no |
| cloudfront_lambda_function_event_type | The type of event that triggers the above Lambda Function ([documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#lambda_function_association)) | string | `origin-request` | no |

## Outputs

| Name | Description |
|------|-------------|
| website_cdn_root_id | CloudFront Distribution ID |

## Author

Module written by [@cloudmaniac](https://github.com/cloudmaniac).

Module Support: [terraform-aws-static-website](https://github.com/cloudmaniac/terraform-aws-static-website). Contributions and comments are welcomed.

## Additional Resources

* Blog post describing the thought process behind this: [My Wordpress to Hugo Migration #2 - Hosting](https://cloudmaniac.net/wordpress-to-hugo-migration-2-hosting/)

## Todo

* [ ] Tag all ressources
* [ ] Use versioning on S3 buckets instead of invalidation
* [ ] Secure S3 buckets
* [ ] Optional enhanced version with Lambda@Edge configuration and S3 endpoint (REST endpoint) used as the origin
* [ ] Add more outputs
