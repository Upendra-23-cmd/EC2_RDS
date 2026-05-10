resource "aws_launch_template" "my_launch_template" {
    name_prefix = "my_application_template"
    image_id = var.ami_id
    instance_type = var.instance_type
    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = var.root_volume_size
            volume_type = var.root_volume_type
        }
    }
    
}