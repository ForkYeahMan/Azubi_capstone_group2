# ---------------------------------------------------------------------------
# Auto Scaling Group + launch template
# Mirrors: ASG "group-2-alb" (min 1 / max 4 / desired 1) using launch template
# "Group-2-Templates". In the live account this ran ALONGSIDE the fixed
# instances in compute.tf (var.instance_count), all feeding the same target
# group. Set enable_asg = false if you only want the fixed instances.
# ---------------------------------------------------------------------------

resource "aws_launch_template" "app" {
  count         = var.enable_asg ? 1 : 0
  name          = "Group-2-Templates"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # The live template did not pin a security group / instance profile / user
  # data. Attaching them here makes ASG nodes match the fixed instances.
  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Project = "group-2" }
  }
}

resource "aws_autoscaling_group" "app" {
  count               = var.enable_asg ? 1 : 0
  name                = "group-2-alb"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.http.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = "group-2"
    propagate_at_launch = true
  }
}
