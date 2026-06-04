variable "aws_region" {
  description = "AWS Region"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 Instance Size"
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS Key Pair Name"
}

variable "project_name" {
  description = "Project Name"
  default     = "portfolio"
}