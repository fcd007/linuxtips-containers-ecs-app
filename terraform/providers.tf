provider "aws" {
  region = var.region

  default_tags {
    tags = {
      finops      = "true"
      environment = "dev"
    }
  }
}