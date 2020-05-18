variable "container_port" {
  description = "Container Application port Exposed in Dockerfile  "
}

variable "app_name" {
       description = "Name of application used for Application Load Balancers"
}
variable "container_name" {
       description = "Name of container image"
}

variable "docker_image" {
       description = "URL of Docker image"
}
variable "desired_count" {
  default = 2
  description = "Number of Docker containers"
}

variable "cluster_id" {
}

variable "vpc" {
  
}
variable "security_group_id" {
}

# variable "postgres_address"{
       
# }


