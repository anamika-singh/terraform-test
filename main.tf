provider "aws" {
  region = var.region
  profile = "hcapdevelopment"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet-a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-a
  availability_zone = "${var.region}a"
  #map_public_ip_on_launch = false
}

resource "aws_subnet" "subnet-b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-b
  availability_zone = "${var.region}b"
  #map_public_ip_on_launch = false
}

resource "aws_subnet" "subnet-c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-c
  availability_zone = "${var.region}c"
  #map_public_ip_on_launch = false
}

resource "aws_route_table" "subnet-route-table-public" {
  vpc_id = aws_vpc.vpc.id
}
resource "aws_route_table" "subnet-route-table-private" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${element(aws_subnet.subnet-a.*.id, 0)}"
  depends_on    = [aws_internet_gateway.igw]
  
}

resource "aws_route" "subnet-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.subnet-route-table-public.id
}

resource "aws_route" "subnet-route-private" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
  route_table_id         = aws_route_table.subnet-route-table-private.id
}

resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.subnet-route-table-public.id
}

resource "aws_route_table_association" "subnet-b-route-table-association" {
  subnet_id      = aws_subnet.subnet-b.id
  route_table_id = aws_route_table.subnet-route-table-private.id
}

resource "aws_route_table_association" "subnet-c-route-table-association" {
  subnet_id      = aws_subnet.subnet-c.id
  route_table_id = aws_route_table.subnet-route-table-private.id
}


 data "aws_ami" "amazon-linux-2" {
 most_recent = true
 owners      = ["amazon"]


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]

 }
}


resource "aws_instance" "instance" {
  ami                         = "${data.aws_ami.amazon-linux-2.id}"
  instance_type               = "t2.small"
  vpc_security_group_ids      = [ aws_security_group.security-group.id ]
  subnet_id                   = aws_subnet.subnet-a.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

resource "aws_security_group" "security-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

output "nginx_domain" {
  value = aws_instance.instance.public_dns
}


resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "relaunched-"
  image_id      = aws_instance.instance.ami
  instance_type = "t2.small"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bar" {
  name                 = "autoscalling"
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = [aws_subnet.subnet-a.id, aws_subnet.subnet-b.id,aws_subnet.subnet-c.id]
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
}
