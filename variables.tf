variable "website-domain-main" {
  description = "Main website domain, e.g. cloudmaniac.net"
  type        = string
}

variable "website-domain-redirect" {
  description = "Secondary FQDN that will redirect to the main URL, e.g. www.cloudmaniac.net"
  default     = null
  type        = string
}

variable "domains-zone-root" {
  description = "root zone under which the domains should be registered"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags added to resources"
  default     = {}
  type        = map(string)
}

variable "support-spa" {
  description = "Support SPA website with redirect to index.html"
  default = false
  type = bool
}
