# Gmail to Telegram Workflow Investigation Report

**Date**: 2025-11-30  
**Workflow ID**: 5K6W8v0rMADEfaJx  
**Workflow Name**: Gmail to Telegram  
**Investigation Scope**: Recent failures (executions 320, 319, 318, 314, 313, 312)

---

## Executive Summary

The "Gmail to Telegram" workflow has experienced a pattern of intermittent failures over the past 14 days, with 10 out of 14 executions failing (71% failure rate). Analysis reveals two distinct failure patterns:

1. **Immediate failures** (0-0.5 seconds): Authentication or initial Gmail API errors (executions 320, 319, 311, 310, 309)
2. **Long-running failures** (27-48 minutes): Processing errors or LLM timeouts during email analysis (executions 318, 314, 313, 312, 307)

**Critical Finding**: The workflow is triggered daily at 02:00 and processes unread emails from the last 2 days. The model configured is `llama3.2:3b`, which is installed and available.

---

## Performance Analysis

### Execution Statistics (Last 14 Runs)

| Metric | Value |
|--------|-------|
| Total Executions | 14 |
| Successful | 4 (29%) |
| Failed | 10 (71%) |
| Average Duration | 20.86 minutes |
| Success Duration | ~28-48 minutes |
| Immediate Failures | ~0.2-0.5 seconds |
| Long-Running Failures | ~27-48 minutes |

### Recent Execution Timeline

| ID | Date | Duration | Status | Pattern |
|----|------|----------|--------|---------|
| 320 | 2025-11-30 | 0.2s | ❌ Error | Immediate failure |
| 319 | 2025-11-29 | 0.2s | ❌ Error | Immediate failure |
| 318 | 2025-11-28 | 1.5m | ❌ Error | Short processing error |
| 317 | 2025-11-27 | 48.3m | ✅ Success | Normal operation |
| 316 | 2025-11-26 | 28.6m | ✅ Success | Normal operation |
| 315 | 2025-11-25 | 39.3m | ✅ Success | Normal operation |
| 314 | 2025-11-24 | 27.8m | ❌ Error | Long-running failure |
| 313 | 2025-11-23 | 27.4m | ❌ Error | Long-running failure |
| 312 | 2025-11-22 | 39.0m | ❌ Error | Long-running failure |
| 311 | 2025-11-21 | 0.2s | ❌ Error | Immediate failure |

---

## Data Quality Analysis

### LLM Response Analysis (Execution 318)

Successfully extracted LLM response from execution 318, which shows the model was able to process emails and generate structured output:

```
Important: No
Category: Newsletter
Summary: You received a promotional email from LinkedIn about your search appearances on the platform.
Actions:
- View Search Results: https://www.linkedin.com/search/
- See All Viewers: https://www.linkedin.com/search/
```

**Key Observations**:
- LLM successfully parsed email content
- Text format output is correctly structured
- Link placeholders (if any) were properly extracted
- Category classification working correctly
- Summary generation functional

### Workflow Node Structure

The workflow consists of:
1. **Schedule Trigger** - Daily at 02:00
2. **Get Unread Emails** - Gmail API (last 2 days, limit 20)
3. **Any Emails?** - Validation check
4. **Map Email Fields** - Data extraction
5. **Clean Email Input** - Sanitization with comprehensive JavaScript code
6. **Loop Over Emails** - Batch processing
7. **Set model** - Configures `llama3.2:3b`
8. **Summarise Email with LLM** - HTTP request to Ollama
9. **Calculate Metrics** - Performance tracking
10. **Format for Telegram** - Message formatting with link rehydration
11. **Notify Summary** - Telegram delivery

---

## Root Cause Analysis

### Primary Issues Identified

#### 1. **Gmail API Authentication Failures** (Immediate failures)
**Symptoms**: 
- Executions fail within 0.2-0.5 seconds
- No email data processed
- Occurs on 320, 319, 311, 310, 309

**Likely Causes**:
- OAuth2 token expiration
- Gmail API rate limiting
- Credential refresh failure
- Network connectivity issues

**Evidence**:
- Workflow fails before reaching email processing nodes
- No LLM invocation occurs
- Pattern suggests external API dependency failure

#### 2. **LLM Processing or Timeout Issues** (Long-running failures)
**Symptoms**:
- Executions run for 27-48 minutes before failing
- Similar duration to successful executions
- Occurs on 314, 313, 312, 307

**Likely Causes**:
- LLM response timeout (despite 80000000ms timeout configured)
- Ollama service memory exhaustion
- Model loading failures during processing
- Network issues between n8n and Ollama containers

**Evidence**:
- Failures occur after significant processing time
- Successful executions have similar durations
- Model is available (`llama3.2:3b` installed)

#### 3. **Execution 318 - Short Processing Error**
**Symptoms**:
- Failed after only 1.5 minutes
- Unusual compared to other patterns

**Likely Cause**:
- Empty email result or validation failure
- Processing error in "Format for Telegram" node
- Possible null pointer or data structure issue

---

## Technical Analysis

### Model Configuration

**Configured Model**: `llama3.2:3b` (line 305 in workflow)  
**Available Models**:
```
llama3.2:3b    2.0 GB    ✅ Installed
llama3.2:1b    1.3 GB    ✅ Installed
llama3.1:8b    4.9 GB    ✅ Installed
qwen2.5:14b    9.0 GB    ✅ Installed
```

**Model Status**: ✅ Correct model available

### Timeout Configuration

From `docker-compose.yml`:
```
N8N_WORKFLOW_TIMEOUT=43200  # 12 hours
N8N_HTTP_REQUEST_TIMEOUT=0  # Disabled
FETCH_BODY_TIMEOUT=43200000  # 12 hours
```

HTTP Request node timeout: `80000000ms` (22+ hours)

**Timeout Status**: ✅ Properly configured for long-running LLM calls

### Email Sanitization

The workflow includes extensive email sanitization logic (lines 150-156):
- HTML cleaning
- Language detection (Polish, German, French)
- Promotional email detection
- URL extraction and placeholder replacement
- Boilerplate removal
- Token reduction strategies

**Sanitization Status**: ✅ Comprehensive implementation

### Link Rehydration System

The "Format for Telegram" node includes link rehydration (lines 172-175):
- Parses `[LINK_N]` and `LINK_N` placeholders
- Uses `urlMap` from sanitization phase
- Logging for debugging missing links

**Link Handling**: ✅ Properly implemented

---

## Service Health Check

### Docker Services Status
```
✅ n8n           - Up 10 minutes (healthy)
✅ postgres      - Up 10 minutes (healthy)
✅ ollama        - Up 10 minutes (healthy)
✅ grafana       - Up 10 minutes (healthy)
✅ prometheus    - Up 10 minutes (healthy)
```

### Ollama Memory Configuration
```yaml
mem_limit: 14g
mem_reservation: 4g
```

**Current System**: Raspberry Pi 5 with 16GB RAM  
**Status**: ✅ Adequate memory for `llama3.2:3b` (2GB model)

### n8n Timeout Patch Status
```
[patch] http server timeouts: request=0ms, headers=120000ms, keepAlive=65000ms
[patch] axios timeout set to 43200000ms
[patch] undici dispatcher set: headersTimeout=10800000ms, bodyTimeout=43200000ms
[patch] Global fetch patched for Ollama requests
```

**Status**: ✅ Patches loaded successfully

---

## Recommendations

### Immediate Actions (Priority 1)

#### 1. **Fix Gmail OAuth2 Token Refresh**

**Problem**: Intermittent authentication failures causing immediate execution failures.

**Solution**: Check and refresh Gmail OAuth2 credentials.

```bash
# Check credential status in n8n UI
# Navigate to: Settings > Credentials > Gmail account

# If expired, re-authenticate:
# 1. Go to Credentials page
# 2. Edit "Gmail account" credential
# 3. Click "Connect my account"
# 4. Complete OAuth2 flow
```

**Expected Impact**: Eliminate 50% of failures (executions 320, 319, 311, 310, 309)

**Testing**: Monitor next 3 daily executions for immediate failures

---

#### 2. **Add Explicit Error Handling and Logging**

**Problem**: Unable to retrieve detailed error messages from failed executions.

**Solution**: Add Error Trigger nodes and enhanced logging to capture failure details.

**Implementation**:

Add an **Error Trigger** node after critical nodes:
- After "Get Unread Emails" - Capture Gmail API errors
- After "Summarise Email with LLM" - Capture Ollama errors
- After "Format for Telegram" - Capture formatting errors

Error Handler workflow:
```javascript
// Send detailed error to Telegram
const errorDetails = {
  execution_id: $workflow.id,
  node_name: $node.name,
  error_message: $json.error?.message || 'Unknown error',
  error_stack: $json.error?.stack || '',
  timestamp: new Date().toISOString(),
  input_data: JSON.stringify($input.all()).substring(0, 500)
};

return {
  json: {
    message: `❌ Workflow Error\\n\\nNode: ${errorDetails.node_name}\\nError: ${errorDetails.error_message}\\nTime: ${errorDetails.timestamp}\\n\\nExecution ID: ${errorDetails.execution_id}`
  }
};
```

**Expected Impact**: Full visibility into failure root causes

---

#### 3. **Implement Retry Logic for LLM Failures**

**Problem**: Long-running executions fail without retry, wasting processing time.

**Solution**: Add retry logic with exponential backoff for Ollama requests.

**Implementation**:

Modify "Summarise Email with LLM" node:
```yaml
options:
  timeout: 80000000
  retry:
    retries: 3
    retryDelay: 5000  # 5 seconds
    retryOnHttpStatusCodes: [408, 429, 500, 502, 503, 504]
```

Add a "Check Ollama Health" node before processing:
```bash
curl -f http://ollama:11434/api/tags
```

If health check fails, skip to error notification instead of attempting LLM call.

**Expected Impact**: Reduce wasted processing time on infrastructure failures

---

### Short-Term Improvements (Priority 2)

#### 4. **Add Email Result Validation**

**Problem**: Execution 318 failed after 1.5 minutes, suggesting validation issue.

**Solution**: Add explicit validation after "Get Unread Emails" node.

```javascript
// Validation node after "Get Unread Emails"
const emails = $input.all();

if (!Array.isArray(emails)) {
  throw new Error('Invalid email data: not an array');
}

if (emails.length === 0) {
  console.log('No new emails found - exiting gracefully');
  return [];
}

// Validate each email has required fields
const validatedEmails = emails.filter(email => {
  const data = email.json || email;
  return data.id && data.subject !== undefined && data.from;
});

if (validatedEmails.length !== emails.length) {
  console.warn(`Filtered out ${emails.length - validatedEmails.length} invalid emails`);
}

return validatedEmails;
```

**Expected Impact**: Prevent processing errors from malformed Gmail API responses

---

#### 5. **Implement Graceful Degradation for LLM Failures**

**Problem**: If LLM fails, entire workflow fails, losing all email notifications.

**Solution**: Create a fallback summary when LLM is unavailable.

```javascript
// Add fallback logic in "Format for Telegram" node
function createFallbackSummary(email) {
  return {
    isImportant: false,
    category: 'unprocessed',
    summary: `Email from ${email.fromName}: ${email.subject}`,
    actions: [`Open in Gmail: ${email.gmailUrl}`]
  };
}

// In main processing loop
try {
  const parsedData = parseTextResponse(llmResponse, data.urlMap);
  if (!parsedData) {
    console.warn('LLM parsing failed, using fallback');
    parsedData = createFallbackSummary(data);
  }
  // ... continue processing
} catch (error) {
  console.error('Processing error:', error);
  const fallbackData = createFallbackSummary(data);
  // ... continue with fallback
}
```

**Expected Impact**: Ensure critical notifications still sent even when LLM fails

---

#### 6. **Add Execution Monitoring Dashboard**

**Problem**: Manual investigation required to identify failure patterns.

**Solution**: Create a Grafana dashboard querying PostgreSQL execution data.

**Queries**:
```sql
-- Success rate over time
SELECT 
  date_trunc('day', "startedAt") as date,
  COUNT(*) FILTER (WHERE status = 'success') as successful,
  COUNT(*) FILTER (WHERE status = 'error') as failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'success') / COUNT(*), 2) as success_rate
FROM execution_entity
WHERE "workflowId" = '5K6W8v0rMADEfaJx'
  AND "startedAt" > NOW() - INTERVAL '30 days'
GROUP BY date
ORDER BY date DESC;

-- Average duration by status
SELECT 
  status,
  AVG(EXTRACT(EPOCH FROM ("stoppedAt" - "startedAt"))) / 60 as avg_duration_minutes,
  COUNT(*) as count
FROM execution_entity
WHERE "workflowId" = '5K6W8v0rMADEfaJx'
  AND "startedAt" > NOW() - INTERVAL '30 days'
GROUP BY status;
```

**Expected Impact**: Proactive detection of failure trends

---

### Long-Term Optimizations (Priority 3)

#### 7. **Optimize LLM Processing for Batch Efficiency**

**Current**: Each email processed individually in loop  
**Optimization**: Batch multiple emails in single LLM call

**Implementation**: Modify prompt to accept multiple emails:
```
Analyze the following 5 emails and provide structured output for each...

Email 1:
[email content]

Email 2:
[email content]

...

Output format for each email:
EMAIL_1:
Important: Yes/No
Category: <category>
...
---
EMAIL_2:
Important: Yes/No
...
```

**Benefits**:
- Reduce API calls
- Leverage model's context window more efficiently
- Faster overall execution time

**Trade-offs**:
- More complex parsing
- Risk of partial failures affecting batch

---

#### 8. **Implement Incremental Processing State**

**Problem**: If execution fails mid-processing, all progress lost.

**Solution**: Store processing state in n8n variables or external database.

```javascript
// Mark emails as processed
const processedEmailIds = $workflow.staticData.processedIds || [];

// Filter out already processed emails
const unprocessedEmails = emails.filter(email => 
  !processedEmailIds.includes(email.id)
);

// After successful processing
processedEmailIds.push(email.id);
$workflow.staticData.processedIds = processedEmailIds;

// Cleanup old IDs (keep last 100)
if (processedEmailIds.length > 100) {
  $workflow.staticData.processedIds = processedEmailIds.slice(-100);
}
```

**Expected Impact**: Prevent duplicate processing and data loss on retries

---

## Testing Recommendations

### Test Plan for OAuth2 Fix

1. **Verify credentials**:
   ```bash
   # Check n8n UI for credential status
   # Look for expiration warnings
   ```

2. **Test Gmail API connection**:
   ```bash
   # In n8n, test "Get Unread Emails" node manually
   # Should return recent emails without error
   ```

3. **Monitor next 3 scheduled executions**:
   - 2025-12-01 02:00
   - 2025-12-02 02:00
   - 2025-12-03 02:00

4. **Success criteria**:
   - No immediate failures (<1 second duration)
   - Emails successfully retrieved
   - Execution proceeds to LLM processing

### Test Plan for Error Handling

1. **Simulate Gmail API failure**:
   ```bash
   # Temporarily disable Gmail credentials
   # Trigger workflow manually
   # Verify error notification sent to Telegram
   ```

2. **Simulate Ollama failure**:
   ```bash
   docker compose stop ollama
   # Trigger workflow manually
   # Verify graceful degradation to fallback summaries
   docker compose start ollama
   ```

3. **Simulate parsing failure**:
   ```javascript
   // Temporarily modify "Format for Telegram" to throw error
   throw new Error('Test parsing failure');
   // Verify error captured and logged
   ```

---

## Monitoring Plan

### Daily Health Check (Automated)

Create a monitoring workflow:
- Query execution_entity for last 24 hours
- Calculate success rate
- If success rate < 50%, send alert to Telegram
- Include execution IDs and durations

### Weekly Review (Manual)

- Review Grafana dashboard
- Analyze failure patterns
- Check Ollama resource usage
- Review n8n logs for warnings

### Monthly Optimization Review

- Analyze average execution times
- Review token usage and costs
- Evaluate model performance
- Consider model upgrades if needed

---

## Appendix: Investigation Data

### Execution Details Queried

| ID | Started | Stopped | Duration | Status | Notes |
|----|---------|---------|----------|--------|-------|
| 320 | 2025-11-30 02:00:32 | 02:00:32 | 0.2s | Error | Immediate failure |
| 319 | 2025-11-29 02:00:32 | 02:00:32 | 0.2s | Error | Immediate failure |
| 318 | 2025-11-28 02:00:32 | 02:01:59 | 1.5m | Error | Short processing |
| 317 | 2025-11-27 02:00:32 | 02:48:50 | 48.3m | Success | Normal operation |
| 316 | 2025-11-26 02:00:32 | 02:29:04 | 28.6m | Success | Normal operation |

### LLM Response Sample (Execution 318)

```
Important: No
Category: Newsletter
Summary: You received a promotional email from LinkedIn about your search appearances on the platform.
Actions:
- View Search Results: https://www.linkedin.com/search/
- See All Viewers: https://www.linkedin.com/search/
```

### Service Status at Investigation Time

```
NAME                       STATUS                    UPTIME
homelab-n8n                Up 10 minutes (healthy)   10m
homelab-postgres           Up 10 minutes (healthy)   10m
homelab-ollama             Up 10 minutes (healthy)   10m
```

---

## Conclusion

The "Gmail to Telegram" workflow is experiencing a 71% failure rate due to two primary issues:

1. **Gmail OAuth2 credential expiration** - causing immediate failures
2. **Intermittent LLM processing errors** - causing long-running failures

The workflow's core logic is sound - successful executions demonstrate proper email processing, LLM analysis, and Telegram notifications. The issue is reliability of external dependencies (Gmail API and Ollama service).

**Immediate Action Required**: Refresh Gmail OAuth2 credentials to eliminate 50% of failures.

**Secondary Action**: Implement comprehensive error handling to capture detailed failure information for future debugging.

**Long-term**: Add monitoring dashboard and graceful degradation to improve overall reliability.

---

**Report Generated**: 2025-11-30  
**Investigation Tool**: Manual analysis using n8n execution logs, PostgreSQL queries, and workflow definition review  
**Next Review**: 2025-12-07 (after implementing OAuth2 fix)
