# data "aws_ecs_task_definition" "one" {
#     task_definition = "${aws_ecs_task_definition.one.family}"
#     depends_on = [aws_ecs_task_definition.one]
# }

resource "aws_ecs_task_definition" "one" {
    family = var.container_name
    # container_definitions = file("task_wp2.json")
    container_definitions = <<DEFINITION
    [
      {
        "name": "${var.container_name}",
        "image": "${var.docker_image}",
        "essential": true,
        "memory": 128,
        "cpu": 128,
        "portMappings": [ 
            { "hostPort": 0, 
              "containerPort": ${var.container_port}, 
              "protocol": "tcp" } 
        ] ,
      
        "environment": [
          {
          "name": "SECRETS_PATH",
          "value": "dmiint-dmicreds/sms-serverless-dev.env"
          },
          
          {
            "test": "lalalla",
            "pest": "34343"
          }
          # {
          #   "name": "POSTGRES_URL",
          #   "value": "${var.postgres_address}"
          # }
        ]
      }
  ]
  DEFINITION
}

resource "aws_ecs_service" "one-ecs-service" {
    name = "Xone-service"
    cluster = var.cluster_id
    #task_definition = "${aws_ecs_task_definition.one.family}:${max("${aws_ecs_task_definition.test.revision}", "${data.aws_ecs_task_definition.test.revision}")}"
    task_definition = aws_ecs_task_definition.one.arn
    desired_count = var.desired_count
    # iam_role = aws_iam_role.ecs-service-role.name
    # iam_role = "ECS-APP-Role" #hardcoded iam_role

    load_balancer {
        target_group_arn = aws_alb_target_group.one.id
        container_name = var.container_name 
        container_port = var.container_port
    }

    depends_on = [
        aws_alb_listener.one,
    ]
}

resource "aws_alb_target_group" "one" {
    name = "Xone-alb-group"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc.vpc_id
}

resource "aws_alb" "one" {
    name = "Xone-alb-ecs"
    subnets = var.vpc.public_subnets
    security_groups = [var.security_group_id]
    # [aws_security_group.sg_for_ec2_instances.id, module.vpc.default_security_group_id]
    # security_groups = [module.vpc.default_security_group_id]
}

resource "aws_alb_listener" "one" {
    load_balancer_arn = aws_alb.one.id
    port = "80"
    protocol = "HTTP"

    default_action {
        target_group_arn = aws_alb_target_group.one.id
        type = "forward"
    }
}

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

