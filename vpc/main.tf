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

# create a vpc ffor the microservices application

resource aws_vpc "my_vpc" {
    cidr_block = var.cidr_block
    tags = {
        Name = "microservices-vpc"
        environment = "devlopement"
          }
}

# Create three subnets: one public for the frontend, and two private for the backend and database

resource "aws_subnet" "public_frontend" {
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "public-frontend-subnet"
        environment = "devlopement"
          }
}

resource "aws_subnet" "private_backend" {
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1a"
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "private-backend-subnet"
        environment = "devlopement"
          }
}

resource "aws_subnet" "private_database" {
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "private-database-subnet"
        environment = "devlopement"
          }
}

# Create an internet gateway and attach it to the VPC

resource "aws_internet_gateway" "microservices_igw" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "microservices-igw"
        environment = "devlopement"
          }
  
}

# Create route tables for public and private subnets

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.microservices_igw.id
    }
    tags = {
        Name = "public-route-table"
        environment = "devlopement"
          }
}

resource "aws_route_table" "privatebackend_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "public-route-table"
        environment = "devlopement"
          }
}

resource "aws_route_table" "privatdatabase_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "public-route-table"
        environment = "devlopement"
          }
}

# Associate the public route table with the public subnet

resource "aws_route_table_association" "public_frontend" {
    subnet_id = aws_subnet.public_frontend.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "backend_private" {
    subnet_id = aws_subnet.private_backend.id
    route_table_id = aws_route_table.privatebackend_route_table.id
}

resource "aws_route_table_association" "databse_private" {
    subnet_id = aws_subnet.private_database
    route_table_id = aws_route_table.privatdatabase_route_table.id
}