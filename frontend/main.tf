# deploy an S3 static website - main bucket (without www)
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "My bucket for Resume"
    Environment = "Dev"
  }
}

# www bucket that will redirect to the main bucket
resource "aws_s3_bucket" "www_bucket" {
  bucket = "www.${var.bucket_name}"

  tags = {
    Name        = "WWW Redirect Bucket"
    Environment = "Dev"
  }
}


# Origin Access Control for CloudFront
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy for CloudFront access only
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main_distribution.arn
          }
        }
      }
    ]
  })
}

# Upload Index.html to the website
resource "aws_s3_object" "index_upload" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "index.html"
  source = "dist/index.html"
  content_type = "text/html"
}
# Upload style.css to the website
resource "aws_s3_object" "css_upload" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "style.css"
  source = "dist/style.css"
  content_type = "text/css"
}
# upload script.js to the website
resource "aws_s3_object" "js_upload" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "script.js"
  source = "dist/script.js"
  content_type = "application/javascript"
}
# upload a bunch of images to s3 under images folder
resource "aws_s3_object" "images_upload" {
  for_each = fileset("dist/images", "*")
  bucket = aws_s3_bucket.website_bucket.id
  key    = "images/${each.value}"
  source = "dist/images/${each.value}"
  content_type = "image/png"
}

# Import Hosted Zone
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# ACM Certificate for the domain name and its alternatives (in us-east-1 for CloudFront)
resource "aws_acm_certificate" "website_certificate" {
  provider      = aws.acm_provider
  domain_name   = var.domain_name
  validation_method = "DNS"
  subject_alternative_names = [
    # "*.${var.domain_name}",
    "www.${var.domain_name}"
  ]
  tags = {
    Name = "Website Certificate"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Import Resource for Route53 into this block
resource "aws_route53_record" "website_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  name            = each.value.name
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Certificate validation
resource "aws_acm_certificate_validation" "website_cert_validation" {
  provider                = aws.acm_provider
  certificate_arn         = aws_acm_certificate.website_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.website_cert_validation : record.fqdn]

  timeouts {
    create = "30m"
  }
}

# Main CloudFront Distribution
resource "aws_cloudfront_distribution" "main_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "S3-${var.bucket_name}"
  }

  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.website_cert_validation.certificate_arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "Main Distribution"
  }
}

# WWW CloudFront Distribution
resource "aws_cloudfront_distribution" "www_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "S3-www-${var.bucket_name}"
  }

  enabled             = true
  default_root_object = "index.html"
  aliases             = ["www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-www-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.website_cert_validation.certificate_arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "WWW Distribution"
  }
}

# Route53 A record for main domain
resource "aws_route53_record" "main_domain" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.main_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 A record for www subdomain
resource "aws_route53_record" "www_domain" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

