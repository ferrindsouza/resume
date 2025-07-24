variable "region" {
  description = "the aws region"
  default = "us-east-1"
  type = string
}
variable "domain_name" {
    type = string
    description = "Name of the Domain"
}
variable "bucket_name" {
    type = string
    description = "Name of the bucket"
}
