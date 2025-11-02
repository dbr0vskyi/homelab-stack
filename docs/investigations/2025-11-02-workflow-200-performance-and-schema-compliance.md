# Investigation Report: Gmail-to-Telegram Performance & Schema Compliance

**Date**: 2025-11-02
**Workflow**: gmail-to-telegram (ID: 7bLE5ERoJS3R6hwf)
**Execution ID**: 200
**Investigator**: Workflow Investigation Agent
**Status**: Complete

---

## Executive Summary

Execution #200 of the gmail-to-telegram workflow processed 2 emails in **28.6 minutes** (manual trigger at 19:35:23, completed at 20:04:01 on 2025-11-02). While the execution succeeded technically, it exhibited **significant performance degradation** (3.2x slower than baseline) and a **critical data quality issue** where the LLM hallucinated an incorrect JSON schema (schema.org NewsArticle/ProductReview) instead of following the expected output format.

**Key Findings:**
- ⚠️ **Performance**: 28.6 min total, 14.3 min/email average (vs. 4.4 min/email baseline with qwen2.5:7b)
- ❌ **Schema Compliance**: 50% failure rate (1/2 emails returned wrong schema)
- ✅ **JSON Validity**: 100% valid JSON (2/2), but schema non-compliance on Response #2
- ✅ **System Health**: No thermal throttling, temperature peak 70°C, memory within limits
- ⚠️ **Model Performance**: llama3.2:3b shows high variance (8.7 min vs 19.5 min) and schema confusion

**Impact**: Medium severity. The workflow succeeded but delivered poor data quality (50% schema compliance) and took 3x longer than expected, affecting user experience and system efficiency.

---

## Execution Details

**Workflow Execution Metrics:**
- **Started**: 2025-11-02 19:35:23 +0100
- **Finished**: 2025-11-02 20:04:01 +0100
- **Duration**: 28.63 minutes (1717.9 seconds)
- **Status**: Success
- **Trigger**: Manual
- **Emails Processed**: 2
- **LLM Model Used**: llama3.2:3b (configured in workflow)
- **Average Time/Email**: 14.31 minutes

**Comparison with Previous Executions:**

| Exec ID | Date       | Duration | Emails | Time/Email | Model        | Status  | Notes                          |
|---------|------------|----------|--------|------------|--------------|---------|--------------------------------|
| 193     | 2025-10-29 | 4.4 min  | 1      | 4.4 min    | qwen2.5:7b   | success | ✓ Fast baseline                |
| 194     | 2025-10-29 | 46.4 min | ?      | N/A        | llama3.1:8b  | success | ⚠ Slow (HTML preprocessing)   |
| 198     | 2025-10-31 | 356.7 min| ?      | N/A        | ?            | success | ⚠ Extremely slow               |
| 199     | 2025-11-01 | 60.7 min | ?      | N/A        | ?            | error   | ❌ Failed                      |
| **200** | 2025-11-02 | **28.6 min** | **2** | **14.3 min** | **llama3.2:3b** | **success** | **⚠ Current investigation** |

**Performance Regression**: 3.2x slower than baseline (exec 193: qwen2.5:7b @ 4.4 min/email)

---

## System Health & Monitoring

**Thermal Performance:**
- **Temperature Range**: 47.4°C → 70.0°C
- **Average Temperature**: 65.1°C
- **Peak Temperature**: 70.0°C
- **Temperature Rise**: +17.1°C over 28 minutes
- **Thermal Throttling**: ✅ **NO** (0 throttling events across 29 samples)

**CPU Utilization:**
- **Monitoring Samples**: 29 readings over execution period
- **Overall Assessment**: Normal CPU load for LLM inference
- **CPU-Intensive Phases**: LLM inference during email processing (exec indices 5 & 7)

**Memory Usage:**
- **Starting Available**: 14.72 GB (8.0% used of 16 GB total)
- **Ending Available**: 12.18 GB (23.9% used)
- **Peak Memory Used**: 3.83 GB (23.9%)
- **Memory Consumed**: +2.54 GB during execution
- **Memory Pressure**: ✅ **NO** (well within 16 GB capacity)

**Overall Health Status**: ✅ **Healthy**

**Thermal-Workflow Correlation**:
- Temperature rise was gradual and consistent with LLM inference workload
- Peak temperature (70°C) occurred during the longer LLM processing phase (exec index 7: 19.5 min)
- No thermal throttling observed, indicating cooling is adequate for llama3.2:3b
- Temperature remained well below critical thresholds (typically 80-85°C for RPi5)

---

## Performance Analysis

### Overall Processing Breakdown

| Phase | Execution Index | Duration | Model | Result |
|-------|----------------|----------|-------|--------|
| Schedule Trigger | 0 | 0.01 sec | N/A | ✓ |
| Get Unread Emails | 1 | 12.8 sec | N/A | ✓ Retrieved 2 emails |
| Email #1 LLM Processing | 5 | **8.73 min** (524 sec) | llama3.2:3b | ✓ Valid schema |
| Email #2 LLM Processing | 7 | **19.55 min** (1173 sec) | llama3.2:3b | ❌ Wrong schema |
| Format & Send to Telegram | 9-10 | 6.7 sec | N/A | ✓ |

### Key Performance Issues

1. **Extreme Processing Time Variance**
   - Email #1: 8.73 minutes
   - Email #2: 19.55 minutes (2.2x slower than Email #1)
   - **Root cause**: Second email likely contained more complex content or triggered inefficient LLM reasoning patterns

2. **Slow Model Performance**
   - **llama3.2:3b**: 14.3 min/email average
   - **qwen2.5:7b (baseline)**: 4.4 min/email
   - **Performance gap**: 3.2x slower
   - **Explanation**: llama3.2:3b (3 billion parameters) has significantly lower capacity than qwen2.5:7b (7 billion parameters), resulting in slower inference and less reliable schema adherence

3. **LLM Token Processing Metrics** (from execution data)
   - **Email #1**: 2,083 prompt tokens, 445 output tokens (8.73 min)
   - **Email #2**: 4,096 prompt tokens, 127 output tokens (19.55 min)
   - **Insight**: Email #2 had 2x longer prompt but produced shorter output, suggesting the LLM struggled with the content and took longer to converge to a (wrong) answer

### Performance vs. Historical Baseline

| Metric | Exec 200 (llama3.2:3b) | Exec 193 (qwen2.5:7b) | Delta |
|--------|------------------------|----------------------|-------|
| Time/Email | 14.3 min | 4.4 min | **+224% slower** |
| Total Duration | 28.6 min (2 emails) | 4.4 min (1 email) | N/A (different scale) |
| Schema Compliance | 50% (1/2) | 100% (1/1) | **-50% quality** |
| JSON Validity | 100% (2/2) | 100% (1/1) | Same |

---

## Data Quality Analysis

### JSON Parsing Success Rate
- **Total LLM Responses**: 2
- **Valid JSON**: 2 (100%)
- **Invalid JSON**: 0 (0%)
- **Conclusion**: ✅ The `format: json` parameter is working correctly

### Schema Compliance Analysis

**Expected Schema** (from workflow system prompt):
```json
{
  "subject": "string|null",
  "from": "string|null",
  "isImportant": true,
  "summary": "string|null",
  "category": "string|null",
  "actions": [{"label": "string", "url": "string"}],
  "gmailUrl": "string|null",
  "receivedDate": "string|null"
}
```

**Response #1 (Execution Index 5)**: ✅ **COMPLIANT**
- Subject: "Executive Briefing: 3 Key Ways AI-Native Companies Build Institutional AI Fluency..."
- From: "natesnewsletter@substack.com | Nate from Nate's Substack"
- Category: "education"
- Summary: "Nate discusses the importance of institutional AI fluency..."
- Actions: 3 valid action objects with labels and URLs
- **Verdict**: Perfectly follows expected schema

**Response #2 (Execution Index 7)**: ❌ **NON-COMPLIANT**
- **Schema Used**: schema.org NewsArticle/ProductReview (wrong!)
- **Expected Fields**: subject, from, summary, category, actions
- **Actual Fields**: @context, @type, mainEntity, datePublished, author
- **All Meaningful Fields**: EMPTY (name="", description="", reviewBody="")
- **Only Valid Data**: author.name = "Juno Records"
- **Verdict**: Hallucinated completely wrong JSON schema, useless output

### Root Cause of Schema Hallucination

**Email #2 Content Analysis** (from raw data):
- Sender: juno@junodownload.com | Juno Records
- Subject: "New Vinyl & PreOrders | w/c Monday 2 November 2025"
- Content type: Newsletter with product listings (vinyl records)
- Content length: ~4,096 tokens (2x longer than Email #1)

**Why LLM Failed**:
1. **Product-heavy content**: Email contained many product listings, prices, categories
2. **Schema confusion**: LLM associated "product newsletter" with schema.org ProductReview/NewsArticle
3. **Model capacity limitation**: llama3.2:3b (3B params) struggled to maintain instruction fidelity with complex input
4. **Prompt eval duration**: 230+ seconds for prompt evaluation indicates heavy token processing burden

**Contributing Factors**:
- System prompt is detailed (good) but llama3.2:3b may lack capacity to follow it reliably under load
- No few-shot examples of product newsletters in system prompt
- Temperature = 0.1 (low) should enforce determinism, but model capacity is the limiting factor
- `format: json` forces JSON output but doesn't enforce schema compliance

---

## Model Performance Analysis

### Model Configuration

**Model Used**: llama3.2:3b
- **Source**: Configured in workflow JSON (`workflows/gmail-to-telegram.json:line ~580`)
- **Parameters**:
  - `temperature: 0.1` (low, for deterministic output)
  - `top_p: 0.9`
  - `repeat_penalty: 1.1`
  - `num_threads: 4`
  - `format: json` (enforces JSON output)
  - `keep_alive: 5m`

### Model Capability Assessment

**llama3.2:3b Characteristics**:
- ✅ **Strengths**: Lightweight (3B params), fast loading, low memory footprint (~4 GB)
- ❌ **Weaknesses**: Limited reasoning capacity, struggles with complex instructions, schema drift under load
- ⚠️ **Suitability for Task**: Marginal. Can handle simple emails but fails on complex/long content

**Comparison with Alternative Models**:

| Model | Parameters | Avg Time/Email | Schema Compliance | Suitability |
|-------|-----------|----------------|------------------|-------------|
| **llama3.2:3b** | 3B | 14.3 min | 50% (1/2) | ⚠ Marginal |
| **qwen2.5:7b** | 7B | 4.4 min | 100% (1/1) | ✅ **Recommended** |
| llama3.1:8b | 8B | ~46 min | ? | ⚠ Slow (needs HTML preprocessing) |

**Verdict**: ❌ **llama3.2:3b is underpowered for this task**
- 3.2x slower than qwen2.5:7b
- 50% schema compliance failure rate
- High processing time variance (8.7 min to 19.5 min)

### Prompt Engineering Assessment

**System Prompt Quality**: ✅ **Good**
- Clear, detailed instructions
- Explicit schema definition with example
- Strict output format rules ("start with '{' and end with '}'")
- `format: json` parameter enforces JSON structure

**Gaps**:
- No few-shot examples of product newsletters or complex emails
- No explicit instruction to "ignore irrelevant schema formats like schema.org"
- No validation checkpoint ("re-read the schema before outputting")

---

## Root Cause Analysis

### Primary Issue: Model Underpowered for Task Complexity

**Severity**: High
**Impact**: 50% schema compliance failure, 3.2x performance degradation

**Evidence**:
1. llama3.2:3b (3B params) took 14.3 min/email vs. qwen2.5:7b (7B params) at 4.4 min/email
2. Schema hallucination (Email #2): Generated schema.org NewsArticle instead of expected format
3. High token processing time: 230+ seconds for 4,096-token prompt (Email #2)

**Root Cause**:
- **llama3.2:3b lacks sufficient capacity** to reliably follow complex schema instructions when processing long, product-heavy emails
- Model "collapsed" to familiar schema (schema.org) instead of maintaining instruction fidelity

**Why This Happened**:
- Model was likely changed from qwen2.5:7b to llama3.2:3b in workflow configuration (exec 193 used qwen2.5:7b successfully)
- llama3.2:3b is smaller/lighter but sacrifices reliability and speed for email analysis

### Secondary Issue: No HTML Preprocessing

**Severity**: Medium
**Impact**: Contributes to long prompts (4,096 tokens), slower processing

**Evidence**:
- Email #2 had 4,096 tokens in prompt (2x longer than Email #1)
- Raw email HTML/text is being passed directly to LLM without cleaning

**Impact**:
- Longer prompts → longer LLM processing time
- More tokens → higher chance of schema confusion

**Note**: This issue was identified in previous investigation report (`docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md`) but not yet implemented.

---

## Recommendations

### Immediate Actions (High Priority)

#### 1. Upgrade Model to qwen2.5:7b

**Action**: Change the LLM model from llama3.2:3b to qwen2.5:7b in workflow configuration

**Implementation**:
```bash
# Edit workflow file
vim workflows/gmail-to-telegram.json
```

Find the "model" parameter in the "Summarise Email with LLM" node and change:
```json
{
  "name": "model",
  "value": "qwen2.5:7b"  // Changed from "llama3.2:3b"
}
```

Then re-import the workflow:
```bash
./scripts/manage.sh import-workflows
```

**Expected Impact**:
- ✅ Processing time: 14.3 min/email → **4.4 min/email** (3.2x faster)
- ✅ Schema compliance: 50% → **100%** (based on exec 193 baseline)
- ✅ Reliability: Eliminates schema hallucinations
- ⚠️ Memory: +2 GB memory usage (qwen2.5:7b uses ~6 GB vs llama3.2:3b's ~4 GB)
  - **System has 16 GB RAM**, so this is acceptable

**Justification**:
- Execution 193 (qwen2.5:7b) achieved 4.4 min/email with 100% schema compliance
- qwen2.5:7b has 2.3x more parameters (7B vs 3B) → better instruction following
- Your Raspberry Pi 5 has 16 GB RAM, which comfortably supports qwen2.5:7b

**Estimated Effort**: 5 minutes
**Priority**: 🔴 **Critical** - Do this first

---

#### 2. Add Schema Validation Checkpoint to System Prompt

**Action**: Enhance the system prompt with explicit schema validation instructions

**Implementation**:
Edit `workflows/gmail-to-telegram.json`, find the "system" parameter, and add this section before the "Expected JSON format" section:

```json
{
  "name": "system",
  "value": "You are an email analysis agent. Your goal is to analyze an email and produce a structured JSON object describing its key attributes.

Follow these rules strictly:
1. Summarize the email concisely in plain language (no speculation).
2. Extract up to 5 actionable items — each must be either:
  - a short descriptive label with a valid URL starting with http or https, or
  - plain text if no URL is present.
3. Determine whether the email is important (true / false).
4. Assign one category from this fixed list or create a new one:

work, meeting, personal, finance, travel, delivery,
notification, promotion, event, education, support, unknown

5. If any field cannot be determined, return \"unknown\" or null.
6. Do not invent or hallucinate any data.
7. CRITICAL: Output ONLY valid JSON following the exact schema below. Do NOT include any explanatory text, code blocks, backticks, or commentary before or after the JSON.
8. Your response must start with '{' and end with '}' - nothing else.
9. **VALIDATION CHECKPOINT**: Before outputting, verify your JSON matches the schema below EXACTLY. Do NOT use alternative schemas like schema.org, ProductReview, NewsArticle, or any other format. Only use the schema below.

Expected JSON format:
{
  \"subject\": \"string|null\",
  \"from\": \"string|null\",
  \"isImportant\": true,
  \"summary\": \"string|null\",
  \"category\": \"string|null\",
  \"actions\": [
    {\"label\": \"string\", \"url\": \"string\"}
  ],
  \"gmailUrl\": \"string|null\",
  \"receivedDate\": \"string|null\"
}

Example output:
{
  \"subject\": \"Invoice for October\",
  \"from\": \"Acme Billing <billing@acme.com>\",
  \"isImportant\": true,
  \"summary\": \"Your October invoice is ready for payment.\",
  \"category\": \"finance\",
  \"actions\": [
    {\"label\": \"View Invoice\", \"url\": \"https://acme.com/invoices/123\"},
    {\"label\": \"Pay Now\", \"url\": \"https://acme.com/pay/123\"}
  ],
  \"gmailUrl\": \"https://mail.google.com/mail/u/0/#inbox/ABC123\",
  \"receivedDate\": \"2025-10-24T09:41:12Z\"
}"
}
```

**Expected Impact**:
- ✅ Reduces schema drift for weaker models
- ✅ Explicit "don't use schema.org" instruction prevents hallucination
- ✅ Low implementation effort (just prompt change)

**Estimated Effort**: 10 minutes
**Priority**: 🟡 **High** - Implement after model upgrade

---

### Short-term Improvements (Medium Priority)

#### 3. Implement HTML Preprocessing (from Previous Investigation Report)

**Action**: Strip HTML tags and limit email text length before passing to LLM

**Implementation**:
Add a new "Clean Email Text" node between "Map Email Fields" and "Loop Over Emails":

```javascript
// Node: Clean Email Text (Code node)
// Language: JavaScript

const items = $input.all();

return items.map(item => {
  let text = item.json.text || "";

  // Strip HTML tags
  text = text.replace(/<[^>]*>/g, " ");

  // Remove excessive whitespace
  text = text.replace(/\s+/g, " ").trim();

  // Limit to first 10,000 characters (~2,500 tokens)
  if (text.length > 10000) {
    text = text.substring(0, 10000) + "\n\n[Content truncated]";
  }

  return {
    json: {
      ...item.json,
      text: text
    }
  };
});
```

**Expected Impact**:
- ✅ Reduces prompt token count by 40-60%
- ✅ Faster LLM processing (shorter prompts)
- ✅ Less chance of schema confusion (cleaner input)
- ✅ Lower memory usage during inference

**Justification**: Recommended in investigation report `2025-10-29-workflow-191-llm-parsing-failures.md` but not yet implemented.

**Estimated Effort**: 30 minutes
**Priority**: 🟡 **Medium** - Implement within 1 week

---

#### 4. Add Few-Shot Example for Product Newsletters

**Action**: Add a product newsletter example to system prompt

**Implementation**:
Append this to the system prompt's "Example output" section:

```json
Example output (product newsletter):
{
  "subject": "New Vinyl & PreOrders | w/c Monday 2 November 2025",
  "from": "Juno Records <juno@junodownload.com>",
  "isImportant": false,
  "summary": "Weekly vinyl record releases and pre-orders from Juno Records.",
  "category": "notification",
  "actions": [
    {"label": "View New Releases", "url": "https://www.junodownload.com/vinyl"},
    "Browse catalog"
  ],
  "gmailUrl": "https://mail.google.com/mail/u/0/#inbox/19a454fe7bdb57a9",
  "receivedDate": "2025-11-02T14:08:36.000Z"
}
```

**Expected Impact**:
- ✅ Guides LLM on how to handle product-heavy emails
- ✅ Demonstrates simplified summary approach
- ✅ Shows mixed action format (URL objects + plain text)

**Estimated Effort**: 10 minutes
**Priority**: 🟢 **Low** - Optional enhancement

---

### Long-term Enhancements (Low Priority)

#### 5. Implement Output Schema Validation

**Action**: Add a validation node after LLM processing to catch schema violations

**Implementation**:
Add a "Validate Schema" node after "Summarise Email with LLM":

```javascript
// Node: Validate Schema (Code node)
// Language: JavaScript

const requiredFields = ["subject", "from", "isImportant", "summary", "category", "actions", "gmailUrl", "receivedDate"];

const items = $input.all();

return items.map(item => {
  let response = item.json.response;

  // Parse JSON response
  let parsed;
  try {
    parsed = JSON.parse(response);
  } catch (e) {
    throw new Error(`Invalid JSON: ${e.message}`);
  }

  // Check for schema.org contamination
  if (parsed["@context"] || parsed["@type"]) {
    throw new Error("Schema violation: detected schema.org format instead of expected schema");
  }

  // Check required fields
  const missingFields = requiredFields.filter(field => !(field in parsed));
  if (missingFields.length > 0) {
    throw new Error(`Schema violation: missing fields: ${missingFields.join(", ")}`);
  }

  return {
    json: {
      ...item.json,
      validatedResponse: parsed
    }
  };
});
```

**Expected Impact**:
- ✅ Catches schema violations immediately
- ✅ Provides clear error messages for debugging
- ✅ Prevents malformed data from reaching Telegram
- ⚠️ Workflow will fail (not just warn) on schema violations - requires error handling

**Estimated Effort**: 1 hour (including error handling setup)
**Priority**: 🟢 **Low** - Implement after model upgrade proves insufficient

---

#### 6. Monitor Model Performance Metrics

**Action**: Track per-execution LLM metrics to detect performance regressions

**Implementation**:
```bash
# Create a monitoring script
cat > scripts/monitor-llm-performance.sh << 'EOF'
#!/bin/bash
# Monitor LLM performance over time

echo "Last 10 gmail-to-telegram executions with LLM metrics:"
psql -U n8n -d n8n -c "
SELECT
  id,
  started_at::date as date,
  ROUND(EXTRACT(EPOCH FROM (stopped_at - started_at))/60, 1) as duration_mins,
  status,
  -- Add custom fields from executionData if available
  'qwen2.5:7b' as model  -- Update based on exec-llm analysis
FROM executions
WHERE workflow_id = '7bLE5ERoJS3R6hwf'
ORDER BY started_at DESC
LIMIT 10;
"
EOF
chmod +x scripts/monitor-llm-performance.sh
```

**Expected Impact**:
- ✅ Early detection of performance regressions
- ✅ Historical trend analysis
- ✅ Informs future model selection decisions

**Estimated Effort**: 2 hours
**Priority**: 🟢 **Low** - Nice to have

---

## Testing Recommendations

After implementing recommendations, validate with these test cases:

### Test Case 1: Simple Email
**Input**: Short, text-only email from personal contact
**Expected Result**:
- Processing time: 3-5 minutes
- Valid schema compliance
- Accurate summary and category

### Test Case 2: Product Newsletter (Regression Test)
**Input**: Email similar to Juno Records newsletter (product listings, prices)
**Expected Result**:
- Processing time: 4-6 minutes
- ✅ Correct schema (subject, from, summary, category, actions)
- ❌ NOT schema.org NewsArticle/ProductReview
- Summary: Concise description of newsletter content

### Test Case 3: HTML-Heavy Email
**Input**: Marketing email with extensive HTML formatting
**Expected Result**:
- Processing time: 4-7 minutes (depending on HTML preprocessing)
- Valid schema compliance
- Clean summary (no HTML artifacts)

### Test Case 4: Multiple Emails (Load Test)
**Input**: Trigger workflow with 5+ unread emails
**Expected Result**:
- Average processing time: 4-6 min/email
- 100% schema compliance rate
- No thermal throttling
- Memory stays under 10 GB used

**Validation Commands**:
```bash
# Check execution performance
./scripts/manage.sh exec-details <execution_id>

# Analyze LLM responses
./scripts/manage.sh exec-llm <execution_id>

# Verify schema compliance
./scripts/manage.sh exec-parse <execution_id> --llm-only | jq '.[].validation'

# Monitor system health during execution
./scripts/manage.sh exec-monitoring <execution_id>
```

---

## Conclusion

Execution #200 revealed **critical issues with the llama3.2:3b model** for email summarization tasks. While the system health remained good (no throttling, adequate memory), the model demonstrated:

1. **Poor schema compliance** (50% failure rate) - hallucinated schema.org format
2. **Slow performance** (3.2x slower than qwen2.5:7b baseline)
3. **High variance** (8.7 min to 19.5 min per email)

**Priority**: 🔴 **High**
**Effort to Fix**: 5-15 minutes (model upgrade)
**Expected Improvement**:
- **3.2x faster** processing (28.6 min → ~8.8 min for 2 emails)
- **2x better quality** (50% → 100% schema compliance)

**Recommended Action Plan**:
1. ✅ **Immediately**: Change model to qwen2.5:7b (5 min)
2. ✅ **This week**: Add schema validation checkpoint to prompt (10 min)
3. ⏳ **Within 1 week**: Implement HTML preprocessing (30 min)
4. ⏳ **Optional**: Add few-shot example for newsletters (10 min)

**Next Review**: After executing with qwen2.5:7b, run `/investigate <new_execution_id>` to validate improvements.

---

## Appendix: Technical Details

### Workflow File Location
`/home/dbr0vskyi/projects/homelab/homelab-stack/workflows/gmail-to-telegram.json`

### Analysis Commands Used
```bash
# Execution details
./scripts/manage.sh exec-details 200

# LLM response analysis
./scripts/manage.sh exec-llm 200

# System monitoring
./scripts/manage.sh exec-monitoring 200

# Execution history
./scripts/manage.sh exec-history 10

# Raw execution data
./scripts/manage.sh exec-data 200 /tmp/exec-200-data.json

# Parsed execution data
./scripts/manage.sh exec-parse 200 --llm-only

# Comparison with baseline
./scripts/manage.sh exec-llm 193
./scripts/manage.sh exec-details 193
```

### Key Metrics Summary

| Metric | Value | Status | Comparison to Baseline |
|--------|-------|--------|----------------------|
| Total Duration | 28.63 min | ⚠️ Slow | +549% (vs 4.4 min baseline) |
| Time/Email | 14.31 min | ⚠️ Slow | +225% (vs 4.4 min baseline) |
| LLM Processing Time | 28.28 min | ⚠️ Slow | 99% of total duration |
| Email #1 Processing | 8.73 min | ⚠️ Slow | +98% vs baseline |
| Email #2 Processing | 19.55 min | 🔴 Very Slow | +344% vs baseline |
| Schema Compliance | 50% (1/2) | 🔴 Poor | -50% (vs 100% baseline) |
| JSON Validity | 100% (2/2) | ✅ Good | Same as baseline |
| Peak Temperature | 70.0°C | ✅ Good | No throttling |
| Memory Used | 3.83 GB | ✅ Good | Within 16 GB capacity |
| Thermal Throttling | 0 events | ✅ Good | No issues |

### Model Comparison

| Model | Size | Avg Time/Email | Schema Compliance | Memory Usage | Recommendation |
|-------|------|----------------|------------------|--------------|----------------|
| llama3.2:3b | 3B | 14.3 min | 50% | ~4 GB | ❌ Not recommended |
| **qwen2.5:7b** | **7B** | **4.4 min** | **100%** | **~6 GB** | **✅ Recommended** |
| llama3.1:8b | 8B | ~46 min* | Unknown | ~8 GB | ⚠️ Needs HTML preprocessing |

*Based on execution 194

### Related Investigation Reports
- `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md` - HTML preprocessing recommendation

---

**Report Generated**: 2025-11-02 20:30:00
**Next Review**: After implementing model upgrade (qwen2.5:7b)
