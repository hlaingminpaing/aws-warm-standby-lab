# --- SECURITY GROUPS ---
resource "aws_security_group" "alb_primary" {
  provider    = aws.primary
  name        = "alb-sg-primary"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.vpc_primary.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_primary" {
  provider    = aws.primary
  name        = "app-sg-primary"
  description = "Allow HTTP from ALB"
  vpc_id      = module.vpc_primary.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_primary.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_standby" {
  provider    = aws.standby
  name        = "alb-sg-standby"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.vpc_standby.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_standby" {
  provider    = aws.standby
  name        = "app-sg-standby"
  description = "Allow HTTP from ALB"
  vpc_id      = module.vpc_standby.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_standby.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- AMI DATA SOURCE ---
data "aws_ami" "amazon_linux_primary" {
  provider    = aws.primary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "amazon_linux_standby" {
  provider    = aws.standby
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- PRIMARY COMPUTE ---
resource "aws_lb" "primary" {
  provider           = aws.primary
  name               = "primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_primary.id]
  subnets            = module.vpc_primary.public_subnets
}

resource "aws_lb_target_group" "primary" {
  provider = aws.primary
  name     = "primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc_primary.vpc_id
}

resource "aws_lb_listener" "primary" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

resource "aws_launch_template" "primary" {
  provider      = aws.primary
  name_prefix   = "primary-app-"
  image_id      = data.aws_ami.amazon_linux_primary.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app_primary.id]

  user_data = base64encode(templatefile("${path.module}/app_userdata.sh.tpl", {
    region_name          = "Primary Active Region"
    db_host              = aws_rds_cluster.primary.endpoint
    db_user              = aws_rds_cluster.primary.master_username
    db_pass              = aws_rds_cluster.primary.master_password
    db_name              = aws_rds_cluster.primary.database_name
    app_js_content       = file("${path.module}/app/server.js")
    package_json_content = file("${path.module}/app/package.json")
  }))
}

resource "aws_autoscaling_group" "primary" {
  provider            = aws.primary
  name                = "primary-asg"
  vpc_zone_identifier = module.vpc_primary.private_subnets
  target_group_arns   = [aws_lb_target_group.primary.arn]
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.primary.id
    version = "$Latest"
  }
}

# --- STANDBY COMPUTE ---
resource "aws_lb" "standby" {
  provider           = aws.standby
  name               = "standby-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_standby.id]
  subnets            = module.vpc_standby.public_subnets
}

resource "aws_lb_target_group" "standby" {
  provider = aws.standby
  name     = "standby-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc_standby.vpc_id
}

resource "aws_lb_listener" "standby" {
  provider          = aws.standby
  load_balancer_arn = aws_lb.standby.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.standby.arn
  }
}

resource "aws_launch_template" "standby" {
  provider      = aws.standby
  name_prefix   = "standby-app-"
  image_id      = data.aws_ami.amazon_linux_standby.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app_standby.id]

  user_data = base64encode(templatefile("${path.module}/app_userdata.sh.tpl", {
    region_name          = "Standby (Inactive) Region"
    db_host              = aws_rds_cluster.standby.endpoint
    db_user              = aws_rds_cluster.primary.master_username
    db_pass              = aws_rds_cluster.primary.master_password
    db_name              = aws_rds_cluster.primary.database_name
    app_js_content       = file("${path.module}/app/server.js")
    package_json_content = file("${path.module}/app/package.json")
  }))
}

resource "aws_autoscaling_group" "standby" {
  provider            = aws.standby
  name                = "standby-asg"
  vpc_zone_identifier = module.vpc_standby.private_subnets
  target_group_arns   = [aws_lb_target_group.standby.arn]
  min_size            = 1 # Minimal instances for warm standby
  max_size            = 4
  desired_capacity    = 1 # Scaled down

  launch_template {
    id      = aws_launch_template.standby.id
    version = "$Latest"
  }
}
