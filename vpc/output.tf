output  "vpc_id" {
    description = "value of vpc id"
    value = aws_vpc.my_vpc.id
}

output "public_subnet_id" {
    description = "value of public subnet id"
    value = aws_subnet.public_frontend.id
}

output "private_subnet_id" {
    description = "value of private subnet id"
    value = aws_subnet.private_backend.id
}

output "database_subnet_id" {
    description = "value of database subnet id"
    value = aws_subnet.private_database.id
}
