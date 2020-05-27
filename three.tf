provider "aws" {
    version = "~> 2.17"
    region = "us-east-1"
    profile="dev"
    shared_credentials_file = "~/.aws/credentials"

  #   assume_role {
  #     role_arn = "arn:aws:iam::015517000868:role/OrganizationAccountAccessRole"
  #     session_name = "terraform-session"
  # }
}

variable "ecs_cluster_name" {
  default =  "Test-ECS-Cluster"
  description = "Name of ECS Cluster"
}
variable "app_name" {
  default =  "ngs-test-app"
  description = "Application/GitHub repo name"
}

#get all "available" availability zones 
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ecs" {
  most_recent = true # get the latest version

  filter {
    name = "name"
    values = ["amzn2-ami-ecs-*"] # ECS optimized image
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = [
    "amazon" # Only official images
  ]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "test-arif"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# VPC
output "vpc_id" {
  description = "VPC Id"
  value       = module.vpc.vpc_id
}


module "ecs-cluster" {
  source = "./terraform-ecs-cluster/"
  # source = "github.com/ArifCengic/tf-ecs"
  iam_instance_profile = "arn:aws:iam::015517000868:instance-profile/ECS-APP-Role"
  ecs_cluster_name =  "Dev-POC-cluster"
  instance_type = "t2.medium"
  max_size = 3
  min_size = 1
  desired_capacity = 2
  # key_name = "MyKeyPair"
  vpc_public_subnets = module.vpc.private_subnets
  security_group_id = aws_security_group.sg_for_ec2_instances.id
}

# variable "container_port" {
#   default = "8080"
#   description = "Container Application port Exposed in Dockerfile  "
# }
# variable "container_name" {
#   default = "wordpress"
# }

module "ecs-service2" {
  source = "./terraform-ecs-service/"
  container_port = "5000"
  docker_image = "cengica/notifications"
  container_name = "aws_test"
  app_name = "test-aws-test"
  cluster_id = module.ecs-cluster.ecs_cluster_id
  vpc = module.vpc
  security_group_id = aws_security_group.sg_for_ec2_instances.id
  postgres_address = "jane-db.cdw7pvmeniqb.us-east-1.rds.amazonaws.com"
}

output "dns_name2" {
  value = module.ecs-service2.dns_name
}
# output "alb_target_group_id" {
#   value = aws_alb_target_group.one.id
# }

# module "ecs" {
#   source = "terraform-aws-modules/ecs/aws"
#   name = "test-ecs-arif"
# }


# Allow EC2 instances to receive HTTP/HTTPS/SSH traffic IN and any traffic OUT
resource "aws_security_group" "sg_for_ec2_instances" {
  name_prefix = "${var.ecs_cluster_name}_sg_for_ec2_instances_"
  description = "Security group for EC2 instances within the cluster"
  vpc_id      = module.vpc.vpc_id
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = var.ecs_cluster_name
  }
}

# test setting allow all - remve in staging/production
resource "aws_security_group_rule" "allow_ingress_all" {
  security_group_id = aws_security_group.sg_for_ec2_instances.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_for_ec2_instances.id
}
resource "aws_security_group_rule" "allow_http_in" {
  type = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_for_ec2_instances.id
}

resource "aws_security_group_rule" "allow_https_in" {
  type      = "ingress"
  protocol  = "tcp"
  from_port = 443
  to_port   = 443
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_for_ec2_instances.id
}

resource "aws_security_group_rule" "allow_egress_all" {
  security_group_id = aws_security_group.sg_for_ec2_instances.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}


resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "My DB subnet group"
  }
}

# resource "aws_db_instance" "mydb1" {
#   allocated_storage        = 256 # gigabytes
#   backup_retention_period  = 7   # in days
#   # db_subnet_group_name     = "${var.rds_public_subnet_group}"
#   db_subnet_group_name     = aws_db_subnet_group.default.name
#   engine                   = "postgres"
#   engine_version           = "9.5.4"
#   identifier               = "testdb1"
#   instance_class           = "db.r3.large"
#   # instance_class           = "db.t2.micro"
#   multi_az                 = false
#   name                     = "testdb1"
#   # parameter_group_name     = "mydbparamgroup1" # if you have tuned it
#   # password                 = "${trimspace(file("${path.module}/secrets/mydb1-password.txt"))}"
#   password                 = "Pa$$w0rd!!"
#   port                     = 5432
#   publicly_accessible      = false
#   storage_encrypted        = true # you should always do this
#   storage_type             = "gp2"
#   username                 = "test"
#   vpc_security_group_ids   = [aws_security_group.sg_for_ec2_instances.id]
#   skip_final_snapshot      = true
#   # final_snapshot_identifier = "test-db"
# }

# #----------------------- ECS -------------------------
# variable "instance_type" {
#   default = "t2.medium"
# }

# resource "aws_launch_configuration" "test-ecs-launch-configuration" {
#     name = "test-ecs-launch-configuration"
#     image_id = "ami-aff65ad2" #ECS AMI for us-east-1
#     instance_type = var.instance_type 
#     security_groups = [aws_security_group.sg_for_ec2_instances.id]
#     #iam_instance_profile = aws_iam_instance_profile.ecs-instance-profile.id
#     iam_instance_profile = "arn:aws:iam::064777359940:instance-profile/ECS-APP-Role" #hardcoded 
#     root_block_device {
#         volume_type = "standard"
#         volume_size = 100
#         delete_on_termination = true
#     }

#     lifecycle {
#         create_before_destroy = true
#     }

#     associate_public_ip_address = "true"
#     key_name = "MyKeyPair"

#     # register the cluster name with ecs-agent which will in turn coord
#     # with the AWS api about the cluster
#     #
#     user_data                   = <<EOF
#                                   #!/bin/bash
#                                   echo ECS_CLUSTER=${var.ecs_cluster_name} >> /etc/ecs/ecs.config
#                                   EOF
# }


# resource "aws_autoscaling_group" "test-ecs-autoscaling-group" {
#     name = "test-ecs-autoscaling-group"
#     max_size = "3"
#     min_size = "1"
#     desired_capacity = "2"

#     vpc_zone_identifier = module.vpc.public_subnets 
#     launch_configuration = aws_launch_configuration.test-ecs-launch-configuration.name
#     # health_check_type = "ELB"
#     health_check_type = "EC2"

#         tag {
#             key = "Name"
#             value = "Test-ECS-cluster"
#             propagate_at_launch = true
#         }
# }

# resource "aws_ecs_cluster" "test-ecs-cluster" {
#     name = var.ecs_cluster_name
# }
#----------------------- ECS -------------------------
#------------ IAM Roles --------------
# resource "aws_iam_role" "ecs-instance-role" {
#     name = "ecs-instance-role"
#     path = "/"
#     assume_role_policy = data.aws_iam_policy_document.ecs-instance-policy.json
# }

# data "aws_iam_policy_document" "ecs-instance-policy" {
# statement {
#     actions = ["sts:AssumeRole"]

#         principals {
#             type = "Service"
#             identifiers = ["ec2.amazonaws.com"]
#         }
#     }
# }

# resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
#     role = aws_iam_role.ecs-instance-role.name
#     policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs-instance-profile" {
# name = "ecs-instance-profile"
# path = "/"
# role = aws_iam_role.ecs-instance-role.id
#     provisioner "local-exec" {
#         command = "sleep 60"
#     }
# }

# resource "aws_iam_role" "ecs-service-role" {
#     name = "ecs-service-role"
#     path = "/"
#     assume_role_policy = data.aws_iam_policy_document.ecs-service-policy.json
# }

# resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
#     role = aws_iam_role.ecs-service-role.name
#     policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
# }

# data "aws_iam_policy_document" "ecs-service-policy" {
#     statement {
#         actions = ["sts:AssumeRole"]

#         principals {
#             type = "Service"
#             identifiers = ["ecs.amazonaws.com"]
#         }
#     }
# }
#-------------------- End IAM Roles ------------
#
# need to add security group config
# so that we can ssh into an ecs host from bastion box
#

# resource "aws_security_group" "instance" {
#     vpc_id = module.vpc.vpc_id
#     ingress {
#         from_port = var.ec2_test_port
#         to_port = var.ec2_test_port
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
 

#     egress {
#         from_port = 0
#         to_port = 0
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
# }

# variable "ec2_test_port" {
#   default="8080"
# }

# resource "aws_instance" "example" {
#     ami                 = "ami-00af20496ceb57b55"
#     instance_type       = "t2.nano"
#     # vpc_security_group_ids      = [aws_security_group.instance.id]
#     security_groups = [aws_security_group.instance.id]
#     subnet_id = module.vpc.public_subnets[0]
#     associate_public_ip_address = true
#     key_name = "MyKeyPair"

#     # user_data = file("web.sh")
#     user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello My World" > index.html
#               nohup busybox httpd -f -p "${var.ec2_test_port}" &
#               EOF


#     root_block_device {
#         volume_type           = "gp2"
#         volume_size           = 40
#         delete_on_termination = true
#     }

#     lifecycle {
#         create_before_destroy = true
#     }
#     tags = {
#             name = "test-aws-instance"
#     }
# }

# resource "aws_db_instance" "postgres" {
#   allocated_storage    = 20
#   storage_type         = "gp2"
#   engine               = "postgres"
#   # engine_version       = "5.7"
#   instance_class       = "db.t2.micro"
#   name                 = "foo"
#   username             = "foo"
#   password             = "Pa$$w0rd"
#   skip_final_snapshot = true
#   final_snapshot_identifier = "2016-03-02-09-09"
# }
# resource "aws_db_instance" "dev_db" {
#     identifier = "dev"
#     allocated_storage    = 100
#     storage_type         = "gp2"
#     engine               = "postgres"
#     engine_version       = "10.9"
#     port                 = 1433
#     instance_class       = "db.t3.medium"
#     name                 = "dev"
#     username             = "dev"
#     password             = "mydevpassword"
#     parameter_group_name = "postgress10"
#     tags = {
#         Name = "dev"
#     }
#     skip_final_snapshot = true
# }



# provider "postgresql" {
#   alias    = "app_db_master"
#   host     = aws_db_instance.mydb1.address
#   username = aws_db_instance.mydb1.username
#   password = aws_db_instance.mydb1.password
#   sslmode  = "require"
# }

# resource "postgresql_database" "ext" {
#   provider          = "postgresql.app_db_master"
#   name              = "test-ext"
#   owner             = postgresql_role.role.name
#   lc_collate        = "en_US.UTF-8"
#   lc_ctype          = "en_US.UTF-8"
#   connection_limit  = -1
#   allow_connections = true
# }

# resource "postgresql_role" "role" {
#   provider         = postgresql.app_db_master
#   name             = "test"
#   login            = true
#   password         = "test"
#   connection_limit = -1
# }

# data "aws_ecs_task_definition" "one" {
#     task_definition = "${aws_ecs_task_definition.one.family}"
#     depends_on = [aws_ecs_task_definition.one]
# }
#----------------------- ECS Service ------------------------

# resource "aws_ecs_task_definition" "one" {
#     family = "one-family"
#     # container_definitions = file("task_wp2.json")
#     container_definitions = <<DEFINITION
#     [
#       {
#         "name": "wordpress",
#         "image": "cengica/aws_test",
#         "essential": true,
#         "memory": 128,
#         "cpu": 128,
#         "portMappings": [ 
#             { "hostPort": 80, "containerPort": 8080, "protocol": "tcp" } 
#         ] ,
      
#         "environment": [
#           {
#             "name": "POSTGRES_USER",
#             "value": "foo"
#           },
#           {
#             "name": "POSTGRES_DB",
#             "value": "foo"
#           },
#           {
#             "name": "POSTGRES_PW",
#             "value": "Pa$$w0rd"
#           },
#           {
#             "name": "POSTGRES_URL",
#             "value": "aws_db_instance.postgres.address"
#           }
#         ]
#       }
#   ]
#   DEFINITION
# }

# resource "aws_ecs_service" "one-ecs-service" {
#     name = "one-service"
#     cluster = aws_ecs_cluster.test-ecs-cluster.id
#     #task_definition = "${aws_ecs_task_definition.one.family}:${max("${aws_ecs_task_definition.test.revision}", "${data.aws_ecs_task_definition.test.revision}")}"
#     task_definition = aws_ecs_task_definition.one.arn
#     desired_count = 2
#     # iam_role = aws_iam_role.ecs-service-role.name
#     # iam_role = "ECS-APP-Role" #hardcoded iam_role

#     load_balancer {
#         target_group_arn = aws_alb_target_group.one.id
#         container_name = var.container_name 
#         container_port = var.container_port
#     }

#     depends_on = [
#         aws_alb_listener.one,
#     ]
# }

# resource "aws_alb_target_group" "one" {
#     name = "my-alb-group"
#     port = 80
#     protocol = "HTTP"
#     vpc_id = module.vpc.vpc_id
# }

# resource "aws_alb" "one" {
#     name = "one-alb-ecs"
#     subnets = module.vpc.public_subnets
#     security_groups = [aws_security_group.sg_for_ec2_instances.id, module.vpc.default_security_group_id]
#     # security_groups = [module.vpc.default_security_group_id]
# }

# resource "aws_alb_listener" "one" {
#     load_balancer_arn = aws_alb.one.id
#     port = "80"
#     protocol = "HTTP"

#     default_action {
#         target_group_arn = aws_alb_target_group.one.id
#         type = "forward"
#     }
# }

#----------------------------------
# resource "aws_alb_listener" "wp" {
#     load_balancer_arn = aws_alb.main.id
#     port = "8080"
#     protocol = "HTTP"

#     default_action {
#       type = "fixed-response"

#       fixed_response {
#         content_type = "text/plain"
#         message_body = "More than this 8080 Fixed response content"
#         status_code  = "200"
#       }
#   }
# }
#--------------------------

# output "dns_name" {
#   value = aws_alb.one.dns_name
# }
#----------------------- ECS Service ------------------------
# module "ecs-service1" {
#   source = "./terraform-ecs-service/"

#   container_port = "8080"
#   container_name = "test-ME-app"
#   docker_image = "cengica/aws_test"
#   app_name = "test-my-app"
#   # cluster_id = aws_ecs_cluster.test-ecs-cluster.id
#   cluster_id = module.ecs-cluster.ecs_cluster_id
#   vpc = module.vpc
#   security_group_id = aws_security_group.sg_for_ec2_instances.id
# }

# output "dns_name1" {
#   value = module.ecs-service1.dns_name
# }