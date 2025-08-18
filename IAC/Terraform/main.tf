provider "aws" { region = "us-east-1" }

resource "aws_lb" "media_alb" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [] # attach your SGs
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.media_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action { type = "fixed-response"
    fixed_response { content_type = "text/plain" message_body = "Not Found" status_code = "404" }
  }
}

resource "aws_lb_target_group" "media_tg1" {
  name        = "${var.project}-tg-1"
  port        = 4001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5 # we drain via controller, do not rely on this
  health_check {
    protocol = "HTTP"
    path     = var.tg_healthy_path
    matcher  = "200-399"
    interval = 30
  }
}

# Path-based rule for /media/1/*
resource "aws_lb_listener_rule" "media1" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition { path_pattern { values = ["/media/1/*"] } }

  action {
    type = "forward"
    forward {
      target_group { arn = aws_lb_target_group.media_tg1.arn, weight = 1 }
      stickiness { enabled = false }
    }
  }
}
