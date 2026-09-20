resource "aws_lb" "api" {
  name               = "arcamap-api"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "ipv4"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  idle_timeout      = 60
  client_keep_alive = 3600
  enable_http2      = true
}

resource "aws_lb_target_group" "api" {
  vpc_id           = var.vpc_id
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 8080
  protocol_version = "HTTP1"

  load_balancing_algorithm_type     = "round_robin"
  load_balancing_cross_zone_enabled = "use_load_balancer_configuration"
  slow_start                        = 0
  deregistration_delay              = 300

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "api_http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "api_https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_cloudwatch_log_delivery_source" "alb" {
  for_each = {
    access       = "ALB_ACCESS_LOGS"
    connection   = "ALB_CONNECTION_LOGS"
    health_check = "ALB_HEALTH_CHECK_LOGS"
  }

  name         = "arcamap-alb-${each.key}"
  log_type     = each.value
  resource_arn = aws_lb.api.arn
}

resource "aws_cloudwatch_log_delivery_destination" "alb" {
  name          = "arcamap-alb"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = var.log_group_arn
  }
}

resource "aws_cloudwatch_log_delivery" "alb" {
  for_each = aws_cloudwatch_log_delivery_source.alb

  delivery_source_name     = each.value.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.alb.arn
}
