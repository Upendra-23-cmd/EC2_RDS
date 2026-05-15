resource "aws_launch_template" "my_launch_template" {
    name_prefix = "my_application_template"
    image_id = var.ami_id
    instance_type = var.instance_type
    key_name = aws_key_pair.key_pair.key_name
    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = var.root_volume_size
            volume_type = var.root_volume_type
        }
    }

    network_interfaces {
        associate_public_ip_address = true
        device_index = 0
        subnet_id = var.subnet_id[0]
        security_groups = [aws_security_group.security_groups.id]
    }
    
}


resource "aws_instance" "database_instance" {
    ami = "ami-091138d0f0d41ff90"
    instance_type = var.instance_type
    key_name = aws_key_pair.key_pair.key_name
    subnet_id = var.subnet_id[0]
    security_groups = [aws_security_group.database_security_groups.id]
    tags = {
        Name = "database-instance"
    }
  
}