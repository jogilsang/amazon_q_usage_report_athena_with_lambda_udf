# Amazon Q Usage Analytics - Deployment Order

## Prerequisites
- AWS CLI configured with appropriate profiles
- Maven installed (for Java UDF build)
- jq installed (for JSON parsing)
- Configure `config.json` with your settings

## Deployment Steps

### 1. Deploy Java UDF Lambda (Athena Account)
```bash
./deploy_q_account_java_udf.sh <AWS_PROFILE>
```
**What it does:**
- Creates IAM role: `AthenaUDFForIAMIdentityCenterRole`
- Builds Java UDF with Maven
- Deploys Lambda function: `final-identity-udf`
- Configures AssumeRole for cross-account access

### 2. Deploy Athena Resources (Athena Account)
```bash
./deploy_q_account_athena.sh --profile <AWS_PROFILE>
```
**What it does:**
- Creates Athena database and table
- Uploads sample data to S3
- Configures query result location

### 3. Deploy IAM Identity Center Trust (Identity Center Account)
```bash
./deploy_iam_identity_center_account.sh --profile <AWS_PROFILE>
```
**What it does:**
- Creates IAM role: `IdentityCenter-ReadOnly-Role`
- Adds trust relationship for `AthenaUDFForIAMIdentityCenterRole`
- Attaches Identity Center read-only policies

## Architecture

```
┌─────────────────────────────────────┐
│   Athena Account (us-east-1)        │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Athena Query                 │  │
│  │ + UDF: getusername()         │  │
│  └──────────┬───────────────────┘  │
│             │                       │
│  ┌──────────▼───────────────────┐  │
│  │ Lambda: final-identity-udf   │  │
│  │ Role: AthenaUDFFor...Role    │  │
│  └──────────┬───────────────────┘  │
│             │ AssumeRole            │
└─────────────┼───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ Identity Center Account (ap-ne-2)   │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ IdentityCenter-ReadOnly-Role │  │
│  │ Trust: AthenaUDFFor...Role   │  │
│  └──────────┬───────────────────┘  │
│             │                       │
│  ┌──────────▼───────────────────┐  │
│  │ IAM Identity Center          │  │
│  │ (Identity Store API)         │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Single Account vs Cross-Account

### Single Account
- All resources in one account
- AssumeRole still used (best practice)
- `IDENTITY_CENTER_ACCOUNT_ID` = Lambda account ID

### Cross-Account
- Athena/Lambda in Account A
- Identity Center in Account B
- AssumeRole crosses account boundary
- Trust relationship required

## Testing

```sql
USING EXTERNAL FUNCTION getusername(user_id VARCHAR)
RETURNS VARCHAR
LAMBDA 'final-identity-udf'

SELECT 
    UserId,
    getusername(UserId) as UserName,
    COUNT(*) as active_days
FROM q_user_analytics.user_reports
GROUP BY UserId
LIMIT 5;
```

## Troubleshooting

### AssumeRole Permission Denied
- Check trust relationship in `IdentityCenter-ReadOnly-Role`
- Verify `AthenaUDFForIAMIdentityCenterRole` has AssumeRole policy
- Wait 10-30 seconds for IAM propagation

### UDF Method Not Found
- Method name must be lowercase: `getusername` not `getUserName`
- Check Lambda handler: `com.amazon.q.analytics.IdentityCenterUDF`

### OutOfMemoryError
- Increase Lambda memory to 512MB or higher
- Check CloudWatch Logs for detailed errors
