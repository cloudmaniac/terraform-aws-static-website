variable "website-domain-main" {
  description = "Main website domain, e.g. cloudmaniac.net"
  type        = string
}

variable "website-domain-redirect" {
  description = "Secondary FQDN that will redirect to the main URL, e.g. www.cloudmaniac.net"
  default     = null
  type        = string
}

variable "tags" {
  description = "Tags added to resources"
  default     = {}
  type        = map(string)
}

variable "cloudfront_lambda_function_arn" {
  description = <<EOF
                The optional ARN of AWS Lambda Function that can be associated with the CloudFront
                distribution that can provide custom behaviour. For more information read:
                https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#lambda_function_association
                EOF
  default     = null
  type        = string
}

variable "cloudfront_lambda_function_event_type" {
  description = <<EOF
                The type of event that triggers the above Lambda Function. For possible types, see:
                https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#lambda_function_association
                EOF
  default     = "origin-request"
  type        = string
}
