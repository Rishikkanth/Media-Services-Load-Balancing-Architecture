variable "project"      { type = string }
variable "vpc_id"       { type = string }
variable "private_subnets" { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "certificate_arn" { type = string } # ACM cert for media.example.com
variable "cluster_name" { type = string }
variable "tg_healthy_path" { type = string default = "/status" }

