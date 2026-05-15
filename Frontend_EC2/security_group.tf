resource "aws_security_group" "security_groups" {
    name = "microservices-sg"
    description = "Security group for microservices"
    vpc_id = var.vpc_id

    # INBOUND RULES
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = "0.0.0.0/0"
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = "0.0.0.0/0"
    }

    # OUTBOUND RULES
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
    }

    tags = {
      Name = "public-micro-subnet-sg"
    }
}


