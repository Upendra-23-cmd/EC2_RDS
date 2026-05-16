module "vpc" {
    source = "./vpc"
}

module "frontend" {
    source = "./Frontend_EC2"
    vpc_id = module.vpc.vpc_id
    subnet_id = module.vpc.public_subnet_id
}

module "backend" {
    source = "./Backend_EC2"
    subnet_id = module.vpc.private_subnet_id
    vpc_id = module.vpc.vpc_id
}

module "database" {
    source = "./database"
    subnet_id = module.vpc.database_subnet_id
    vpc_id = module.vpc.vpc_id
}