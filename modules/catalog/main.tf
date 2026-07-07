# Single-table design:
#   PK = "ARCHIVE#<archive_id>"        SK = "META" | "OBJECT#<object_key>"
#   GSI1 (status-index): status + created_at  -> query by lifecycle state
#   GSI2 (owner-index):  owner  + created_at  -> query a tenant's archives
resource "aws_dynamodb_table" "catalog" {
  name         = "${var.name_prefix}-catalog"
  billing_mode = var.billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  # Only set capacity when provisioned; ignored under PAY_PER_REQUEST.
  read_capacity  = var.billing_mode == "PROVISIONED" ? 10 : null
  write_capacity = var.billing_mode == "PROVISIONED" ? 10 : null

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "created_at"
    type = "S"
  }
  attribute {
    name = "owner"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? 5 : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? 5 : null
  }

  global_secondary_index {
    name            = "owner-index"
    hash_key        = "owner"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? 5 : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? 5 : null
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  deletion_protection_enabled = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-catalog" })
}
