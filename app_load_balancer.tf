#
# This will establish an application load balancer, the required security group and the needed target groups
#
# The order of opreations is:
# 1) Create Security group
#    a. ingress from corporate IPs
#    b. ingress from Route53 DNS Health Check Service
#
# 2) Create the actual load balancer
#    a. Must be AFTER service instance is created
#
# 2) Create Target Groups
#    a. circleci-users (port 443, health check on port 8800, /ping
#    b. circleci-admin (port 8800, healtch check on same port /ping
#
# 4) Create the Listeners
#

resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}_circleci_alb_sg"
  tags        = merge(var.Tags, {"Name" = format("%s-circleci-alb-sg", var.prefix)})
  description = "SG for CircleCI Application Load Balancer"
  vpc_id      = var.aws_vpc_id

  ingress {
    cidr_blocks = concat( var.Company_IPs, var.aws_nat_eip_list) 
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }

  ingress {
    cidr_blocks = concat(var.Company_IPs, var.aws_nat_eip_list)
    from_port = 443 
    to_port   = 443
    protocol  = "tcp"
  }

  ingress {
    cidr_blocks = concat(var.Company_IPs, var.aws_nat_eip_list)
    from_port = 8800
    to_port   = 8800
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb" {  
  name            = "${var.prefix}-circleci-alb"  
  subnets         = var.aws_public_subnet_list
  security_groups = [aws_security_group.alb_sg.id]
  internal        = false  
  tags            = merge(var.Tags, {"Name" = format("%s-circleci-alb", var.prefix)})
}

resource "aws_alb_target_group" "admin"{
  name        = "circleci-admin"
  target_type = "instance"
  vpc_id      = var.aws_vpc_id
  port        = 8800
  protocol    = "HTTPS"

  health_check {
    enabled = true
    protocol = "HTTPS"
    path     = "/ping"
#    port     = traffic-port
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout  = 5
    interval = 30
    matcher  = "200"
  }

  tags = var.Tags
}

resource "aws_alb_target_group" "http-users"{
  name        = "circleci-users"
  target_type = "instance"
  vpc_id      = var.aws_vpc_id
  port        = 80
  protocol    = "HTTP"

  health_check {
    enabled = true
    protocol = "HTTPS"
    path     = "/ping"
    port     = 8800
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout  = 5
    interval = 30
    matcher  = "200"
  }

  tags = var.Tags
}

resource "aws_alb_listener" "https_users_listener" {  
  load_balancer_arn = aws_alb.alb.arn  
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:us-east-1:432450059541:certificate/be827bcf-de59-4050-a72f-bcea76bffbc2"

  default_action {    
    target_group_arn = aws_alb_target_group.http-users.arn
    type             = "forward"  
  }
}

resource "aws_alb_listener" "http_users_listener" {  
  load_balancer_arn = aws_alb.alb.arn  
  port              = "80"
  protocol          = "HTTP"

  default_action {    
    target_group_arn = aws_alb_target_group.http-users.arn
    type             = "forward"  
  }
}

resource "aws_alb_listener" "admin_listener" {  
  load_balancer_arn = aws_alb.alb.arn
  port              = "8800"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:432450059541:certificate/be827bcf-de59-4050-a72f-bcea76bffbc2"
  
  default_action {    
    target_group_arn = aws_alb_target_group.admin.arn
    type             = "forward"  
  }
}

resource "aws_alb_target_group_attachment" "svc_admin" {
  target_group_arn = aws_alb_target_group.admin.arn
  target_id        = aws_instance.services.id  
  port             = 8800
}

resource "aws_alb_target_group_attachment" "svc_user" {
  target_group_arn = aws_alb_target_group.http-users.arn
  target_id        = aws_instance.services.id  
  port             = 80
}
