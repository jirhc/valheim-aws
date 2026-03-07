# Terraform State Locking with DynamoDB

## Why state locking?

When multiple people (or CI/CD pipelines) run `terraform plan` or `terraform apply` at the same time, they can corrupt the Terraform state file. **State locking** prevents this by using a DynamoDB table as a distributed lock.

When a Terraform operation starts, it writes a lock entry to the DynamoDB table. If another operation tries to run concurrently, it will see the lock and wait (or fail), preventing state corruption.

## How it works

```
┌──────────┐       ┌──────────────┐       ┌───────────────┐
│ Terraform│──────>│ S3 (state)   │       │ DynamoDB      │
│ CLI      │       │              │       │ (lock table)  │
│          │──────>│ tfstate file │       │               │
│          │       └──────────────┘       │ LockID (PK)   │
│          │──────────────────────────────>│ Info, Created │
│          │  acquire lock / release lock │               │
└──────────┘                              └───────────────┘
```

1. **Before** reading/writing state, Terraform acquires a lock in DynamoDB.
2. The lock entry contains: who locked, when, and the operation being performed.
3. **After** the operation completes (or fails), the lock is released.
4. If someone else tries to run Terraform while locked, they get a clear error message with details about who holds the lock.

## Setup instructions

### 1. Create the DynamoDB table

Run this once in the AWS Console or via CLI:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region <your-region>
```

> **Cost**: DynamoDB on-demand pricing is virtually free for this use case. A lock operation costs fractions of a cent. You'll likely spend less than $0.01/month.

### 2. Update backend configuration

In your `infra/deploy/config/backend.tf` file, add the `dynamodb_table` key:

```hcl
# bucket to store the server data
bucket         = "<your-bucket-name>"
# store the terraform state in S3
key            = "valheim-server/prod/terraform.tfstate"
# define a region
region         = "eu-west-3"
# enable state locking (optional but recommended)
dynamodb_table = "terraform-state-lock"
```

### 3. Re-initialize Terraform

After updating the backend config, re-run init:

```bash
./run-tf.sh init
```

Terraform will detect the new `dynamodb_table` setting and start using it for locking.

## Verifying it works

You can verify locking is active by running two Terraform operations simultaneously:

```bash
# Terminal 1
./run-tf.sh plan

# Terminal 2 (while terminal 1 is still running)
./run-tf.sh plan
# Expected: "Error acquiring the state lock" with details about who holds it
```

## Force-unlocking (emergency only)

If Terraform crashes mid-operation and leaves a stale lock:

```bash
terraform -chdir=./infra/deploy force-unlock <LOCK_ID>
```

> ⚠️ Only use this when you're **certain** no other Terraform operation is running.
