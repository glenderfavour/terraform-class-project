# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = var.vpc_name
    Env    = var.environment
    team   = var.team
  }
}

#create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "tf_igw"
  }
}

#create Route Table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tf_routetable"
  }
}

#create Subnet
resource "aws_subnet" "pub-subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ca-central-1a"

  tags = {
    Name = "publ-tf-subnet"
  }
}

#create routetable association
resource "aws_route_table_association" "sub_association" {
  subnet_id      = aws_subnet.pub-subnet.id
  route_table_id = aws_route_table.route-table.id
}

#create security Group with port 22 and 443
resource "aws_security_group" "ssh_https_sg" {
  name        = "allow_ssh_https"
  description = "Allow ssh_https inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }


  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]

  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_https"
  }
}

#create private subnet
resource "aws_subnet" "pri-subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ca-central-1a"
  tags = {
    Name = "pri-tf-subnet"
  }
}

#create private subnet for rds
resource "aws_subnet" "pri-subnet-rds" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ca-central-1b"
  tags = {
    Name = "pri-tf-rds-subnet"
  }
}

#create subnet group for rds
resource "aws_db_subnet_group" "rds-subnet-gp" {
  name       = "rds_subnet"
  subnet_ids = [aws_subnet.pri-subnet.id, aws_subnet.pri-subnet-rds.id]

  tags = {
    Name = "rds_subnet"
  }
}

#create security group for rds
resource "aws_security_group" "rdssg" {
  name   = "rds_sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ssh_https_sg.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

#creat nat gateway
resource "aws_eip" "elastic-ip" {
  #instance = aws_instance.ec2_instance.id
  #vpc      = aws_vpc.vpc.id
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.elastic-ip.id
  subnet_id     = aws_subnet.pub-subnet.id

  tags = {
    Name = "tf_natgtw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

#create private route table
resource "aws_route_table" "priv-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = aws_subnet.pri-subnet.cidr_block
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "tf-priv-routetable"
  }
}

#create private route table association
resource "aws_route_table_association" "priv-sub-association" {
  subnet_id      = aws_subnet.pri-subnet.id
  route_table_id = aws_route_table.priv-route-table.id
}