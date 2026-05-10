data "aws_route53_zone" "main" {
  count        = var.create_dns_records ? 1 : 0
  provider     = aws.primary
  name         = var.domain_name
  private_zone = false
}

# --- HEALTH CHECK FOR PRIMARY ---
resource "aws_route53_health_check" "primary_health" {
  count             = var.create_dns_records ? 1 : 0
  provider          = aws.primary
  fqdn              = aws_lb.primary.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "primary-alb-health-check"
  }
}

# --- ROUTE 53 FAILOVER RECORDS ---
resource "aws_route53_record" "app_primary" {
  count    = var.create_dns_records ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.main[0].zone_id
  name     = "app.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary-active"
  health_check_id = aws_route53_health_check.primary_health[0].id

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_standby" {
  count    = var.create_dns_records ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.main[0].zone_id
  name     = "app.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "standby-inactive"

  alias {
    name                   = aws_lb.standby.dns_name
    zone_id                = aws_lb.standby.zone_id
    evaluate_target_health = true
  }
}
