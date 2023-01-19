locals {

    project_name = "ec2-nginx"
    name_context = "${local.project_name}-${terraform.workspace}"
    name = "${local.project_name}-${terraform.workspace}"

    global_tag = {
        Billing     = "Billing Account 01"
    }

    project_tag = {
        Environment = terraform.workspace
        Project     = local.project_name
    }

    tags  = merge(local.global_tag,local.project_tag)

    region = "eu-central-1"

}
######################
#Simpler no module vpc
######################

# resource "aws_vpc" "main" {
#   cidr_block           = "192.168.0.0/16" # <--- pick a network from the private CIDR block defined by RFC1918
#   enable_dns_hostnames = true
#   enable_dns_support   = true # <-- this is all that is required to have basic DNS in our VPC
#   tags = {
#     Name = "Demo-VPC"
#   }
# }
# resource "aws_subnet" "public" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "192.168.1.0/24"
#   map_public_ip_on_launch = true # <--- this will give instances a internet routable IP-address
#   tags = {
#     Name = "Demo-Subnet-Public"
#   }
# }
# resource "aws_internet_gateway" "ig" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "Demo-IGW"
#   }
# }
# # Allocate a new, permanent public IP address
# resource "aws_eip" "nat_public_ip" {
#   vpc = true
# }
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.ig.id
#   }
# }
# resource "aws_route_table_association" "public" {
#   route_table_id = aws_route_table.public.id
#   subnet_id      = aws_subnet.public.id
# }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name_context}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b",]
  private_subnets = []
  # private_subnets = ["10.0.1.0/24", "10.0.2.0/24",]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = false
  enable_vpn_gateway = false
  enable_dns_hostnames = true

  tags = {
    Terraform = "true"
    Environment = local.project_tag.Environment
  }
}

################
##security group
################
module "security" {
    source = "./modules/security"
    # vpc_id = aws_vpc.main.id if used no module vpc
    vpc_id = module.vpc.vpc_id

}

#########
#DATA AMI
#########
data "aws_ami" "ec2_instance" {
  most_recent = true
  owners      = ["amazon"]

 filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
#####
#EC2
#####
resource "aws_instance" "ec2_instance" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.ec2_instance.id
  user_data              = file("userdata.tpl")
  subnet_id              = module.vpc.public_subnets[0]
  # subnet_id              = aws_subnet.public.id when using no module vpc
  iam_instance_profile   = aws_iam_instance_profile.dev-resources-iam-profile.name
  vpc_security_group_ids = [module.security.EC2_sg]
  tags = local.tags

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 20
}

}

#######################
#IAM & instance profile
#######################
resource "aws_iam_instance_profile" "dev-resources-iam-profile" {
name = "ec2_profile"
role = aws_iam_role.dev-resources-iam-role.name
}

resource "aws_iam_role" "dev-resources-iam-role" {
name        = "dev-ssm-role"
description = "The role for the developer resources EC2"
assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
                 }
}
EOF
}

resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
role       = aws_iam_role.dev-resources-iam-role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
