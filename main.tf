####################################################################
# HaloArchives — root composition
#
# Data flow:
#   producer -> API Gateway -> ingest Lambda -> S3 archive bucket
#                                   |
#   S3 ObjectCreated event -> SQS  -> catalog_writer Lambda -> DynamoDB
#
#   retrieval request -> API -> Step Functions:
#       initiate (Glacier restore) -> wait/poll -> finalize (presign) -> notify
#
# Everything is KMS-encrypted, least-privilege IAM, and observable.
####################################################################

module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  account_id  = local.account_id
  region      = var.region
  tags        = local.common_tags
}

module "networking" {
  source = "./modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
  tags        = local.common_tags
}

module "storage" {
  source = "./modules/storage"
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  name_prefix                = local.name_prefix
  kms_key_arn                = module.security.kms_key_arn
  replica_kms_key_arn        = module.security.replica_kms_key_arn
  enable_object_lock         = var.enable_object_lock
  object_lock_retention_days = var.object_lock_retention_days
  lifecycle_transitions      = var.lifecycle_transitions
  enable_replication         = var.enable_replication
  tags                       = local.common_tags
}

module "catalog" {
  source = "./modules/catalog"

  name_prefix           = local.name_prefix
  kms_key_arn           = module.security.kms_key_arn
  billing_mode          = var.catalog_billing_mode
  point_in_time_recovery = var.catalog_point_in_time_recovery
  tags                  = local.common_tags
}

module "ingestion" {
  source = "./modules/ingestion"

  name_prefix          = local.name_prefix
  kms_key_arn          = module.security.kms_key_arn
  archive_bucket_arn   = module.storage.archive_bucket_arn
  archive_bucket_id    = module.storage.archive_bucket_id
  catalog_table_arn    = module.catalog.table_arn
  catalog_table_name   = module.catalog.table_name
  lambda_runtime       = var.lambda_runtime
  lambda_architecture  = var.lambda_architecture
  log_retention_days   = var.lambda_log_retention_days
  subnet_ids           = module.networking.private_subnet_ids
  security_group_id    = module.networking.lambda_security_group_id
  tags                 = local.common_tags
}

module "retrieval" {
  source = "./modules/retrieval"

  name_prefix         = local.name_prefix
  kms_key_arn         = module.security.kms_key_arn
  archive_bucket_arn  = module.storage.archive_bucket_arn
  archive_bucket_id   = module.storage.archive_bucket_id
  catalog_table_arn   = module.catalog.table_arn
  catalog_table_name  = module.catalog.table_name
  lambda_runtime      = var.lambda_runtime
  lambda_architecture = var.lambda_architecture
  log_retention_days  = var.lambda_log_retention_days
  tags                = local.common_tags
}

module "api" {
  source = "./modules/api"

  name_prefix               = local.name_prefix
  ingest_lambda_arn         = module.ingestion.ingest_lambda_arn
  ingest_lambda_name        = module.ingestion.ingest_lambda_name
  retrieval_state_machine   = module.retrieval.state_machine_arn
  retrieval_start_role_arn  = module.retrieval.api_start_role_arn
  log_retention_days        = var.lambda_log_retention_days
  tags                      = local.common_tags
}

module "observability" {
  source = "./modules/observability"

  name_prefix                   = local.name_prefix
  region                        = var.region
  alarm_email                   = var.alarm_sns_email
  kms_key_arn                   = module.security.kms_key_arn
  ingestion_queue_name          = module.ingestion.queue_name
  ingestion_dlq_name            = module.ingestion.dlq_name
  ingestion_dlq_threshold       = var.ingestion_dlq_alarm_threshold
  lambda_function_names = [
    module.ingestion.ingest_lambda_name,
    module.ingestion.catalog_writer_lambda_name,
    module.retrieval.initiate_lambda_name,
    module.retrieval.finalize_lambda_name,
  ]
  catalog_table_name = module.catalog.table_name
  api_id             = module.api.api_id
  tags               = local.common_tags
}
