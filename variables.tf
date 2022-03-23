variable "website-domain-main" {
  description = "Main website domain, e.g. cloudmaniac.net"
  type        = string
}

variable "website-additional-domains" {
  description = "Main website additional domains (e.g., additional.cloudmaniac.net) that don't need redirection"
  type        = list(string)
  default = []
}

variable "website-domain-redirect" {
  description = "Secondary FQDN that will redirect to the main URL (e.g., www.cloudmaniac.net)"
  default     = null
  type        = string
}

variable "domains-zone-root" {
  description = "Root zone under which the domains should be registered"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags added to resources"
  default     = {}
  type        = map(string)
}

variable "support-spa" {
  description = "Support SPA (Single-Page Application) website with redirect to index.html"
  default = false
  type = bool
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
