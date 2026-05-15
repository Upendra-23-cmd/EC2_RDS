module "vpc" {
    source = "./vpc"
}

module "frontend" {
    source = "./Frontend_EC2"
    vpc_id = module.vpc.vpc_id
    subnet_id = module.vpc.public_frontend.id
}

module "backend" {
    source = "./Backend_EC2"
    subnet_id = module.vpc.private_backend.id
    vpc_id = module.vpc.vpc_id
}

module "database" {
    source = "./database"
    subnet_id = module.vpc.private_database.id
    vpc_id = module.vpc.vpc_id
}