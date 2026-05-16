resource "tls_private_key" "private_key_pem" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "local_file" "local_file" {
    content = tls_private_key.private_key_pem.private_key_pem
    filename = "${path.module}/my_temp_key.pem"
    file_permission = "0400"
}

resource "aws_key_pair" "key_pair_database" {
    key_name = "my_key_pair-2"
    public_key = tls_private_key.private_key_pem.public_key_openssh
}