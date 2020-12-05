provider "aws" {
  region                  = var.region
  shared_credentials_file = var.awscreds
  profile                 = var.awsprofile
}

# create a VPC
resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myterraformsetup"
  }
}
# Create an Internet Gateway
resource "aws_internet_gateway" "terraform-gw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "myterraformsetup"
  }
}

# Create custom Routing table
resource "aws_route_table" "terraform-rt" {
  vpc_id =aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0" ##sends all traffic to our VPC
    gateway_id = aws_internet_gateway.terraform-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.terraform-gw.id
  }

  tags = {
    Name = "myterraformsetup"
  }
}


# Create a subnet
resource "aws_subnet" "terraform-subnet" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Main"
  }
}

resource "aws_subnet" "terraform-subnet-2" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "Main"
  }
}
# Associate subnet to Routing table 
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.terraform-subnet.id
  route_table_id = aws_route_table.terraform-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.terraform-subnet-2.id
  route_table_id = aws_route_table.terraform-rt.id
}
# Create sercurtiy group to allow port 22,443,80,5432
resource "aws_security_group" "terraform-sg" {
  name        = "terraform-allow_webapp_traffic"
  description = "Allow webapp inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description = "HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "POstgresDB traffic from RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  ingress {
    description = "ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["150.129.100.40/32"]
  }

  #allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "myterraformsetup"
  }
}

# Create network interface with an IP in subnet that was created 
resource "aws_network_interface" "terraform-nic" {
  subnet_id       = aws_subnet.terraform-subnet.id
  private_ips     = ["10.0.1.50"]  #ip address in range of subnet created
  security_groups = [aws_security_group.terraform-sg.id]

}
resource "aws_network_interface" "terraform-nic-2" {
  subnet_id       = aws_subnet.terraform-subnet.id
  private_ips     = ["10.0.1.51"]  #ip address in range of subnet created
  security_groups = [aws_security_group.terraform-sg.id]

}
# Assign an Elastic IP to the network interface created internetgateway should be defined first
resource "aws_eip" "terraform-EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.terraform-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.terraform-gw]
}

resource "aws_eip" "terraform-EIP-2" {
  vpc                       = true
  network_interface         = aws_network_interface.terraform-nic-2.id
  associate_with_private_ip = "10.0.1.51"
  depends_on = [aws_internet_gateway.terraform-gw]
}
# Create Ubuntu server install Nginx
# get ami from aws ec2 instance console
resource "aws_instance" "my-terraform-server-1" {
  ami           = var.ec2-ami
  instance_type = var.ec2-instancetype
  availability_zone = var.ec2-availabilityzone
  key_name = var.ec2-privatekey

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.terraform-nic.id 
    
  }

## To run commands as userdata
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y 
              sudo apt install nginx -y
              sudo systemctl restart nginx 
              EOF

#creates a tag for the resources created
  tags = {
    Name = "myterraformsetup-1"
  }
}

resource "aws_instance" "my-terraform-server-2" {
  ami           = var.ec2-ami
  instance_type = var.ec2-instancetype
  availability_zone = var.ec2-availabilityzone
  key_name = var.ec2-privatekey

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.terraform-nic-2.id 
    
  }

## To run commands as userdata
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y 
              sudo apt install nginx -y
              sudo systemctl restart nginx 
              EOF

#creates a tag for the resources created
  tags = {
    Name = "myterraformsetup-2"
  }
}

output "server1_pubilc_IP" {
  value = aws_eip.terraform-EIP.public_ip
}

output "server2_pubilc_IP" {
  value = aws_eip.terraform-EIP-2.public_ip
}


## Creates Target Group for the Application ELB
resource "aws_lb_target_group" "my-terraform-elb-targetgroup" {
  name     = "my-terraform-elb-targetgroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform-vpc.id
#   path     = "/elb_status" 
}

## Attaches 2 EC2 instance to the Target Group
resource "aws_lb_target_group_attachment" "my-terraform-elb-targetgroup-attach-1" {
  target_group_arn = aws_lb_target_group.my-terraform-elb-targetgroup.arn
  target_id        = aws_instance.my-terraform-server-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "my-terraform-elb-targetgroup-attach-2" {
  target_group_arn = aws_lb_target_group.my-terraform-elb-targetgroup.arn
  target_id        = aws_instance.my-terraform-server-2.id
  port             = 80
}

##Created an Application ELB
resource "aws_lb" "my-terraform-elb" {
  name               = "my-terraform-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraform-sg.id]
  subnets            = [aws_subnet.terraform-subnet.id,aws_subnet.terraform-subnet-2.id,]

  tags = {
    Environment = "myterraformsetup"
  }
}

#Creates Listener for the ELB 
## HTTPS NOT DEFINED since ACM Certs validation limitation
resource "aws_lb_listener" "my-terraform-elb-listener" {
  load_balancer_arn = aws_lb.my-terraform-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-terraform-elb-targetgroup.arn
  }
}

output "elb_dns_name" {
  value = aws_lb.my-terraform-elb.dns_name
}

#Create SG for RDS
resource "aws_security_group" "terraform-rds-sg" {
  name        = "terraform-allow_RDS_traffic"
  description = "Allow rds inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description = "POstgresDB traffic To RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.terraform-sg.id]
  } 

  #allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "myterraformsetup"
  }
}

resource "aws_db_subnet_group" "terraform-rds-subnet" {
  name       = "main"
  subnet_ids = [aws_subnet.terraform-subnet.id, aws_subnet.terraform-subnet-2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

#Creates RDS POSTGRESQL DB
resource "aws_db_instance" "my-terraform-rds" {
  identifier           = "terraform-rds"
  allocated_storage    = var.rds-allocated_storage
  storage_type         = "gp2"
  engine               = var.rds-engine
  engine_version       = "11.6"
  instance_class       = var.dbintancetype
  name                 = var.dbname
  username             = var.dbuser
  password             = var.dbpassword
  parameter_group_name = "default.postgres11"
  skip_final_snapshot  = true
  apply_immediately = true
  final_snapshot_identifier = "whatever"
  db_subnet_group_name = aws_db_subnet_group.terraform-rds-subnet.id
  vpc_security_group_ids = [aws_security_group.terraform-rds-sg.id]
}

output "rds_endpoint" {
  value = "${aws_db_instance.my-terraform-rds.endpoint}"
}


#Creates S3 Bucket static hosting enabled
resource "aws_s3_bucket" "terraform-s3" {
    bucket = var.s3-bucket
    acl    = "public-read"
    policy = data.aws_iam_policy_document.bucket_policy.json
    website {
        index_document = "index.html"
        error_document = "index.html"
    }

}

data "aws_iam_policy_document" "bucket_policy" {
    statement {
        actions = [
            "s3:GetObject",
        ]
        principals {
            type = "*"
            identifiers = ["*"]
        }
    resources = [
      "arn:aws:s3:::${var.s3-bucket}/*"
    ]

    }
}

#Uploads and Index file
resource "aws_s3_bucket_object" "object" {
  bucket = var.s3-bucket
  key = "index.html"
  content_type = "text/html"
  source = "/home/nijo/Documents/mydocs/terraform/index.html"
  depends_on = [aws_s3_bucket.terraform-s3]
}

output "s3_endpoint" {
  value = "${aws_s3_bucket.terraform-s3.website_endpoint}"
}

# CREATES CDN Distirbution
resource "aws_cloudfront_distribution" "terraform-cdn" {
  origin {

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

# Orgin Bucket
    domain_name = aws_s3_bucket.terraform-s3.website_endpoint
    origin_id   = "terraform-s3.website"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "terraform-s3.website"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true  
    ssl_support_method  = "sni-only"
  }
}

output "cdn_endpoint" {
  value = "${aws_cloudfront_distribution.terraform-cdn.domain_name}"
}
