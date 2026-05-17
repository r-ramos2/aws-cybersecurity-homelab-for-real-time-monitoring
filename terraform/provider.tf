terraform {
  required_version = ">= 1.5.0"

  # Uncomment and configure to store state remotely.
  # This keeps the generated SSH private key out of a local plaintext file
  # and adds locking to prevent concurrent applies.
  #
  # Prerequisites:
  #   aws s3api create-bucket --bucket <bucket> --region us-east-1
  #   aws s3api put-bucket-encryption ...   (enable SSE-S3 or SSE-KMS)
  #   aws dynamodb create-table --table-name terraform-state-lock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "aws-cybersecurity-homelab/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
    # local provider removed — no local_file resources are used in this module.
    # Add it back if you need to write the SSH key to disk via local_sensitive_file.
  }
}

provider "aws" {
  region = var.region
}
