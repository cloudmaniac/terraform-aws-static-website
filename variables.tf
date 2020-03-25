variable "aws-region-default" {
  description = "Default AWS region to build required resources"
  default     = "us-east-1"
}

variable "website-domain-main" {
  description = "Website domain"
}

variable "website-domain-redirect" {
  description = "Secondary FQDN that will redirect to the main URL."
  default     = null
}