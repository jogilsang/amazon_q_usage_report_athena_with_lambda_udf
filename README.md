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
cd /Users/jogilsang/Documents/project_my/amazon_q_usage_report_athena_with_lambda_udf

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
./deploy_q_account.sh --profile YOUR_PROFILE
```

This automatically:
1. Builds Lambda package
2. Builds Java UDF
3. Creates IAM role with necessary permissions
4. Creates Lambda function
5. Uploads Java UDF to S3

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

## 🔧 Additional Setup

### 1. Athena Table Creation

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS q_user_analytics.user_reports (
  UserId STRING,
  Date STRING,
  Chat_AICodeLines INT,
  Chat_MessagesInteracted INT,
  -- Add other columns as needed
)
PARTITIONED BY (year STRING, month STRING, day STRING)
LOCATION 's3://your-bucket/amazon-q-data/'
TBLPROPERTIES ('has_encrypted_data'='false');
```

### 2. Java UDF Lambda Function (for Athena)

The Java UDF is automatically uploaded to S3. To use it in Athena queries:

```bash
# Create Lambda function for Athena UDF
aws lambda create-function \
  --function-name identity-center-udf \
  --runtime java11 \
  --role <Lambda-Role-ARN> \
  --handler com.amazon.q.analytics.IdentityCenterUDFHandler \
  --code S3Bucket=<bucket>,S3Key=athena-udf/identity-center-udf-1.0-SNAPSHOT.jar \
  --timeout 60 \
  --memory-size 512
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

### Test Cross-Account Role

```bash
# Test assume role from Q account
aws sts assume-role \
  --role-arn arn:aws:iam::<Identity-Center-Account-ID>:role/IdentityCenter-ReadOnly-Role \
  --role-session-name test-session \
  --profile <Q-account-profile>
```

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

## 🔄 Update Procedure

### Update Lambda Code Only

```bash
# Modify lambda/lambda_function.py
python3 deploy_q_account.py
# Existing function will be updated
```

### Update Configuration

```bash
# Modify config.json
python3 deploy_q_account.py
# Lambda environment variables will be updated
```

## 🐛 Troubleshooting

### 1. Lambda Package Build Failed
```bash
# Upgrade pip
pip install --upgrade pip

# Reinstall dependencies
pip install -r lambda/requirements.txt -t /tmp/test
```

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

## 📊 생성되는 리포트

### CSV 파일 구조
- **DisplayName**: 사용자 표시 이름
- **UserName**: 사용자 로그인 이름
- **UserId**: 고유 사용자 ID
- **active_days**: 활동 일수
- **46개 기능별 메트릭**: Chat, CodeFix, CodeReview, Dev, DocGeneration, InlineChat, Inline, TestGeneration, Transformation 등

### 저장 위치
- **S3**: `s3://<버킷이름>/amazon-q-reports/amazon_q_usage_YYYYMM_timestamp.csv`
- **이메일**: CSV 파일이 첨부된 이메일 자동 발송

## 🕐 실행 스케줄

- **실행 시간**: 매월 1일 오전 11시 (한국시간)
- **분석 대상**: 전월 데이터 (예: 2월 1일 실행 시 1월 데이터 분석)
- **EventBridge Scheduler**: `cron(0 2 1 * ? *)` (UTC)

## 🔧 추가 설정

### 1. SES 이메일 검증

```bash
# 발신자 이메일 검증
aws ses verify-email-identity --email-address admin@company.com --region us-east-1

# 수신자 이메일 검증 (샌드박스 모드인 경우)
aws ses verify-email-identity --email-address team@company.com --region us-east-1
```

### 2. Athena 테이블 생성

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS q_user_analytics.user_reports (
  -- 테이블 스키마 정의
)
LOCATION 's3://your-bucket/amazon-q-data/'
```

### 3. Java UDF Lambda 함수 생성 (Athena에서 사용)

```bash
# S3에 업로드된 JAR 파일을 사용하여 Lambda 함수 생성
aws lambda create-function \
  --function-name identity-center-udf \
  --runtime java11 \
  --role <Lambda 실행 역할 ARN> \
  --handler com.amazon.q.analytics.IdentityCenterUDFHandler \
  --code S3Bucket=<버킷>,S3Key=athena-udf/identity-center-udf-1.0-SNAPSHOT.jar \
  --timeout 60 \
  --memory-size 512
```

## 🧪 테스트 실행

### Lambda 함수 수동 실행

```bash
aws lambda invoke \
  --function-name <함수이름> \
  --region us-east-1 \
  --profile <프로필> \
  response.json

cat response.json
```

### Cross-account Role 테스트

```bash
# Q 계정에서 Payer 계정의 Role assume 테스트
aws sts assume-role \
  --role-arn arn:aws:iam::<Payer계정ID>:role/AmazonQAnalyticsCrossAccountRole \
  --role-session-name test-session \
  --external-id <Q계정ID>-amazon-q-analytics \
  --profile <Q계정프로필>
```

## 🔒 보안 고려사항

### 최소 권한 원칙
- Payer 계정의 Cross-account Role은 **Identity Center 읽기 전용** 권한만 부여
- External ID 사용으로 보안 강화

### 권한 범위
**Q 계정 Lambda**:
- Athena 쿼리 실행
- S3 읽기/쓰기 (자체 버킷만)
- SES 이메일 발송
- Cross-account Role assume

**Payer 계정 Role**:
- Identity Store 읽기 (`identitystore:ListUsers`, `identitystore:DescribeUser`)
- SSO Admin 읽기 (`sso-admin:ListInstances`)

## 🔄 업데이트 방법

### Lambda 코드만 업데이트

```bash
# lambda/lambda_function.py 수정 후
python3 deploy_q_account.py
# 기존 스택 업데이트 선택
```

### CloudFormation 템플릿 업데이트

```bash
# templates/*.yaml 수정 후
python3 deploy_q_account.py  # 또는 deploy_payer_account.py
```

## 🐛 문제 해결

### 1. Lambda 패키지 빌드 실패
```bash
# pip 업그레이드
pip install --upgrade pip

# 의존성 재설치
pip install -r lambda/requirements.txt -t /tmp/test
```

### 2. Java UDF 빌드 실패
```bash
# Maven 설치 확인
mvn --version

# 의존성 다운로드
cd java_udf/identity-center-udf
mvn dependency:resolve
```

### 3. Cross-account Role assume 실패
- External ID 확인: `<Q계정ID>-amazon-q-analytics`
- Trust Policy 확인: Q 계정의 Lambda 실행 역할 ARN
- IAM Identity Center 활성화 확인

### 4. Athena 쿼리 실패
- 테이블 존재 확인
- S3 버킷 권한 확인
- Athena 쿼리 결과 버킷 설정 확인

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
8488bd6c-5081-7061-3353-13643f204de9   | chogilsang@gsneotek.com    | 5            | 150            | 1200
```

**Key Points:**
- UDF function name must be **lowercase** in SQL (`getusername`, not `getUserName`)
- Lambda function name: `final-identity-udf`
- Returns user email from IAM Identity Center
- Caches results for performance

## 📞 지원

문제가 발생하거나 개선 사항이 있으면 이슈를 생성해주세요.

---

**버전**: v1.0  
**최종 업데이트**: 2026-03-22
