# HaloArchives — Terraform

A modular, multi-environment AWS archival platform: WORM object storage with
tiered Glacier lifecycle, a DynamoDB catalog, event-driven ingestion, and
asynchronous restore workflows fronted by an HTTP API.

> Assumes AWS. If you meant GCP/Azure or a non-cloud target, the module
> boundaries carry over but the resources would be swapped out.

## Architecture

```
              ┌─────────────┐   POST /archives    ┌──────────────┐
   producer ──▶ API Gateway ├────────────────────▶│ ingest λ     │
              │  (HTTP API) │                      │ (presign PUT)│
              └──────┬──────┘                      └──────┬───────┘
                     │ POST /retrievals                   │ seed META
                     ▼                                    ▼
          ┌──────────────────┐                    ┌───────────────┐
          │ Step Functions   │                    │  S3 archive    │
          │ initiate→wait→   │   ObjectCreated     │  bucket (WORM) │
          │ poll→finalize    │◀───────┐            └──────┬────────┘
          └────────┬─────────┘        │ presign GET       │ event
                   │ RestoreObject    │                   ▼
                   ▼                  │            ┌──────────────┐
          (Glacier / Deep Archive)   └────────────│ SQS ─► catalog│
                                                   │ writer λ      │
                                                   └──────┬────────┘
                                                          ▼
                                                  ┌────────────────┐
                                                  │ DynamoDB catalog│
                                                  │ (GSIs, stream,  │
                                                  │  PITR, TTL)     │
                                                  └────────────────┘
```

## Modules

| Module          | Responsibility |
|-----------------|----------------|
| `security`      | Customer-managed KMS keys (primary + replica), key policy |
| `networking`    | VPC, private subnets, gateway + interface VPC endpoints, Lambda SG |
| `storage`       | Archive bucket (versioning, Object Lock, tiered lifecycle, TLS-only policy, access logs), optional cross-region replication |
| `catalog`       | DynamoDB single-table catalog with two GSIs, stream, PITR, TTL |
| `ingestion`     | SQS + DLQ, `ingest` and `catalog_writer` Lambdas, S3→SQS notifications, least-privilege IAM |
| `retrieval`     | `initiate`/`finalize` Lambdas and a Step Functions state machine for async Glacier restore |
| `api`           | HTTP API Gateway with a Lambda proxy route and a Step Functions service integration |
| `observability` | Alarm SNS topic, CloudWatch alarms (DLQ depth, Lambda errors, DDB throttles), dashboard |

## Layout

```
.
├── versions.tf providers.tf backend.tf   # pinning, providers, remote state
├── variables.tf main.tf outputs.tf       # root composition
├── environments/{dev,staging,prod}.tfvars
├── src/                                   # Lambda handler sources (zipped by archive_file)
└── modules/…                              # the eight modules above
```

## Usage

Bootstrap the state backend once (an S3 bucket + a DynamoDB lock table), then:

```bash
terraform init \
  -backend-config="bucket=haloarchives-tfstate-<acct>" \
  -backend-config="key=haloarchives/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=haloarchives-tflock"

terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

## Notes & knobs

- **Object Lock is immutable per bucket.** It's off in `dev` (so the stack tears
  down cleanly) and on in `staging`/`prod` in COMPLIANCE mode. Objects under a
  COMPLIANCE retention window cannot be deleted by anyone, including root.
- **Lifecycle tiering** is data-driven via `lifecycle_transitions`
  (default 30d → STANDARD_IA, 90d → GLACIER, 365d → DEEP_ARCHIVE).
- **Cross-region replication** is opt-in (`enable_replication`) and only wired
  in `prod` by default; it provisions the replica bucket, KMS key, and IAM role.
- **Glacier retrieval is asynchronous** — the state machine issues `RestoreObject`,
  waits, polls object head for restore completion, then presigns a time-limited
  download URL. Wait/poll timing is in `modules/retrieval/main.tf`.
- Lambdas run in private subnets with no NAT; all AWS API traffic goes through
  gateway/interface VPC endpoints.
- The Lambda handlers in `src/` are working reference implementations, not
  production-hardened (no auth on the API, minimal validation). Wire an authorizer
  (Cognito/JWT/IAM) onto the API routes before exposing it.
```
