package com.amazon.q.analytics;

import com.amazonaws.athena.connector.lambda.handlers.UserDefinedFunctionHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.identitystore.IdentitystoreClient;
import software.amazon.awssdk.services.identitystore.model.DescribeUserRequest;
import software.amazon.awssdk.services.identitystore.model.DescribeUserResponse;
import software.amazon.awssdk.services.identitystore.model.IdentitystoreException;
import software.amazon.awssdk.services.sts.StsClient;
import software.amazon.awssdk.services.sts.model.AssumeRoleRequest;
import software.amazon.awssdk.services.sts.model.AssumeRoleResponse;
import software.amazon.awssdk.services.sts.model.Credentials;
import software.amazon.awssdk.auth.credentials.AwsSessionCredentials;

import java.util.concurrent.ConcurrentHashMap;

/**
 * Identity Center UDF for Amazon Q Developer Pro Analytics
 * Converts UserId to UserName using AWS Identity Center API
 */
public class IdentityCenterUDF extends UserDefinedFunctionHandler {
    
    private static final String SOURCE_TYPE = "IdentityCenter";
    
    // 캐시 - 성능 최적화를 위해 사용자 정보 캐싱
    private static final ConcurrentHashMap<String, String> userCache = new ConcurrentHashMap<>();
    
    // Identity Store 클라이언트
    private IdentitystoreClient identityStoreClient;
    private String identityStoreId;
    
    public IdentityCenterUDF() {
        super(SOURCE_TYPE);
        initializeIdentityStore();
    }
    
    /**
     * Identity Store 클라이언트 초기화
     * Cross-account AssumeRole을 통해 Identity Center에 접근
     */
    private void initializeIdentityStore() {
        try {
            // 환경변수에서 설정 가져오기
            String region = System.getenv("IDENTITY_STORE_REGION");
            this.identityStoreId = System.getenv("IDENTITY_STORE_ID");
            String accountId = System.getenv("IDENTITY_CENTER_ACCOUNT_ID");
            String roleName = System.getenv("CROSS_ACCOUNT_ROLE_NAME");
            
            if (region == null) {
                region = "us-east-1"; // 기본값
            }
            
            if (this.identityStoreId == null) {
                throw new RuntimeException("IDENTITY_STORE_ID 환경변수가 설정되지 않았습니다.");
            }
            
            // AssumeRole을 통한 자격 증명 획득
            if (accountId != null && roleName != null) {
                software.amazon.awssdk.services.sts.StsClient stsClient = software.amazon.awssdk.services.sts.StsClient.builder()
                        .region(Region.of(region))
                        .build();
                
                String roleArn = String.format("arn:aws:iam::%s:role/%s", accountId, roleName);
                
                software.amazon.awssdk.services.sts.model.AssumeRoleRequest assumeRoleRequest = 
                    software.amazon.awssdk.services.sts.model.AssumeRoleRequest.builder()
                        .roleArn(roleArn)
                        .roleSessionName("identity-center-udf-session")
                        .build();
                
                software.amazon.awssdk.services.sts.model.AssumeRoleResponse assumeRoleResponse = 
                    stsClient.assumeRole(assumeRoleRequest);
                
                software.amazon.awssdk.services.sts.model.Credentials credentials = assumeRoleResponse.credentials();
                
                // AssumeRole로 얻은 자격 증명으로 Identity Store 클라이언트 생성
                software.amazon.awssdk.auth.credentials.AwsSessionCredentials sessionCredentials = 
                    software.amazon.awssdk.auth.credentials.AwsSessionCredentials.create(
                        credentials.accessKeyId(),
                        credentials.secretAccessKey(),
                        credentials.sessionToken()
                    );
                
                this.identityStoreClient = IdentitystoreClient.builder()
                        .region(Region.of(region))
                        .credentialsProvider(() -> sessionCredentials)
                        .build();
            } else {
                // AssumeRole 없이 기본 자격 증명 사용 (단일 계정)
                this.identityStoreClient = IdentitystoreClient.builder()
                        .region(Region.of(region))
                        .build();
            }
                    
        } catch (Exception e) {
            throw new RuntimeException("Identity Store 클라이언트 초기화 실패: " + e.getMessage(), e);
        }
    }
    
    /**
     * UserId를 UserName으로 변환하는 UDF 메서드
     * Athena UDF는 메서드명을 소문자로 요구함
     * 
     * @param userId AWS Identity Center의 사용자 ID
     * @return 사용자 이름 (UserName)
     */
    public String getusername(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return "Unknown";
        }
        
        String cleanUserId = userId.trim().replace("\"", "");
        
        // 캐시에서 먼저 확인
        String cachedUserName = userCache.get(cleanUserId);
        if (cachedUserName != null) {
            return cachedUserName;
        }
        
        try {
            // Identity Center API 호출
            DescribeUserRequest request = DescribeUserRequest.builder()
                    .identityStoreId(this.identityStoreId)
                    .userId(cleanUserId)
                    .build();
            
            DescribeUserResponse response = identityStoreClient.describeUser(request);
            String userName = response.userName();
            
            // 캐시에 저장
            userCache.put(cleanUserId, userName);
            
            return userName;
            
        } catch (IdentitystoreException e) {
            // Identity Store 관련 오류
            String errorUserName = "Unknown";
            userCache.put(cleanUserId, errorUserName);
            return errorUserName;
            
        } catch (Exception e) {
            // 기타 오류
            String errorUserName = "Error";
            userCache.put(cleanUserId, errorUserName);
            return errorUserName;
        }
    }
    
    /**
     * 캐시 크기 확인 (디버깅용)
     * 
     * @return 캐시에 저장된 항목 수
     */
    public int getCacheSize() {
        return userCache.size();
    }
    
    /**
     * 캐시 초기화 (필요시 사용)
     */
    public void clearCache() {
        userCache.clear();
    }
}
