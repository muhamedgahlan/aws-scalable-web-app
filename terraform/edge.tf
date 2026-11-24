# ---------- S3 bucket for static assets ----------
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "static" {
  bucket        = "${var.project_name}-static-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "logo" {
  bucket       = aws_s3_bucket.static.id
  key          = "static/logo.svg"
  content_type = "image/svg+xml"
  content      = <<-SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <circle cx="50" cy="50" r="45" fill="#FF9900"/>
      <text x="50" y="62" font-size="36" text-anchor="middle" fill="#232F3E" font-family="sans-serif">AWS</text>
    </svg>
  SVG
}

# ---------- CloudFront ----------
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  use_domain = var.domain_name != "" && var.acm_certificate_arn != ""
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = "${var.project_name} CDN"
  aliases = local.use_domain ? [var.domain_name] : []

  origin {
    origin_id   = "alb"
    domain_name = aws_lb.app.dns_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    origin_id                = "s3-static"
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Dynamic content -> ALB (managed policies: CachingDisabled + AllViewer)
  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  # Static assets -> S3 (managed policy: CachingOptimized)
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "s3-static"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = local.use_domain ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }

  dynamic "viewer_certificate" {
    for_each = local.use_domain ? [1] : []
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }
}

data "aws_iam_policy_document" "static" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.static.json
}

# ---------- Route 53 (optional, only if a domain is provided) ----------
resource "aws_route53_record" "alias" {
  count   = local.use_domain ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_health_check" "site" {
  count             = local.use_domain ? 1 : 0
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}
