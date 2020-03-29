# AWS Static Website Terraform Module

![Terraform Version](https://img.shields.io/badge/tf-%3E%3D0.12.0-blue.svg)

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
  * Distribution #2: to frontend the subdomain that will be redirect to the main domain.
* **Lambda@Edge** (triggered by the CloudFront Distribution) to re-write requests so that CloudFront requests a default index object (e.g., index.html) for subfolders.
* **Route53** record sets pointing to the two CloudFront distributions.

## Requirements

* This module is meant for use with [Terraform](https://www.terraform.io/downloads.html) 0.12+. It has not been tested with previous versions of Terraform.
* An AWS account and your credentials (`aws_access_key_id` and `aws_secret_access_key`) configured. There are several ways to do this (environment variables, shared credentials file, etc.): my preference is to store them in a [credential file](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html). More information in the [AWS Provider](https://www.terraform.io/docs/providers/aws/index.html) documentation.
* Your domain already configured as a hosted zone on Route53.

## Usage

```HCL
provider "aws" {
  version                 = "~> 2.0"
  region                  = "eu-west-3"
  shared_credentials_file = "~/.aws/credentials"
}

module "aws_static_website" {
  source = "cloudmaniac/static-website/aws"

  website-domain-main     = "example.com"
  website-domain-redirect = "www.example.com"
}
```

Although AWS services are available in many locations, some of them require the `us-east-1` (N. Virginia) region to be configured:

* To use an ACM certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region. ACM certificates in this region that are associated with a CloudFront distribution are distributed to all the geographic locations configured for that distribution.
* Lambda@Edge functions can now be authored in US East (N. Virginia), and will be replicated globally for invocation in response to CloudFront events.

For those reasons, the module includes an aliased provider definition to create those resources in the `us-east-1` region. Remaining resources from the module will inherit default (un-aliased) provider configurations from the parent.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
| website-domain-main | Domain for the website (e.g., `example.com`) | string | - | yes |
| website-domain-redirect | Alternate subdomain to redirect to the main website (e.g., `www.example.com`) | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| website_cdn_root_id | CloudFront Distribution ID |
