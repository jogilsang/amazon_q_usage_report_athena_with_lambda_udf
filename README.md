# Amazon Q Developer Pro Usage Analytics with Athena & Lambda UDF

Automated solution for analyzing Amazon Q Developer Pro usage with Athena queries and Lambda UDF for Identity Center integration. This solution provides on-demand analytics without scheduled execution.

[한국어 문서](README_KR.md)

## 🏗️ Architecture

This solution uses **1 or 2 AWS accounts**:

1. **Q Account**: Where Amazon Q Developer Pro is enabled
   - Lambda function (usage analytics)
   - Athena (query execution)
   - S3 (report storage)
   - Java UDF (Identity Center integration)

2. **IAM Identity Center Account**: Where IAM Identity Center is located
   - Cross-account IAM Role (Identity Center read permissions)
   - Can be the same as Q Account or separate (typically Management/Payer account in AWS Organizations)

> **Note**: For single-account setup (Q and Identity Center in same account), run both scripts against the same account.

## 📋 Prerequisites

### Common
- Python 3.9+
- AWS CLI configured
- Maven (for Java UDF build)
- boto3 (`pip install boto3`)

### Q Account
- Amazon Q Developer Pro enabled
- Athena table configured (`q_user_analytics.user_reports`)
- S3 bucket for reports and Athena results

### IAM Identity Center Account
- IAM Identity Center enabled
- Can be Management/Payer account in AWS Organizations, or same as Q Account

## 🚀 Deployment

### Step 1: Configure

```bash
# Copy example config
cp config.json.example config.json

# Edit configuration
vi config.json
```

**config.json parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `udf_lambda_role_name` | IAM role name for Java UDF Lambda | `AthenaUDFForIAMIdentityCenterRole` |
| `lambda_region` | Lambda and Athena region | `us-east-1` |
| `identity_profile.account_id` | Identity Center account ID | `123456789012` |
| `identity_profile.account_role_name` | Cross-account role name | `IdentityCenter-ReadOnly-Role` |
| `identity_profile.external_id` | External ID for additional security (optional) | `""` or `"my-external-id"` |
| `identity_region` | Identity Center region | `ap-northeast-2` |
| `identity_store_id` | Identity Store ID (find in IAM Identity Center console) | `d-xxxxxxxxxx` |
| `athena_database` | Athena database name | `q_user_analytics` |
| `athena_table` | Athena table name | `user_reports` |
| `s3_data_bucket` | S3 bucket for Q usage data | `your-q-data-bucket` |
| `s3_results_bucket` | S3 bucket for Athena query results | `aws-athena-query-results-ACCOUNT_ID-REGION` |

> **Note**: `identity_store_id` can be found in IAM Identity Center console → Settings → Identity source

### Step 2: Deploy Q Account Lambda (Run First)

```bash
# Deploy Lambda function and resources
./deploy_q_account_java_udf.sh --profile YOUR_PROFILE
```

This automatically:
1. Builds Lambda package
2. Builds Java UDF
3. Creates IAM role with necessary permissions
4. Creates Lambda function

**Output**: Lambda function ARN and role name (needed for Step 4)

### Step 3: Setup Athena Database and Table

```bash
# Setup Athena resources (first time only)
./deploy_q_account_athena.sh --profile YOUR_PROFILE
```

This automatically:
1. Creates Athena query results S3 bucket (if needed)
2. Configures Athena workgroup output location
3. Creates Athena database (if not exists)
4. Creates Athena table using `sample_athena_create_table.sql`

> **Note**: Run this only once or when you need to recreate Athena resources.

### Step 4: Deploy IAM Identity Center Account

```bash
# Deploy Identity Center role
./deploy_iam_identity_center_account.sh --profile YOUR_IDENTITY_CENTER_PROFILE
```

**Input required**: Q Account ID (where Lambda is deployed)

This creates the cross-account IAM role for Identity Center access.

> **Note**: This can be the same account as Q Account if IAM Identity Center is enabled there, or a different account (typically Management/Payer account in AWS Organizations).

## 📁 Project Structure

```
amazon_q_usage_report_athena_with_lambda_udf/
├── deploy_q_account_java_udf.sh             # Java UDF Lambda deployment
├── deploy_q_account_athena.sh               # Athena database/table setup
├── deploy_iam_identity_center_account.sh    # IAM Identity Center role deployment
├── config.json.example                      # Configuration template
├── config.json                              # Your configuration (gitignored)
├── sample_athena_create_table.sql           # Athena table creation SQL
├── sample_queries_with_udf.sql              # Example Athena queries with UDF
├── DEPLOYMENT_ORDER.md                      # Deployment guide with architecture
├── DEPLOYMENT_CHECKLIST.md                  # Deployment checklist
├── java_udf/
│   └── identity-center-udf/                 # Athena UDF (Java)
│       ├── pom.xml                          # Maven configuration
│       └── src/main/java/                   # Java source code
└── README.md
```

### File Descriptions

| File | Purpose |
|------|---------|
| `deploy_q_account_java_udf.sh` | Deploys Java UDF Lambda function with IAM role creation and AssumeRole configuration |
| `deploy_q_account_athena.sh` | Sets up Athena database, table, and S3 buckets |
| `deploy_iam_identity_center_account.sh` | Creates cross-account IAM role for Identity Center access |
| `config.json` | Configuration file with account IDs, regions, and resource names |
| `config.json.example` | Template for configuration file |
| `sample_athena_create_table.sql` | SQL template for creating Athena table |
| `sample_queries_with_udf.sql` | 4 example Athena queries demonstrating UDF usage |
| `DEPLOYMENT_ORDER.md` | Complete deployment guide with architecture diagrams |
| `DEPLOYMENT_CHECKLIST.md` | Step-by-step deployment checklist |
| `java_udf/identity-center-udf/` | Java UDF project for converting UserId to UserName |

## ⚙️ Environment Variables (Lambda)

Automatically configured by deployment script:

| Variable | Description | Example |
|----------|-------------|---------|
| `IDENTITY_CENTER_REGION` | IAM Identity Center region | `ap-northeast-2` |
| `IDENTITY_CENTER_ACCOUNT_ID` | Payer account ID | `123456789012` |
| `CROSS_ACCOUNT_ROLE_NAME` | Cross-account role name | `IdentityCenter-ReadOnly-Role` |
| `ATHENA_REGION` | Athena region | `us-east-1` |
| `ATHENA_DATABASE` | Athena database | `q_user_analytics` |
| `ATHENA_TABLE` | Athena table | `user_reports` |
| `ATHENA_RESULTS_BUCKET` | Athena results S3 bucket | `my-bucket` |
| `S3_BUCKET` | Report storage S3 bucket | `my-bucket` |

## 📊 Generated Reports

### CSV File Structure
- **DisplayName**: User display name
- **UserName**: User login name
- **UserId**: Unique user ID
- **active_days**: Number of active days
- **46 feature metrics**: Chat, CodeFix, CodeReview, Dev, DocGeneration, InlineChat, Inline, TestGeneration, Transformation, etc.

### Storage Location
- **S3**: `s3://<bucket>/monthly-report/amazon_q_usage_YYYYMM_timestamp.csv`

## 🚀 Usage

### Manual Execution

```bash
# Invoke Lambda function
aws lambda invoke \
  --function-name amazon-q-athena-analytics \
  --region us-east-1 \
  response.json

# Check results
cat response.json
```

### View Logs

```bash
# Check CloudWatch Logs
aws logs tail /aws/lambda/amazon-q-athena-analytics --follow
```

## 🧪 Testing

### Test Lambda Function

```bash
# Manual invocation
aws lambda invoke \
  --function-name amazon-q-athena-analytics \
  --region us-east-1 \
  response.json

cat response.json
```

## ⚙️ Environment Variables (Lambda)

Automatically configured by deployment script:

| Variable | Description | Example |
|----------|-------------|---------|
| `IDENTITY_CENTER_REGION` | IAM Identity Center region | `ap-northeast-2` |
| `IDENTITY_CENTER_ACCOUNT_ID` | Payer account ID | `123456789012` |
| `CROSS_ACCOUNT_ROLE_NAME` | Cross-account role name | `IdentityCenter-ReadOnly-Role` |
| `ATHENA_REGION` | Athena region | `us-east-1` |
| `ATHENA_DATABASE` | Athena database | `q_user_analytics` |
| `ATHENA_TABLE` | Athena table | `user_reports` |
| `ATHENA_RESULTS_BUCKET` | Athena results S3 bucket | `my-bucket` |
| `S3_BUCKET` | Report storage S3 bucket | `my-bucket` |
| `SNS_EMAIL` | Email for notifications | `team@company.com` |

## 📊 Usage Examples

### Athena Query with UDF

The Java UDF Lambda function (`final-identity-udf`) converts UserId to UserName using IAM Identity Center API.

**Example Query:**
```sql
USING EXTERNAL FUNCTION getusername(user_id VARCHAR)
RETURNS VARCHAR
LAMBDA 'final-identity-udf'

SELECT 
    UserId,
    getusername(UserId) as UserName,
    COUNT(*) as record_count,
    SUM(Chat_MessagesSent) as total_messages,
    SUM(Dev_AcceptedLines) as total_accepted_lines
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'
GROUP BY UserId
ORDER BY total_messages DESC
LIMIT 10;
```

**Example Result:**
```
UserId                                  | UserName                    | record_count | total_messages | total_accepted_lines
----------------------------------------|----------------------------|--------------|----------------|---------------------
8488bd6c-5081-7061-3353-13643f204de9   | chogilsang@OOO.com    | 5            | 150            | 1200
```

**Key Points:**
- UDF function name must be **lowercase** in SQL (`getusername`, not `getUserName`)
- Lambda function name: `final-identity-udf`
- Returns user email from IAM Identity Center
- Caches results for performance

## 🔒 Security Considerations

### Least Privilege Principle
- IAM Identity Center account cross-account role has **Identity Center read-only** permissions
- External ID can be used for additional security

### Permission Scope
**Q Account Lambda**:
- Athena query execution
- S3 read/write (own bucket only)
- Cross-account role assume

**IAM Identity Center Account Role**:
- Identity Store read (`identitystore:ListUsers`, `identitystore:DescribeUser`)
- SSO Admin read (`sso-admin:ListInstances`)

### 2. Java UDF Build Failed
```bash
# Check Maven installation
mvn --version

# Resolve dependencies
cd java_udf/identity-center-udf
mvn dependency:resolve
```

### 3. Cross-Account Role Assume Failed
- Verify External ID (if used)
- Check Trust Policy includes Lambda role ARN
- Confirm IAM Identity Center is enabled

### 4. Athena Query Failed
- Verify table exists
- Check S3 bucket permissions
- Confirm Athena results bucket is configured

## 📞 Support

For issues or improvements, please create an issue.

---

**Version**: v1.0  
**Last Updated**: 2026-03-21
