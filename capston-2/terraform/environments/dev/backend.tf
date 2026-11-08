terraform {
  backend "s3" {
    bucket       = "capston-2-terraform-state-bucket-fouad"
    key          = "eks/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
