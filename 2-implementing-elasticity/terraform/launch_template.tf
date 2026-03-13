# -------------------------------------------------------------
# Compute configuration
# -------------------------------------------------------------

# Data source for the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

# 8. Launch Template
resource "aws_launch_template" "game_server" {
  name_prefix   = "simulearn-game-server-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Network configuration (Attach to the Web Security Group)
  network_interfaces {
    security_groups             = [aws_security_group.web_sg.id]
    associate_public_ip_address = true
  }

  # Add the User Data script (encoded in base64 as required by Launch Templates)
  user_data = filebase64("${path.module}/../scripts/userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Simulearn-Game-Server"
    }
  }

  tags = {
    Name = "Elasticity-Launch-Template"
  }
}
