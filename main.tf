provider "aws" {
  access_key = ""
  secret_key = ""
  region = "us-east-2"
}

# create a vpc

resource "aws_vpc" "terraform-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc"
  }
}

# create internet gateway

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "igw"
  }
}

# create custom route table

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "preprod"
  }
}

# create subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "preprod-subnet"
  }
}

# assiciate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route-table.id
}

# create a security group to allow port 22,80,443

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# create network interface with an ip in the subnet

resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]

}

# assign an elastic ip to the network interface

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.internet-gateway]
}

# create ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami           = "ami-0a91cd140a1fc148a"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name      = "hpsaws_key"
#  user_data = file("/home/ubuntu/terraform-demo/nginx.sh")

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
}

  tags = {
    Name = "terraform-instance-web"
 }

}
