# 배포 완료 체크리스트

## ✅ 완료된 작업

### 1. Lambda 함수 배포
- **함수명**: `final-identity-udf`
- **상태**: Active
- **런타임**: java11
- **핸들러**: com.example.IdentityCenterUDF
- **환경변수**:
  - IDENTITY_STORE_ID: d-9b67649839
  - IDENTITY_STORE_REGION: ap-northeast-2

### 2. Athena 테스트 성공
- **테스트 쿼리**: ✅ 성공
- **UDF 함수**: `getusername(user_id)`
- **결과 예시**:
  - UserId: 8488bd6c-5081-7061-3353-13643f204de9
  - UserName: chogilsang@OOO.com

### 3. 문서 업데이트
- ✅ README.md - 사용 예제 추가
- ✅ README_KR.md - 사용 예제 추가 (한국어)
- ✅ sample_queries_with_udf.sql - 샘플 쿼리 파일 생성

### 4. 스크립트 수정
- ✅ deploy_java_udf.sh - Lambda 함수명 `final-identity-udf`로 변경

## 📋 사용 방법

### Athena에서 UDF 사용

```sql
USING EXTERNAL FUNCTION getusername(user_id VARCHAR)
RETURNS VARCHAR
LAMBDA 'final-identity-udf'

SELECT 
    UserId,
    getusername(UserId) as UserName,
    COUNT(*) as record_count
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'
GROUP BY UserId
LIMIT 10;
```

### 주요 사항
1. **함수명은 소문자**: `getusername` (SQL에서)
2. **Lambda 함수**: `final-identity-udf`
3. **캐싱**: 성능을 위해 결과 자동 캐싱
4. **에러 처리**: 잘못된 UserId는 "Unknown" 반환

## 🔍 검증 완료

### Lambda 함수
```bash
aws lambda get-function \
  --function-name final-identity-udf \
  --region us-east-1 \
  --profile captain
```

### Athena 쿼리
```bash
# sample_queries_with_udf.sql 파일 참조
# Athena 콘솔에서 직접 실행 가능
```

## 📁 파일 구조

```
.
├── README.md                          # 영문 문서 (업데이트됨)
├── README_KR.md                       # 한글 문서 (업데이트됨)
├── sample_queries_with_udf.sql        # 샘플 쿼리 (신규)
├── deploy_java_udf.sh                 # Java UDF 배포 스크립트 (수정됨)
├── java_udf/
│   └── identity-center-udf/
│       └── src/main/java/com/amazon/q/analytics/
│           └── IdentityCenterUDF.java
└── config.json                        # 설정 파일
```

## 🎯 다음 단계

1. **프로덕션 배포**: 다른 환경에 배포 시 `deploy_java_udf.sh` 사용
2. **모니터링**: CloudWatch Logs에서 Lambda 실행 로그 확인
3. **최적화**: 필요시 Lambda 메모리/타임아웃 조정

---

**배포 완료 일시**: 2026-03-22 19:11
**배포자**: captain profile
**리전**: us-east-1
