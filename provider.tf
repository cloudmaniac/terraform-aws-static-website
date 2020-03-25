## Providers definition

# Default provider
provider "aws" {
  version                 = "~> 2.0"
  region                  = var.aws-region-default
  shared_credentials_file = "../.aws/credentials"
  profile                 = "romain"
}

# Additional provider specific to handle ACM in a CloudFront context
provider "aws" {
  alias                   = "us-east-1"
  version                 = "~> 2.0"
  region                  = "us-east-1"
  shared_credentials_file = "../.aws/credentials"
  profile                 = "romain"
}