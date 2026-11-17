
# Terraform Remote State with Amazon S3

## 1. Overview

This document explains how remote state management was configured for the AWS Infrastructure Automation project using Terraform and Amazon S3.

By default, Terraform stores its state locally in a file named `terraform.tfstate`. For this project, we migrated the state to an Amazon S3 bucket so that the state is stored remotely.

### Why use remote state?

- **Centralised storage:** Terraform state is stored in an S3 bucket instead of an individual computer.
- **State locking:** Prevents multiple Terraform operations from modifying the state simultaneously.
- **Versioning:** Allows previous versions of the state file to be recovered.
- **Encryption:** Protects state data at rest.

## 2. Initial Environment

The project was deployed in AWS using the following configuration:

| Item | Configuration |
|---|---|
| Cloud provider | AWS |
| Region | ap-southeast-2 (Sydney) |
| Infrastructure as Code | Terraform |
| Terraform version | 1.17.1 |
| AWS provider | hashicorp/aws v6.73.0 |
| VPC CIDR | 10.30.0.0/16 |
| Managed resources | 13 |

The infrastructure includes:
- 1 VPC
- 2 public subnets
- 2 private subnets
- 1 Internet Gateway
- 2 route tables
- 4 route table associations
- 1 security group

## 3. Create the S3 Bucket

An S3 bucket was created specifically to store Terraform state.

The bucket name must be globally unique.

```powershell
aws s3api create-bucket `
  --bucket terraform-state-jared-366554472163-ap-southeast-2 `
  --region ap-southeast-2 `
  --create-bucket-configuration LocationConstraint=ap-southeast-2
```

The bucket was created in the Sydney region (`ap-southeast-2`).


## 4. Secure the S3 Bucket

Terraform state files may contain sensitive infrastructure information. Therefore, the S3 bucket was configured with additional security controls.

### 4.1 Block Public Access

All four S3 Block Public Access settings were enabled.

```powershell
aws s3api put-public-access-block `
  --bucket terraform-state-jared-366554472163-ap-southeast-2 `
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
  --region ap-southeast-2
```

This prevents the bucket and its contents from being made publicly accessible through ACLs or bucket policies.

### 4.2 Enable Bucket Versioning

Versioning was enabled to maintain previous versions of the Terraform state file.

```powershell
aws s3api put-bucket-versioning `
  --bucket terraform-state-jared-366554472163-ap-southeast-2 `
  --versioning-configuration Status=Enabled `
  --region ap-southeast-2
```

Versioning helps recover an earlier state version if the current state is accidentally modified or deleted.

### 4.3 Configure Default Encryption

Default server-side encryption was configured using SSE-S3 (AES256).

First, a temporary JSON configuration file named `s3-encryption.json` was created:

```json
{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }
  ]
}
```

The encryption configuration was then applied:

```powershell
aws s3api put-bucket-encryption `
  --bucket terraform-state-jared-366554472163-ap-southeast-2 `
  --server-side-encryption-configuration file://s3-encryption.json `
  --region ap-southeast-2
```

The bucket encryption was verified using:

```powershell
aws s3api get-bucket-encryption `
  --bucket terraform-state-jared-366554472163-ap-southeast-2 `
  --region ap-southeast-2
```

The result confirmed that AES256 encryption was enabled.

After configuration, the temporary JSON file was removed:

```powershell
Remove-Item .\s3-encryption.json
```


## 5. Configure the Terraform S3 Backend

After preparing the S3 bucket, a new file named `backend.tf` was created in the Terraform project root directory.

The file contains the following configuration:

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-jared-366554472163-ap-southeast-2"
    key          = "terraform/state/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

### Configuration explanation

| Setting | Purpose |
|---|---|
| `bucket` | Specifies the S3 bucket used to store Terraform state. |
| `key` | Defines the object path and filename of the state file inside the bucket. |
| `region` | Specifies the AWS region where the bucket exists. |
| `encrypt` | Enables encryption for the state object stored in S3. |
| `use_lockfile` | Enables native S3 state locking using a `.tflock` file. |

### Important considerations

- The S3 bucket must exist before Terraform initializes the backend.
- AWS credentials must have the required permissions to access the bucket.
- The backend configuration does not create the S3 bucket automatically.
- Native S3 lockfile support means a separate DynamoDB locking table is not required.


## 6. Migrate Existing Terraform State to S3

Before configuring the S3 backend, Terraform stored the infrastructure state locally.

After adding `backend.tf`, the existing state was migrated to the remote S3 backend.

The following command was executed from the project root directory:

```powershell
terraform init -migrate-state
```

### What happened during migration?

1. Terraform detected the new S3 backend configuration.
2. Terraform identified the existing local state file.
3. Terraform prompted to migrate the existing state to the new backend.
4. The migration was confirmed.
5. Terraform initialized the S3 backend successfully.

The migration preserved the existing infrastructure state without recreating the AWS resources.

### Why use `-migrate-state`?

The `-migrate-state` option instructs Terraform to copy existing state data to the newly configured backend.

This is important when moving an existing project from local state storage to remote state storage.

## 7. Verify Remote State Migration

After migration, the Terraform state was checked using:

```powershell
terraform state list
```

The command displayed the existing 13 managed resources, confirming that Terraform could still access the infrastructure state.

Next, the S3 bucket was checked:

```powershell
aws s3 ls s3://terraform-state-jared-366554472163-ap-southeast-2/terraform/state/ --region ap-southeast-2
```

The output showed:

```text
terraform.tfstate
```

This confirmed that the Terraform state file was successfully stored in Amazon S3.


## 8. Test Terraform State Locking

Terraform state locking helps prevent multiple users or Terraform processes from modifying the same state simultaneously.

Since the S3 backend was configured with:

```hcl
use_lockfile = true
```

Terraform automatically creates a temporary `.tflock` object in S3 while performing operations that require state locking.

### 8.1 Run Terraform Plan

The following command was executed:

```powershell
terraform plan
```

Terraform successfully:
- Refreshed the existing 13 managed resources.
- Acquired the remote state lock.
- Compared the actual AWS infrastructure against the Terraform configuration.
- Reported that no changes were required.
- Released the state lock after completing the operation.

The output confirmed:

```text
No changes. Your infrastructure matches the configuration.
Releasing state lock...
```

### 8.2 Verify Lock Release

The S3 state directory was checked again:

```powershell
aws s3 ls s3://terraform-state-jared-366554472163-ap-southeast-2/terraform/state/ --region ap-southeast-2
```

Only `terraform.tfstate` remained. The temporary `.tflock` file was no longer present, confirming that the lock had been released.

## 9. Update GitHub Repository

After configuring the remote backend, the `backend.tf` file was added to the Git repository.

The following Git commands were executed:

```powershell
git add backend.tf

git commit -m "Configure S3 remote backend with state locking"

git push
```

The `backend.tf` configuration was successfully pushed to the GitHub repository.

**Important:** Terraform state files (`*.tfstate` and `*.tfstate.*`) must not be committed to GitHub because they may contain sensitive information.

## 10. Final Implementation Summary

The remote state implementation was completed successfully.

| Component | Final Status |
|---|---|
| S3 bucket | Created |
| Block Public Access | Enabled |
| Bucket versioning | Enabled |
| Default encryption | SSE-S3 (AES256) |
| Terraform S3 backend | Configured |
| Existing state migration | Successful |
| Remote state verification | Successful |
| State locking | Tested successfully |
| GitHub backend configuration | Pushed successfully |

The Terraform project now uses Amazon S3 as its remote state backend with native S3 state locking.



## 11. Security Considerations and Best Practices

When using Amazon S3 for Terraform remote state, the following practices should be maintained:

- Keep S3 Block Public Access enabled.
- Enable bucket versioning to support state recovery.
- Enable encryption at rest.
- Apply least-privilege IAM permissions to users and roles accessing the state bucket.
- Never commit Terraform state files or sensitive credentials to GitHub.
- Use state locking to prevent concurrent state modifications.
- Restrict access to the S3 bucket because Terraform state may contain sensitive information.

## 12. Learning Outcomes

Through this hands-on implementation, the following concepts were practised:

1. Creating and configuring an Amazon S3 bucket using AWS CLI.
2. Applying S3 security controls, including public access blocking, versioning and encryption.
3. Configuring an S3 backend in Terraform.
4. Migrating existing local Terraform state to remote storage.
5. Understanding native S3 state locking using `use_lockfile`.
6. Verifying remote state storage and Terraform operations.
7. Managing Terraform configuration and documentation through Git and GitHub.

## 13. References

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)
- [Amazon S3 User Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)
- [Amazon S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [Amazon S3 Default Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html)
