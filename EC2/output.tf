output "template_id" {
    description = "Launch Template ID for the created launch template"
    value = aws_launch_template.my_launch_template.id
}