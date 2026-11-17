terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# Preserve existing Terraform resource addresses

moved {
  from = aws_vpc.main
  to   = module.vpc.aws_vpc.main
}

moved {
  from = aws_subnet.public_a
  to   = module.vpc.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.vpc.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.vpc.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.vpc.aws_subnet.private_b
}

moved {
  from = aws_internet_gateway.main
  to   = module.vpc.aws_internet_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public
}

moved {
  from = aws_route_table_association.public_a
  to   = module.vpc.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.vpc.aws_route_table_association.public_b
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}

moved {
  from = aws_route_table_association.private_a
  to   = module.vpc.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_b
  to   = module.vpc.aws_route_table_association.private_b
}

moved {
  from = aws_security_group.web
  to   = module.vpc.aws_security_group.web
}