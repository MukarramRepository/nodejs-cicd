terraform {

  backend "s3" {
    bucket         = "terraform-nodejs-state-app"
    key            = "nodejs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }

}