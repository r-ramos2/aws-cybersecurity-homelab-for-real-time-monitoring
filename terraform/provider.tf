// provider.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws    = { source = "hashicorp/aws",    version = ">= 4.0" }
    tls    = { source = "hashicorp/tls"    }
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local"  }
  }
}

# Configure AWS provider
provider "aws" {
  region = var.region
}
