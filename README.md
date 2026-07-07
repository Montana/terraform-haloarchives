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

Say if I looked up `Eclipse` for Halo 3, I'd get:

<img width="916" height="464" alt="Screenshot 2026-07-07 at 9 30 40 AM" src="https://github.com/user-attachments/assets/17de196b-c7b8-4416-a5f8-bdc2d31d2d52" />

<br>In the logs it would look like:</br>

```tf
Searched player Eclipse — game #1300157218 (MLG Team King, Construct,
2009-08-14). BLUE team; 26 kills / 15 deaths, +11, 19 assists, K/D 1.73.

Content
```
It would then render: 

<br><img width="836" height="783" alt="carnage_report_eclipse_highlighted" src="https://github.com/user-attachments/assets/d5beab14-a64a-4efa-b78c-6ce7ff924b97" /></br>

We can do the same for let's say `Robbie Bizzle`:

<img width="1294" height="981" alt="Screenshot 2026-07-07 at 9 48 02 AM" src="https://github.com/user-attachments/assets/ce2ac34e-a725-4914-97f1-4b1a3f8f44d4" />

Once a game is selected: 

<img width="839" height="788" alt="carnage_report_robbie_bizzle_highlighted" src="https://github.com/user-attachments/assets/6aedf110-e5ec-494f-a477-9615e544b38a" />

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
