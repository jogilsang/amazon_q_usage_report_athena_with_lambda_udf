# Amazon Q Developer Pro 사용량 분석 with Athena & Lambda UDF

Athena 쿼리와 Lambda UDF를 활용한 Amazon Q Developer Pro 사용량 분석 자동화 솔루션입니다. Identity Center 통합을 통해 온디맨드 분석을 제공합니다.

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
   - Q 계정과 동일하거나 별도 계정 (일반적으로 AWS Organizations의 Management/Payer 계정)

> **참고**: 단일 계정 설정(Q와 Identity Center가 같은 계정)의 경우, 동일한 계정에 대해 두 스크립트를 실행하면 됩니다.

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

## 🚀 배포

### 1단계: 설정

```bash
# 예제 설정 파일 복사
cp config.json.example config.json

# 설정 편집
vi config.json
```

**config.json 파라미터:**

| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `udf_lambda_role_name` | Java UDF Lambda용 IAM 역할 이름 | `AthenaUDFForIAMIdentityCenterRole` |
| `lambda_region` | Lambda 및 Athena 리전 | `us-east-1` |
| `identity_profile.account_id` | Identity Center 계정 ID | `123456789012` |
| `identity_profile.account_role_name` | Cross-account 역할 이름 | `IdentityCenter-ReadOnly-Role` |
| `identity_profile.external_id` | 추가 보안을 위한 External ID (선택사항) | `""` 또는 `"my-external-id"` |
| `identity_region` | Identity Center 리전 | `ap-northeast-2` |
| `identity_store_id` | Identity Store ID (IAM Identity Center 콘솔에서 확인) | `d-xxxxxxxxxx` |
| `athena_database` | Athena 데이터베이스 이름 | `q_user_analytics` |
| `athena_table` | Athena 테이블 이름 | `user_reports` |
| `s3_data_bucket` | Q 사용량 데이터용 S3 버킷 | `your-q-data-bucket` |
| `s3_results_bucket` | Athena 쿼리 결과용 S3 버킷 | `aws-athena-query-results-ACCOUNT_ID-REGION` |

> **참고**: `identity_store_id`는 IAM Identity Center 콘솔 → 설정 → Identity source에서 확인할 수 있습니다.

### 2단계: Q 계정 Lambda 배포 (먼저 실행)

```bash
# Lambda 함수 및 리소스 배포
./deploy_q_account_java_udf.sh captain
```

자동으로 수행되는 작업:
1. Lambda 패키지 빌드
2. Java UDF 빌드
3. 필요한 권한을 가진 IAM 역할 생성
4. Lambda 함수 생성

**출력**: Lambda 함수 ARN 및 역할 이름 (4단계에서 필요)

### 3단계: Athena 데이터베이스 및 테이블 설정

```bash
# Athena 리소스 설정 (최초 1회만)
./deploy_q_account_athena.sh --profile YOUR_PROFILE
```

자동으로 수행되는 작업:
1. Athena 쿼리 결과 S3 버킷 생성 (필요시)
2. Athena 워크그룹 출력 위치 설정
3. Athena 데이터베이스 생성 (없는 경우)
4. `sample_athena_create_table.sql`을 사용하여 Athena 테이블 생성

> **참고**: 최초 1회만 실행하거나 Athena 리소스를 재생성해야 할 때 실행합니다.

### 4단계: IAM Identity Center 계정 배포

```bash
# Identity Center 역할 배포
./deploy_iam_identity_center_account.sh --profile YOUR_IDENTITY_CENTER_PROFILE
```

**입력 필요**: Q 계정 ID (Lambda가 배포된 계정)

Identity Center 접근을 위한 cross-account IAM 역할을 생성합니다.

> **참고**: IAM Identity Center가 활성화된 경우 Q 계정과 동일한 계정이거나, 다른 계정(일반적으로 AWS Organizations의 Management/Payer 계정)일 수 있습니다.

## 📁 프로젝트 구조

```
amazon_q_usage_report_athena_with_lambda_udf/
├── deploy_q_account_java_udf.sh             # Java UDF Lambda 배포
├── deploy_q_account_athena.sh               # Athena 데이터베이스/테이블 설정
├── deploy_iam_identity_center_account.sh    # IAM Identity Center 역할 배포
├── config.json.example                      # 설정 템플릿
├── config.json                              # 사용자 설정 (gitignore됨)
├── sample_athena_create_table.sql           # Athena 테이블 생성 SQL
├── sample_queries_with_udf.sql              # UDF 사용 예제 Athena 쿼리
├── DEPLOYMENT_ORDER.md                      # 아키텍처 포함 배포 가이드
├── DEPLOYMENT_CHECKLIST.md                  # 단계별 배포 체크리스트
├── java_udf/
│   └── identity-center-udf/                 # Athena UDF (Java)
│       ├── pom.xml                          # Maven 설정
│       └── src/main/java/                   # Java 소스 코드
└── README.md
```

### 파일 설명

| 파일 | 용도 |
|-----|------|
| `deploy_q_account_java_udf.sh` | IAM 역할 생성 및 AssumeRole 설정과 함께 Java UDF Lambda 함수 배포 |
| `deploy_q_account_athena.sh` | Athena 데이터베이스, 테이블 및 S3 버킷 설정 |
| `deploy_iam_identity_center_account.sh` | Identity Center 접근을 위한 cross-account IAM 역할 생성 |
| `config.json` | 계정 ID, 리전 및 리소스 이름이 포함된 설정 파일 |
| `config.json.example` | 설정 파일 템플릿 |
| `sample_athena_create_table.sql` | Athena 테이블 생성 SQL 템플릿 |
| `sample_queries_with_udf.sql` | UDF 사용을 보여주는 4개의 예제 쿼리 |
| `DEPLOYMENT_ORDER.md` | 아키텍처 다이어그램 포함 완전한 배포 가이드 |
| `DEPLOYMENT_CHECKLIST.md` | 단계별 배포 체크리스트 |
| `java_udf/identity-center-udf/` | UserId를 UserName으로 변환하는 Java UDF 프로젝트 |

## ⚙️ 환경 변수 (Lambda)

배포 스크립트에 의해 자동으로 설정됩니다:

| 변수 | 설명 | 예시 |
|-----|------|------|
| `IDENTITY_CENTER_REGION` | IAM Identity Center 리전 | `ap-northeast-2` |
| `IDENTITY_CENTER_ACCOUNT_ID` | Payer 계정 ID | `123456789012` |
| `CROSS_ACCOUNT_ROLE_NAME` | Cross-account 역할 이름 | `IdentityCenter-ReadOnly-Role` |
| `ATHENA_REGION` | Athena 리전 | `us-east-1` |
| `ATHENA_DATABASE` | Athena 데이터베이스 | `q_user_analytics` |
| `ATHENA_TABLE` | Athena 테이블 | `user_reports` |
| `ATHENA_RESULTS_BUCKET` | Athena 결과 S3 버킷 | `my-bucket` |
| `S3_BUCKET` | 리포트 저장 S3 버킷 | `my-bucket` |

## 📊 사용 예제

### UDF를 사용한 Athena 쿼리

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

**주요 포인트:**
- UDF 함수 이름은 SQL에서 **소문자**여야 합니다 (`getusername`, `getUserName` 아님)
- Lambda 함수 이름: `final-identity-udf`
- IAM Identity Center에서 사용자 이메일 반환
- 성능을 위해 결과 캐싱

## 🔒 보안 고려사항

### 최소 권한 원칙
- IAM Identity Center 계정 cross-account 역할은 **Identity Center 읽기 전용** 권한만 보유
- 추가 보안을 위해 External ID 사용 가능

### 권한 범위
**Q 계정 Lambda**:
- Athena 쿼리 실행
- S3 읽기/쓰기 (자체 버킷만)
- Cross-account 역할 assume

**IAM Identity Center 계정 역할**:
- Identity Store 읽기 (`identitystore:ListUsers`, `identitystore:DescribeUser`)
- SSO Admin 읽기 (`sso-admin:ListInstances`)

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

### 3. Cross-account Role Assume 실패
- External ID 확인 (사용하는 경우)
- Trust Policy에 Lambda 역할 ARN 포함 확인
- IAM Identity Center 활성화 확인

### 4. Athena 쿼리 실패
- 테이블 존재 확인
- S3 버킷 권한 확인
- Athena 결과 버킷 설정 확인

## 📞 지원

문제가 발생하거나 개선 사항이 있으면 이슈를 생성해주세요.

---

**버전**: v1.0  
**최종 업데이트**: 2026-03-22
