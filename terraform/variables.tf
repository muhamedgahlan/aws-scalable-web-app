variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "scalable-web-app"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "true = one NAT (cheap, for demo). false = one NAT per AZ (production HA)."
  type        = bool
  default     = true
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min" {
  type    = number
  default = 2
}

variable "asg_max" {
  type    = number
  default = 4
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm notifications (SNS)."
  type        = string
}

variable "restrict_alb_to_cloudfront" {
  description = "Only allow CloudFront IPs to reach the ALB."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Max requests per 5 minutes per IP before WAF blocks."
  type        = number
  default     = 2000
}

# ---- Optional custom domain (Route 53). Leave empty to skip. ----
variable "domain_name" {
  description = "e.g. app.example.com (optional)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate in us-east-1 for domain_name (required if domain_name is set)."
  type        = string
  default     = ""
}
