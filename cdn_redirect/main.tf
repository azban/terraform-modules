variable "redirect_to" {
  type = "string"
}

variable "redirect_from" {
  type = "list"
}

variable "dns_zone_id" {
  type = "string"
}

variable "cloudfront_ssl_certificate_arn" {
  type = "string"
}

resource "aws_s3_bucket" "main" {
  bucket = "${var.redirect_to}-redirects"
  acl = "public-read"
  website = {
    redirect_all_requests_to = "https://${var.redirect_to}"
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled = true
  aliases = ["${var.redirect_from}"]
  default_cache_behavior = {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.main.website_endpoint}"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400

    forwarded_values = {
      query_string = false

      cookies = {
        forward = "none"
      }
    }
  }
  origin = {
    domain_name = "${aws_s3_bucket.main.website_endpoint}"
    origin_id = "${aws_s3_bucket.main.website_endpoint}"
    custom_origin_config = {
      origin_protocol_policy = "http-only"
      http_port = 80

      # https://github.com/hashicorp/terraform/issues/10955
      https_port = 443
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }
  viewer_certificate = {
    acm_certificate_arn = "${var.cloudfront_ssl_certificate_arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
  restrictions = {
    geo_restriction = {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "main" {
  count = "${length(var.redirect_from)}"
  zone_id = "${var.dns_zone_id}"
  name = "${element(var.redirect_from, count.index)}"
  type = "A"
  alias = {
    name = "${aws_cloudfront_distribution.main.domain_name}"
    zone_id = "${aws_cloudfront_distribution.main.hosted_zone_id}"
    evaluate_target_health = true
  }
}
