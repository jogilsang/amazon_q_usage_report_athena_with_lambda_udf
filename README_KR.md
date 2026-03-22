# Amazon Q Developer Pro 사용량 분석 - Athena & Lambda UDF

Athena 쿼리와 Lambda UDF를 활용하여 Amazon Q Developer Pro 사용량을 분석하는 솔루션입니다. 스케줄 실행 없이 필요할 때 수동으로 실행하는 온디맨드 방식입니다.

[English Documentation](README.md)

## 🏗️ 아키텍처

이 솔루션은 **1개 또는 2개의 AWS 계정**을 사용합니다:

1. **Q 계정**: Amazon Q Developer Pro가 활성화된 계정
   - Lambda 함수 (사용량 분석)
   - Athena (쿼리 실행)
   - S3 (리포트 저장)
   - Java UDF (Identity Center 통합)

2. **IAM Identity Center 계정**: IAM Identity Center가 위치한 계정
   - Cross-account IAM Role (Identity Center 읽기 권한)
   - Q 계정과 동일할 수도 있고, 별도 계정(AWS Organizations의 Management/Payer 계정)일 수도 있음

> **참고**: 단일 계정 구성(Q와 Identity Center가 같은 계정)의 경우, 두 스크립트를 동일한 계정에 대해 실행하면 됩니다.

## 📋 사전 요구사항

### 공통
- Python 3.9+
- AWS CLI 설정 완료
- Maven (Java UDF 빌드용)
- boto3 (`pip install boto3`)

### Q 계정
- Amazon Q Developer Pro 활성화
- Athena 테이블 설정 (`q_user_analytics.user_reports`)
- 리포트 및 Athena 결과용 S3 버킷

### IAM Identity Center 계정
- IAM Identity Center 활성화
- AWS Organizations의 Management/Payer 계정이거나 Q 계정과 동일

## 🚀 배포 방법

### Step 1: 설정

```bash
cd /Users/jogilsang/Documents/project_my/amazon_q_usage_report_athena_with_lambda_udf

# 예제 설정 파일 복사
cp config.json.example config.json

# 설정 편집
vi config.json
```

**config.json 파라미터:**

| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `lambda_name` | Lambda 함수 이름 | `amazon-q-athena-analytics` |
| `lambda_role_name` | Lambda 실행 역할 이름 | `AmazonQAthenaAnalyticsLambdaRole` |
| `lambda_region` | Lambda 리전 | `us-east-1` |
| `identity_profile.account_id` | Identity Center 계정 ID | `123456789012` |
| `identity_profile.account_role_name` | Cross-account 역할 이름 | `IdentityCenter-ReadOnly-Role` |
| `identity_profile.external_id` | External ID (선택사항) | `""` |
| `identity_region` | Identity Center 리전 | `ap-northeast-2` |
| `athena_database` | Athena 데이터베이스 이름 | `q_user_analytics` |
| `athena_table` | Athena 테이블 이름 | `user_reports` |
| `s3_bucket` | Q 데이터 및 리포트용 S3 버킷 | `your-q-data-bucket` |

### Step 2: Q 계정 Lambda 배포 (먼저 실행)

```bash
# Lambda 함수 및 리소스 배포
./deploy_q_account.sh --profile YOUR_PROFILE
```

자동으로 수행되는 작업:
1. Lambda 패키지 빌드
2. Java UDF 빌드
3. 필요한 권한을 가진 IAM 역할 생성
4. Lambda 함수 생성
5. Java UDF를 S3에 업로드

**출력**: Lambda 함수 ARN 및 역할 이름 (Step 4에서 필요)

### Step 3: Athena 데이터베이스 및 테이블 설정

```bash
# Athena 리소스 설정 (최초 1회만)
./deploy_q_account_athena.sh --profile YOUR_PROFILE
```

자동으로 수행되는 작업:
1. Athena 쿼리 결과용 S3 버킷 생성 (필요시)
2. Athena workgroup output location 설정
3. Athena 데이터베이스 생성 (없는 경우)
4. `sample_athena_create_table.sql`을 사용하여 Athena 테이블 생성

> **참고**: 최초 1회만 실행하거나 Athena 리소스를 재생성해야 할 때 실행하세요.

### Step 4: IAM Identity Center 계정 배포

```bash
# Identity Center 역할 배포
./deploy_iam_identity_center_account.sh --profile YOUR_PROFILE
```

**입력 필요**: Q 계정 ID (Lambda가 배포된 계정)

Identity Center 접근을 위한 cross-account IAM 역할을 생성합니다.

> **참고**: Q 계정과 동일한 계정일 수도 있고(IAM Identity Center가 해당 계정에 활성화된 경우), AWS Organizations의 Management/Payer 계정처럼 별도 계정일 수도 있습니다.

## 📁 프로젝트 구조

```
amazon_q_usage_report_athena_with_lambda_udf/
├── deploy_q_account.py                      # Q 계정 Lambda 배포
├── deploy_q_account_athena.py               # Athena 데이터베이스/테이블 설정
├── deploy_iam_identity_center_account.py    # IAM Identity Center 역할 배포
├── config.json.example                      # 설정 템플릿
├── config.json                              # 사용자 설정 (gitignore)
├── sample_athena_create_table.sql           # Athena 테이블 생성 SQL 템플릿
├── requirements.txt                         # Python 의존성
├── lambda/
│   ├── lambda_function.py                   # Lambda 함수 코드
│   └── requirements.txt                     # Lambda 의존성
├── java_udf/
│   └── identity-center-udf/                 # Athena UDF (Java)
│       ├── pom.xml
│       └── src/
└── README.md
```

## ⚙️ 환경변수 (Lambda)

배포 스크립트가 자동으로 설정:

| 변수 | 설명 | 예시 |
|------|------|------|
| `IDENTITY_CENTER_REGION` | IAM Identity Center 리전 | `ap-northeast-2` |
| `IDENTITY_CENTER_ACCOUNT_ID` | IAM Identity Center 계정 ID | `123456789012` |
| `CROSS_ACCOUNT_ROLE_NAME` | Cross-account 역할 이름 | `IdentityCenter-ReadOnly-Role` |
| `ATHENA_REGION` | Athena 리전 | `us-east-1` |
| `ATHENA_DATABASE` | Athena 데이터베이스 | `q_user_analytics` |
| `ATHENA_TABLE` | Athena 테이블 | `user_reports` |
| `ATHENA_RESULTS_BUCKET` | Athena 결과 S3 버킷 | `my-bucket` |
| `S3_BUCKET` | 리포트 저장 S3 버킷 | `my-bucket` |

## 📊 생성되는 리포트

### CSV 파일 구조
- **DisplayName**: 사용자 표시 이름
- **UserName**: 사용자 로그인 이름
- **UserId**: 고유 사용자 ID
- **active_days**: 활동 일수
- **46개 기능별 메트릭**: Chat, CodeFix, CodeReview, Dev, DocGeneration, InlineChat, Inline, TestGeneration, Transformation 등

### 저장 위치
- **S3**: `s3://<버킷>/monthly-report/amazon_q_usage_YYYYMM_timestamp.csv`

## 🚀 사용 방법

### 수동 실행

```bash
# Lambda 함수 호출
aws lambda invoke \
  --function-name amazon-q-athena-analytics \
  --region us-east-1 \
  response.json

# 결과 확인
cat response.json
```

### 로그 확인

```bash
# CloudWatch Logs 확인
aws logs tail /aws/lambda/amazon-q-athena-analytics --follow
```

## 🔧 추가 설정

### 1. Athena 테이블 생성

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS q_user_analytics.user_reports (
  UserId STRING,
  Date STRING,
  Chat_AICodeLines INT,
  Chat_MessagesInteracted INT,
  -- 필요한 다른 컬럼 추가
)
PARTITIONED BY (year STRING, month STRING, day STRING)
LOCATION 's3://your-bucket/amazon-q-data/'
TBLPROPERTIES ('has_encrypted_data'='false');
```

### 2. Java UDF Lambda 함수 (Athena용)

Java UDF는 자동으로 S3에 업로드됩니다. Athena 쿼리에서 사용하려면:

```bash
# Athena UDF용 Lambda 함수 생성
aws lambda create-function \
  --function-name identity-center-udf \
  --runtime java11 \
  --role <Lambda-Role-ARN> \
  --handler com.amazon.q.analytics.IdentityCenterUDFHandler \
  --code S3Bucket=<bucket>,S3Key=athena-udf/identity-center-udf-1.0-SNAPSHOT.jar \
  --timeout 60 \
  --memory-size 512
```

## 🧪 테스트

### Lambda 함수 테스트

```bash
# 수동 호출
aws lambda invoke \
  --function-name amazon-q-athena-analytics \
  --region us-east-1 \
  response.json

cat response.json
```

### Cross-Account Role 테스트

```bash
# Q 계정에서 역할 assume 테스트
aws sts assume-role \
  --role-arn arn:aws:iam::<Identity-Center-Account-ID>:role/IdentityCenter-ReadOnly-Role \
  --role-session-name test-session \
  --profile <Q-account-profile>
```

## 🔒 보안 고려사항

### 최소 권한 원칙
- IAM Identity Center 계정의 cross-account 역할은 **Identity Center 읽기 전용** 권한만 보유
- 추가 보안을 위해 External ID 사용 가능

### 권한 범위
**Q 계정 Lambda**:
- Athena 쿼리 실행
- S3 읽기/쓰기 (자체 버킷만)
- Cross-account 역할 assume

**IAM Identity Center 계정 Role**:
- Identity Store 읽기 (`identitystore:ListUsers`, `identitystore:DescribeUser`)
- SSO Admin 읽기 (`sso-admin:ListInstances`)

## 🔄 업데이트 방법

### Lambda 코드만 업데이트

```bash
# lambda/lambda_function.py 수정 후
./deploy_q_account.sh --profile YOUR_PROFILE
# 기존 함수가 업데이트됨
```

### 설정 업데이트

```bash
# config.json 수정 후
./deploy_q_account.sh --profile YOUR_PROFILE
# Lambda 환경변수가 업데이트됨
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

# 의존성 해결
cd java_udf/identity-center-udf
mvn dependency:resolve
```

### 3. Cross-Account Role Assume 실패
- External ID 확인 (사용하는 경우)
- Trust Policy에 Lambda 역할 ARN 포함 확인
- IAM Identity Center 활성화 확인

### 4. Athena 쿼리 실패
- 테이블 존재 확인
- S3 버킷 권한 확인
- Athena 결과 버킷 설정 확인

## 📊 사용 예제

### Athena UDF 쿼리

Java UDF Lambda 함수(`final-identity-udf`)는 IAM Identity Center API를 사용하여 UserId를 UserName으로 변환합니다.

**예제 쿼리:**
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

**예제 결과:**
```
UserId                                  | UserName                    | record_count | total_messages | total_accepted_lines
----------------------------------------|----------------------------|--------------|----------------|---------------------
8488bd6c-5081-7061-3353-13643f204de9   | chogilsang@gsneotek.com    | 5            | 150            | 1200
```

**주요 사항:**
- UDF 함수명은 SQL에서 **소문자**로 작성 (`getusername`, `getUserName` 아님)
- Lambda 함수명: `final-identity-udf`
- IAM Identity Center에서 사용자 이메일 반환
- 성능을 위해 결과 캐싱

**더 많은 예제:**
- `sample_queries_with_udf.sql` 파일 참조

## 📞 지원

문제가 발생하거나 개선 사항이 있으면 이슈를 생성해주세요.

---

**버전**: v1.0  
**최종 업데이트**: 2026-03-22
