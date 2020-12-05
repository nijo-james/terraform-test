variable "region" {
  default = "ap-southeast-1"
}

variable "awscreds" {
  default = "/homw/nijo/.aws/creds"
}

variable "awsprofile" {
  default = "my-terraform-admin"
}

variable "ec2-ami" {
  default = "ami-0007cf37783ff7e10"
}

variable "ec2-instancetype" {
  default = "t2.micro"
}

variable "ec2-availabilityzone" {
  default = "ap-southeast-1a"
} 

variable "ec2-privatekey" {
  default = "terraform-server"
} 

variable "rds-allocated_storage" {
  default = "20"
} 

variable "rds-engine" {
  default = "postgres"
} 
variable "dbname" {
  default = "testdb"
} 

variable "dbuser" {
  default = "testdbuser"
} 
variable "dbpassword" {
  default = "pwddbpass"
} 
variable "dbintancetype" {
  default = "db.t2.micro"
} 
variable "s3-bucket" {
  default = "terraform-s3-nijo-test"
}

variable "s3-bucket-object" {
  default = "/home/nijo/Documents/mydocs/terraform/index.html"
}