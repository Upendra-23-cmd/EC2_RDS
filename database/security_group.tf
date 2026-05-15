

resource "aws_security_group" "database_security_groups" {
    name = "microservices-sg"
    description = "Security group for microservices"
    vpc_id = var.vpc_id

    # INBOUND RULES
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = "10.0.3.0/24"
    }


    # OUTBOUND RULES
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
    }

    tags = {
      Name = "database-micro-subnet-sg"
    }
}