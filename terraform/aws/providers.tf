terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = local.region
  access_key = "CHANGE_ME"
  secret_key = "CHANGE_ME"
}
