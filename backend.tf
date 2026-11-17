terraform {
  backend "s3" {
    bucket       = "terraform-state-jared-366554472163-ap-southeast-2"
    key          = "terraform/state/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}