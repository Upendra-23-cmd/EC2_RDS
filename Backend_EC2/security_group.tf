resource "aws_security_group" "private_security_groups" {
    name = "backend_microservices-sg"
    description = "Security group for microservices"
    vpc_id = var.vpc_id

    # INBOUND RULES
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
    }

    # OUTBOUND RULES
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }



    tags = {
      Name = "private-micro-subnet-sg"
    }
}

