-- Amazon Q Developer Pro User Analytics Table
-- This table stores daily usage metrics for Amazon Q Developer Pro users

CREATE EXTERNAL TABLE IF NOT EXISTS q_user_analytics.user_reports (
  UserId STRING,
  Date STRING,
  Chat_AICodeLines INT,
  Chat_MessagesInteracted INT,
  Chat_MessagesSent INT,
  CodeFix_AcceptanceEventCount INT,
  CodeFix_AcceptedLines INT,
  CodeFix_GeneratedLines INT,
  CodeFix_GenerationEventCount INT,
  CodeReview_FailedEventCount INT,
  CodeReview_FindingsCount INT,
  CodeReview_SucceededEventCount INT,
  Dev_AcceptanceEventCount INT,
  Dev_AcceptedLines INT,
  Dev_GeneratedLines INT,
  Dev_GenerationEventCount INT,
  DocGeneration_AcceptedFileUpdates INT,
  DocGeneration_AcceptedFilesCreations INT,
  DocGeneration_AcceptedLineAdditions INT,
  DocGeneration_AcceptedLineUpdates INT,
  DocGeneration_EventCount INT,
  DocGeneration_RejectedFileCreations INT,
  DocGeneration_RejectedFileUpdates INT,
  DocGeneration_RejectedLineAdditions INT,
  DocGeneration_RejectedLineUpdates INT,
  InlineChat_AcceptanceEventCount INT,
  InlineChat_AcceptedLineAdditions INT,
  InlineChat_AcceptedLineDeletions INT,
  InlineChat_DismissalEventCount INT,
  InlineChat_DismissedLineAdditions INT,
  InlineChat_DismissedLineDeletions INT,
  InlineChat_RejectedLineAdditions INT,
  InlineChat_RejectedLineDeletions INT,
  InlineChat_RejectionEventCount INT,
  InlineChat_TotalEventCount INT,
  Inline_AICodeLines INT,
  Inline_AcceptanceCount INT,
  Inline_SuggestionsCount INT,
  TestGeneration_AcceptedLines INT,
  TestGeneration_AcceptedTests INT,
  TestGeneration_EventCount INT,
  TestGeneration_GeneratedLines INT,
  TestGeneration_GeneratedTests INT,
  Transformation_EventCount INT,
  Transformation_LinesGenerated INT,
  Transformation_LinesIngested INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar' = '"',
  'escapeChar' = '\\'
)
STORED AS TEXTFILE
LOCATION 's3://YOUR_BUCKET_NAME/daily-report/'
TBLPROPERTIES (
  'skip.header.line.count'='1',
  'has_encrypted_data'='false'
);
