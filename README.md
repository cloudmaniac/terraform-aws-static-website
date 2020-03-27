# AWS Static Website Terraform Module

![Terraform Version](https://img.shields.io/badge/tf-%3E%3D0.12.0-blue.svg)

Terraform module which provision required AWS resources to host a performant and secured static website.

## Features

This Terraform module will create the following AWS resources:

* **AWS Certificate Manager** to create a wildcard certificate for your domain.
* **S3**
  * One bucket to store static public files.
  * One bucket to redirect a different subdomain to the main domain.
  * One bucket to store access logs.
* **CloudFront**
  * One distribution to frontend the website.
  * One distribution to frontend the sub-domain that will be redirect to the main domain.
* **Lambda@Edge** (triggered by the CloudFront Distribution) to re-write requests so that CloudFront requests a default index object (e.g., index.html) for subfolders.
* **Route53** record sets pointing to the CloudFront distributions.

## Requirements

* This module is meant for use with [Terraform](https://www.terraform.io/downloads.html) 0.12+. It has not been tested with previous versions of Terraform.
* An AWS account and your credentials (`aws_access_key_id` and `aws_secret_access_key`) stored in a [credential file](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
* Your domain already configured as a hosted zone on Route53.

## Usage

```HCL
module "aws_static_website" {
  source = "cloudmaniac/static-website/aws"

  aws-region-default      = "eu-west-3"
  website-domain-main     = "cluster.net"
  website-domain-redirect = "www.cluster.net"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
| aws-region-default | Default region  | string | us-east-1 | no |
| website-domain-main | Domain for the website (e.g., `example.com`) | string | - | yes |
| website-domain-redirect | Domain to redirect to the main website (e.g., `www.example.com`) | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| website_cdn_root_id | CloudFront Distribution ID |
