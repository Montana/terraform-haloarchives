provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# Secondary provider aliased to the replica region so the storage module can
# stand up cross-region replication for the archive bucket when enabled.
provider "aws" {
  alias  = "replica"
  region = var.replica_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    },
    var.additional_tags,
  )
}
