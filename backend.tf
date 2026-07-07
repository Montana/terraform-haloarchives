# Remote state. Values are intentionally left partial and supplied at init time:
#
#   terraform init \
#     -backend-config="bucket=haloarchives-tfstate-<acct>" \
#     -backend-config="key=haloarchives/${ENV}/terraform.tfstate" \
#     -backend-config="region=us-east-1" \
#     -backend-config="dynamodb_table=haloarchives-tflock"
#
# This keeps the state bucket/key out of version control and lets one config
# serve every environment. Bootstrap the bucket + lock table once, out of band.
terraform {
  backend "s3" {
    encrypt = true
  }
}
