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

resource "aws_subnet" "public_subnet_app" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1a"
    tags = {
        Name = "my-public-subnet"
    }
    map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_db" {
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1b"
    tags = {
        Name = "my-private-subnet-database"
    }
}

resource "aws_subnet" "private_subnet_app" {
    cidr_block = "10.0.3.0/24"
    vpc_id = aws_vpc.my_server_vpc.id
    availability_zone = "us-east-1c"
    tags = {
        Name = "my-private-subnet-application"
    }
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_server_vpc.id
    tags = {
        Name = "my-rds-gateway"
    }
}

resource "aws_eip" "nat_eip_app" {
    domain = "vpc"
    tags = {
        Name = "my-nat-eip"
    }
}


resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id = aws_subnet.public_subnet_app.id
    tags = {
        Name = "my-nat-gateway"
    }
}

resource "aws_nat_gateway" "nat_gateway_db" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id = aws_subnet.private_subnet_app.id
    tags = {
        Name = "my-nat-gateway"
    }
}


resource "aws_route_table" "my_rt" {
    vpc_id = aws_vpc.my_server_vpc.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
    }
    tags = {
        Name = "my-route-table"
    }
}

resource "aws_route_table" "my_private_route_table_db" {
    vpc_id = aws_vpc.my_server_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gatewa_db.id
    }
  tags = {
    Name = "my-private-route-table_db"
  }
}

resource "aws_route_table_association" "my_private_rt_table_association_db" {
    subnet_id =  aws_subnet.private_subnet_db.id
    route_table_id = aws_route_table.my_private_route_table_db.id
}

resource "aws_route_table" "my_private_route_table" {
    vpc_id = aws_vpc.my_server_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway.id
    }
  tags = {
    Name = "my-private-route-table"
  }
}

resource "aws_route_table_association" "my_private_rt_table_association" {
    subnet_id =  aws_subnet.private_subnet_app.id
    route_table_id = aws_route_table.my_private_route_table.id
  
}

resource "aws_route_table_association" "my_rt_table_association" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.my_rt.id
  
}

