terraform {
    required_version = ">=1.2"
    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

provider "aws" {
    region = var.region

}

resource "aws_vpc" "my_server_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "my-server-vpc"
    }
}

resource "aws_subnet" "public_subnet" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet" {
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1b"
    tags = {
        Name = "my-private-subnet"
    }
}

resource "aws_subnet" "private_subnet" {
    cidr_block = "10.0.3.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1c"
    tags = {
        Name = "my-private-subnet-database"
    }
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_server_vpc.id
    tags = {
        Name = "my-rds-gateway"
    }
}

resource "aws_route_table" "my_rt" {
    vpc_id = aws_vpc.my_server_vpc.id
    tags = {
        Name = "my-route-table"
    }
}

resource "aws_route_ta" "name" {
  
}