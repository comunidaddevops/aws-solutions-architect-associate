# -------------------------------------------------------------
# Load Balancing configuration
# -------------------------------------------------------------

# 9. Target Group
resource "aws_lb_target_group" "game_tg" {
  name     = "simulearn-game-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health Check configuration
  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
  }

  tags = {
    Name = "Elasticity-Target-Group"
  }
}

# 10. Application Load Balancer (ALB)
resource "aws_lb" "game_alb" {
  name               = "simulearn-game-alb"
  internal           = false # It's internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "Elasticity-ALB"
  }
}

# 11. ALB Listener (Listens on Port 80 and forwards to Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.game_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game_tg.arn
  }
}

# Update outputs.tf to include the ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.game_alb.dns_name
  description = "The DNS name of the Application Load Balancer"
}
