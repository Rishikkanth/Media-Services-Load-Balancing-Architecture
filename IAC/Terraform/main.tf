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

resource "aws_ecs_cluster" "media" {
  name = var.cluster_name
}

resource "aws_ecs_task_definition" "media_td" {
  family                   = "${var.project}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu    = "512"
  memory = "1024"

  container_definitions = jsonencode([
    {
      name      = "media-node"
      image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/media:latest"
      essential = true
      portMappings = [{ containerPort = 4001, hostPort = 4001, protocol = "tcp" }]
      environment = [
        { name = "REGISTRY_TABLE", value = aws_dynamodb_table.registry.name }
      ]
      command = ["/bin/sh","-c","/app/register_on_start.sh && /app/start_media.sh"]
    }
  ])
  execution_role_arn = aws_iam_role.ecs_task_exec.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
}

resource "aws_ecs_service" "media_svc" {
  name            = "${var.project}-svc"
  cluster         = aws_ecs_cluster.media.arn
  task_definition = aws_ecs_task_definition.media_td.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    assign_public_ip = false
    security_groups  = [] # SG for tasks
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.media_tg1.arn
    container_name   = "media-node"
    container_port   = 4001
  }

  lifecycle {
    ignore_changes = [desired_count] # allow external scaler/drain controller
  }
}

resource "aws_dynamodb_table" "registry" {
  name         = "${var.project}-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "node_id"

  attribute { name = "node_id", type = "S" }
  attribute { name = "path",    type = "S" }

  global_secondary_index {
    name            = "path-index"
    hash_key        = "path"
    projection_type = "ALL"
  }
}

resource "aws_iam_role" "drain_lambda_role" {
  name = "${var.project}-drain-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
data "aws_iam_policy_document" "lambda_assume" {
  statement { actions = ["sts:AssumeRole"], principals { type = "Service", identifiers = ["lambda.amazonaws.com"] } }
}
resource "aws_iam_policy" "drain_policy" {
  name   = "${var.project}-drain-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect="Allow", Action=["elasticloadbalancing:DeregisterTargets","elasticloadbalancing:ModifyRule","elasticloadbalancing:DescribeRules"], Resource="*" },
      { Effect="Allow", Action=["ecs:StopTask","ecs:DescribeTasks"], Resource="*" },
      { Effect="Allow", Action=["dynamodb:GetItem","dynamodb:UpdateItem","dynamodb:Query","dynamodb:Scan"], Resource=aws_dynamodb_table.registry.arn },
      { Effect="Allow", Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource="*" }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "drain_attach" {
  role       = aws_iam_role.drain_lambda_role.name
  policy_arn = aws_iam_policy.drain_policy.arn
}

resource "aws_lambda_function" "drain_controller" {
  function_name = "${var.project}-drain-controller"
  role          = aws_iam_role.drain_lambda_role.arn
  runtime       = "python3.11"
  handler       = "lambda_drain_controller.handler"
  filename      = "${path.module}/../../automation/lambda_drain_controller.zip"
  timeout       = 900
  environment {
    variables = {
      REGISTRY_TABLE = aws_dynamodb_table.registry.name
    }
  }
}

# Example: EventBridge rule you call manually or on scale-in signals
resource "aws_cloudwatch_event_rule" "drain_rule" {
  name        = "${var.project}-drain"
  description = "Trigger per-node drain"
  event_pattern = jsonencode({
    source = ["custom.media"],
    detail_type = ["scale-in-node"]
  })
}
resource "aws_cloudwatch_event_target" "drain_target" {
  rule      = aws_cloudwatch_event_rule.drain_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.drain_controller.arn
}
resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drain_controller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.drain_rule.arn
}
