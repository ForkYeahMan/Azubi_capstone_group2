# ---------------------------------------------------------------------------
# Backend EC2 instances + Application Load Balancer
# Mirrors: group-2-1/2/3, group-2-alb, group-2-tg-http
# ---------------------------------------------------------------------------

# Latest Amazon Linux 2023 (matches the live AMI family). Override with var.ami_id.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, data.aws_ami.al2023.id)
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = true

  # NOTE: fresh instances come up BARE. Put your app bootstrap here (or deploy
  # via SSM / your GitHub Actions pipeline after apply).
  # user_data = file("${path.module}/bootstrap.sh")

  tags = { Name = "${var.project}-${count.index + 1}" }
}

resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "${var.project}-alb" }
}

resource "aws_lb_target_group" "http" {
  name        = "${var.project}-tg-http"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}
