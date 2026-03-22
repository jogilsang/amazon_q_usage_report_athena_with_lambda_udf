-- Amazon Q Usage Analytics with Identity Center UDF
-- This query demonstrates how to use the Java UDF Lambda function to map UserId to UserName

-- Register the UDF function
USING EXTERNAL FUNCTION getusername(user_id VARCHAR)
RETURNS VARCHAR
LAMBDA 'final-identity-udf'

-- Example 1: Simple test - Top 5 users by messages
SELECT 
    UserId,
    getusername(UserId) as UserName,
    COUNT(*) as active_days,
    SUM(Chat_MessagesSent) as total_messages
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'
GROUP BY UserId
ORDER BY total_messages DESC
LIMIT 5;

-- Example 2: Top 10 users by chat messages
SELECT 
    UserId,
    getusername(UserId) as UserName,
    COUNT(*) as active_days,
    SUM(Chat_MessagesSent) as total_messages,
    SUM(Dev_AcceptedLines) as total_accepted_lines,
    SUM(CodeFix_AcceptedLines) as total_codefix_lines
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'  -- January data
GROUP BY UserId
ORDER BY total_messages DESC
LIMIT 10;

-- Example 3: Monthly summary with user names
SELECT 
    getusername(UserId) as UserName,
    COUNT(DISTINCT Date) as active_days,
    SUM(Chat_MessagesSent) as chat_messages,
    SUM(Dev_GenerationEventCount) as dev_generations,
    SUM(TestGeneration_EventCount) as test_generations,
    SUM(CodeReview_SucceededEventCount) as code_reviews
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'
GROUP BY UserId
ORDER BY chat_messages DESC;

-- Example 4: Feature usage breakdown
SELECT 
    getusername(UserId) as UserName,
    SUM(Chat_MessagesSent) as chat_usage,
    SUM(Dev_AcceptedLines) as dev_usage,
    SUM(CodeFix_AcceptedLines) as codefix_usage,
    SUM(TestGeneration_AcceptedLines) as test_usage,
    SUM(DocGeneration_AcceptedLineAdditions) as doc_usage
FROM q_user_analytics.user_reports
WHERE Date LIKE '01-%'
GROUP BY UserId
HAVING SUM(Chat_MessagesSent) > 0
ORDER BY chat_usage DESC
LIMIT 20;

-- Notes:
-- 1. UDF function name must be lowercase in SQL (getusername, not getUserName)
-- 2. Lambda function: final-identity-udf
-- 3. Returns user email from IAM Identity Center
-- 4. Results are cached for performance
-- 5. Returns "Unknown" for invalid/missing user IDs
