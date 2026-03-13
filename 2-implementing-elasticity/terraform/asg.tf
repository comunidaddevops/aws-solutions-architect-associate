# -------------------------------------------------------------
# Auto Scaling configuration
# -------------------------------------------------------------

# 12. Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "game_asg" {
  name                = "simulearn-game-asg"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.game_tg.arn]

  # Capacity configuration (Requirements from the Practice Lab)
  min_size         = 2
  desired_capacity = 2
  max_size         = 4 # Adjusted max size to >2 so the ASG can actually scale UP when CPU reaches 50%

  # Using the Launch Template we created in Phase 2
  launch_template {
    id      = aws_launch_template.game_server.id
    version = "$Latest"
  }

  # Ensure the health of the instances using both EC2 and ALB checks
  health_check_type         = "ELB"
  health_check_grace_period = 300 # Give instances 5 mins to bootstrap before checking health

  tag {
    key                 = "Name"
    value               = "Simulearn-ASG-Instance"
    propagate_at_launch = true
  }
}

# 13. Auto Scaling Policy: Target Tracking (Maintain 50% CPU)
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "simulearn-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.game_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

# 14. DIY Goal: Scheduled Action 
# Requirement: Set desired capacity to 3 every Friday at 8:00 PM UTC
resource "aws_autoscaling_schedule" "friday_scale_up" {
  scheduled_action_name  = "scale-up-friday-evening"
  min_size               = 2
  max_size               = 4
  desired_capacity       = 3
  
  # Cron format: Minute Hour DayOfMonth Month DayOfWeek
  # 8:00 PM = 20:00. Friday = 5.
  recurrence             = "0 20 * * 5"
  
  autoscaling_group_name = aws_autoscaling_group.game_asg.name
}
