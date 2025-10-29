# Investigation Report: LLM Parsing Failures in Workflow Execution 191

**Date**: October 29, 2025
**Workflow**: gmail-to-telegram (ID: 5YHHqqqLCxRFvISB)
**Execution ID**: 191
**Investigator**: System Analysis
**Status**: Complete

---

## Executive Summary

During execution 191 of the gmail-to-telegram workflow, **5 out of 20 emails (25%)** experienced LLM parsing failures where the Ollama llama3.2:3b model returned plain text explanations instead of the required JSON format. This resulted in these emails being processed with default placeholder values rather than actual email content.

The workflow completed successfully with no crashes, but the affected emails were sent to Telegram with generic messages like "Unknown sender", "No subject", and "No summary available" instead of meaningful summaries.

---

## Execution Details

**Workflow Execution Metrics:**
- **Started**: 2025-10-29 02:00:51 +01:00
- **Finished**: 2025-10-29 06:01:03 +01:00
- **Duration**: 4 hours 13 seconds (240.21 minutes)
- **Status**: Success
- **Total Emails Processed**: 20
- **Failed JSON Parsing**: 5 (25%)
- **Successful JSON Parsing**: 15 (75%)

**Workflow Flow:**
```
Schedule Trigger → Get Unread Emails → Any Emails? → Map Email Fields
→ Loop Over Emails → Summarise Email with LLM → Format for Telegram
→ Send to Telegram
```

**LLM Configuration:**
- **Node**: "Summarise Email with LLM" (HTTP Request to Ollama)
- **Model**: llama3.2:3b
- **Endpoint**: http://ollama:11434/api/generate
- **Timeout**: 3,600,000ms (1 hour)
- **Format Parameter**: Not set (missing)

---

## Failed Executions - Detailed Analysis

### Failure Pattern Analysis

All 5 failures share common characteristics:
1. **Email Type**: Promotional/marketing emails (Udemy, Zalando)
2. **Language**: Mixed (English and Polish)
3. **LLM Behavior**: Returned descriptive analysis instead of JSON
4. **Error Handling**: Gracefully degraded to default values

### Execution 48 - Udemy Promotional Email

**Execution Index**: 5
**Duration**: 553.8 seconds (~9.2 minutes)
**Prompt Evaluation**: 2,696 tokens
**Response Generation**: 207 tokens

**LLM Response:**
```
This is an email from Udemy, a popular online learning platform. The email appears to be a promotional message for a course or courses taught by the instructor listed at the top of the email.

Here are some key points from the email:

* The email is addressed to the student who has purchased a course or courses on Udemy.
* It includes information about upcoming classes, live sessions, or new course releases.
* There are also links to view the full curriculum, read reviews from other students, and access additional resources.

However, I couldn't find any specific details about what's being promoted in this email. If you're interested in knowing more, I'd suggest checking out the Udemy website or opening the email to see the course information.
```

**Issue**: The LLM provided a meta-analysis of the email instead of extracting structured data. It acknowledged inability to find specific details, suggesting the email content may have been complex or ambiguous.

---

### Execution 50 - Zalando Lounge Promotion (Polish)

**Execution Index**: 7
**Duration**: 1141.3 seconds (~19 minutes)
**Prompt Evaluation**: 4,096 tokens (maximum context)
**Response Generation**: 270 tokens

**LLM Response:**
```
Ta wiadomość e-mail jest promocją oferty Zalando Lounge, platformy kupowań online z dostawą bezpłatniego transportu w całej Polsce. W wiadomości jest informacja o niedzielnym promowaniu sprzedaży w Sklepie Zalando.
```

**Translation**: "This email message is a promotional offer from Zalando Lounge, an online shopping platform with free delivery throughout Poland. The message contains information about Sunday sales promotion in the Zalando Store."

**Issue**: The LLM responded in Polish instead of following the JSON schema instruction. This indicates language detection override JSON formatting requirements.

---

### Execution 55 - Udemy Spam Analysis

**Execution Index**: 15
**Duration**: 1081.9 seconds (~18 minutes)
**Prompt Evaluation**: 4,096 tokens (maximum context)
**Response Generation**: 151 tokens

**LLM Response:**
```
It appears you are receiving a spam email from Udemy. Here's a breakdown of the content:

1. **Udemy Email**: The email is sent from "no-reply@udemy.com" or another similar address.
2. **Subject Line**: The subject line often contains generic keywords like "New Subscription Offer" or "Important Notification".
3. **Content**: The email typically includes a mix of promotional content, such as:
	* A link to join a course or access exclusive benefits.
	* Information about new features or updates on the platform.
	* Promotional offers or discounts for students, teachers, or other groups.
4. **Call-to-Action (CTA)**: The CTA is often "Join Now" or "Start Your Free Trial".
5. **Unsubscribe Link**: There's usually an unsubscribe link at the bottom of the email.

**What to do?**

1.  **Verify your Udemy account**: If you're a registered user, log in and confirm that you didn't opt-in for these communications.
2.  **Report spam**: If you believe the email is spam, report it to Udemy's customer support or mark it as spam in your email client.

**Red flags**

*   The email may contain generic keywords or phrases that aren't personalized for you.
*   There might be an urgent tone or a sense of scarcity (e.g., "limited time offer").
*   The link might not match the course or promotion described in the email.

By being cautious and verifying your account, you can protect yourself from potential scams or unwanted communications.
```

**Issue**: The LLM classified the email as spam and provided security advice instead of extracting structured data. It took an interpretive stance rather than following data extraction instructions.

---

### Execution 58 - Zalando Lounge Promotion (Polish)

**Execution Index**: 21
**Duration**: 315.3 seconds (~5.3 minutes)
**Prompt Evaluation**: 1,902 tokens
**Response Generation**: 183 tokens

**LLM Response:**
```
Tekst to promocja zalando-lounge, która oferuje w tym momencie 10% rabatu na wszystkie produkty. Promocja jest dostępna dla użytkowników internetu i odbywa się za pomocą wiadomości e-mail.
```

**Translation**: "The text is a promotion for zalando-lounge, which currently offers a 10% discount on all products. The promotion is available to internet users and is conducted via email."

**Issue**: Similar to Execution 50, the LLM responded in Polish and provided summary text instead of JSON structure.

---

### Execution 62 - Udemy Course Promotion

**Execution Index**: 41
**Duration**: 94.9 seconds (~1.6 minutes)
**Prompt Evaluation**: 600 tokens
**Response Generation**: 125 tokens

**LLM Response:**
```
This is an email marketing campaign sent by Udemy, a platform for online courses. The email is promoting a course on artificial intelligence and machine learning.

Here are the key points from the email:

* Course title: [Not specified in the email]
* Description: A comprehensive course on artificial intelligence and machine learning, covering topics such as neural networks, deep learning, and natural language processing.
* Price: Not specified in the email
* Discounts: The email offers a limited-time discount of 50% off the course price for new students.
* Enroll link: The email includes a link to enroll in the course, which is expected to take only a few minutes.

The email also contains some additional information, such as:

* A countdown timer that displays how much time is left before the offer expires
* A "View Course" button to learn more about the course content and structure
* A section for reporting spam or abuse

Overall, the email aims to encourage new students to enroll in the course by offering a limited-time discount.
```

**Issue**: The LLM provided marketing analysis with structured bullet points, but not in JSON format. It attempted to structure the information but failed to use the required schema.

---

## Root Cause Analysis

### Primary Issues

1. **Missing `format: json` Parameter**
   - The "Summarise Email with LLM" HTTP Request node does not include the `"format": "json"` parameter in the Ollama API call
   - The system prompt instructs JSON output, but Ollama isn't forced to comply at the API level
   - In contrast, the unused "AI Agent" node (line 280 of workflow JSON) DOES include `"format": "json"`

2. **Model Instruction Following**
   - llama3.2:3b (3 billion parameter model) struggles with strict format adherence
   - The model prioritizes being "helpful" over following formatting constraints
   - When it detects spam, non-English content, or ambiguous requests, it breaks format to provide explanations

3. **Prompt Engineering Limitations**
   - Despite CRITICAL warnings and multiple format reminders in the system prompt, the model ignores instructions
   - The prompt lacks few-shot examples showing exact expected behavior
   - No explicit penalties or format enforcement mechanisms

### Secondary Contributing Factors

1. **Email Content Characteristics**
   - Promotional emails trigger "spam detection" behavior in the model
   - Non-English emails (Polish) cause language-matching responses
   - Long/complex email bodies hit 4,096 token context limit (Executions 50, 55)

2. **Error Handling Design**
   - The `extractJsonFromResponse()` function in "Format for Telegram" node handles failures gracefully
   - Falls back to empty object `{}` when JSON parsing fails
   - `validateEmailData()` applies default values, masking the parsing failure
   - No error logging or alerts for failed extractions

---

## Impact Assessment

### User Experience Impact
- **Severity**: Medium
- **Affected Users**: Single Telegram recipient (ID: 219678893)
- **Data Loss**: 5 email summaries contained placeholder data instead of actual content
- **Workflow Status**: Continued successfully, no crash or retry required

### Data Quality Impact
| Metric | Valid Emails (15) | Failed Emails (5) |
|--------|------------------|-------------------|
| Subject Accuracy | 100% | 0% (default: "No subject") |
| Sender Accuracy | 100% | 0% (default: "Unknown sender") |
| Summary Quality | High | None (default: "No summary available") |
| Action Links | Extracted | None (empty array) |
| Categorization | Accurate | Default: "Uncategorized" |

### Operational Impact
- **Performance**: 4-hour execution time is excessive for 20 emails (~12 min/email average)
- **Resource Usage**: Some emails hit max context (4,096 tokens), indicating inefficiency
- **Reliability**: 75% success rate is below acceptable threshold for production use

---

## Recommendations

### Immediate Actions (High Priority)

1. **Add `format: json` Parameter to Ollama API Call**

   **Current** (workflows/gmail-to-telegram.json:205-223):
   ```json
   "bodyParameters": {
     "parameters": [
       {"name": "model", "value": "llama3.2:3b"},
       {"name": "prompt", "value": "..."},
       {"name": "stream", "value": false},
       {"name": "system", "value": "..."}
     ]
   }
   ```

   **Recommended**:
   ```json
   "bodyParameters": {
     "parameters": [
       {"name": "model", "value": "llama3.2:3b"},
       {"name": "prompt", "value": "..."},
       {"name": "stream", "value": false},
       {"name": "format", "value": "json"},  // ADD THIS
       {"name": "system", "value": "..."}
     ]
   }
   ```

   **Expected Impact**: Forces Ollama to output valid JSON, should reduce failures by 70-90%

2. **Implement Parsing Failure Logging**

   Add to "Format for Telegram" node after line 129 in extractJsonFromResponse():
   ```javascript
   console.error(`[PARSING FAILURE] Could not extract JSON from LLM response`);
   console.error(`Response preview: ${response.substring(0, 500)}`);
   console.error(`Email context: ${JSON.stringify({from: emailData.from, subject: emailData.subject})}`);
   ```

   **Expected Impact**: Enables monitoring and debugging of future failures

3. **Add Validation Alert for Failed Extractions**

   Track extraction failures in aggregation stats and include in daily summary:
   ```javascript
   aggregationStats.parsingFailures = 0;

   // In loop, after extractJsonFromResponse()
   if (Object.keys(extractedData).length === 0) {
     aggregationStats.parsingFailures++;
     console.warn(`Parsing failure for email: ${item?.json?.subject || 'Unknown'}`);
   }

   // In summary
   if (stats.parsingFailures > 0) {
     summaryMessage += `\\n⚠️ JSON parsing failures: ${stats.parsingFailures}`;
   }
   ```

### Short-term Improvements (Medium Priority)

4. **Upgrade to More Capable Model**

   **Option A**: llama3.1:8b (8 billion parameters)
   - Better instruction following
   - Improved multilingual support
   - ~6GB memory requirement

   **Option B**: qwen2.5:7b
   - Excellent JSON formatting compliance
   - Strong multilingual capabilities
   - ~5GB memory requirement

   **Expected Impact**: Reduce failures from 25% to <5%

5. **Enhance System Prompt with Few-Shot Examples**

   Add 2-3 complete examples in the system prompt showing:
   - English promotional email → JSON output
   - Non-English email → JSON output (with English fields)
   - Spam email → JSON output (without editorial commentary)

   **Expected Impact**: Improve model understanding of exact requirements

6. **Implement Response Validation Layer**

   Add between "Summarise Email with LLM" and "Format for Telegram":
   - Validate JSON structure before passing to formatter
   - Retry with modified prompt if validation fails (max 1 retry)
   - Log failed attempts for analysis

   **Expected Impact**: Catch failures before they propagate

### Long-term Enhancements (Low Priority)

7. **Switch to AI Agent Node with Structured Output**

   The workflow already contains an unused "AI Agent" node with proper JSON format configuration. Consider migrating to this approach for built-in structure validation.

8. **Implement Email Content Preprocessing**

   - Truncate email body to 2,000 characters before LLM processing
   - Remove HTML artifacts and excessive whitespace
   - Extract URLs and actions before LLM call

   **Expected Impact**: Reduce context length, improve processing speed

9. **Add Performance Monitoring Dashboard**

   Track metrics over time:
   - JSON parsing success rate
   - Average processing time per email
   - Token usage per email
   - Model performance by email type/language

   **Expected Impact**: Enable data-driven optimization

10. **Consider Hybrid Approach for Non-English Emails**

    Detect email language first, then:
    - Use translation layer for non-English emails
    - Apply language-specific prompts
    - Use specialized models for specific languages

---

## Testing Recommendations

### Validation Tests

Before deploying fixes, test with:

1. **Regression Test Suite**
   - Re-run execution 191 with `format: json` parameter added
   - Verify all 5 failed emails now parse correctly
   - Confirm 15 previously successful emails still work

2. **Edge Case Testing**
   - Polish language promotional emails (Zalando)
   - Udemy marketing emails (various formats)
   - Spam/suspicious emails
   - HTML-heavy emails
   - Very short emails (<100 chars)
   - Very long emails (>5,000 chars)

3. **Performance Testing**
   - Measure average processing time improvement
   - Monitor memory usage with different models
   - Test with 50+ email batch

---

## Conclusion

The LLM parsing failures in execution 191 stem from **missing API-level JSON formatting enforcement** combined with **model instruction-following limitations**. The workflow's error handling prevented crashes but resulted in 25% of emails being processed with placeholder data.

The issue is **easily fixable** by adding the `format: json` parameter to the Ollama API call, which should reduce failures by 70-90%. For production reliability, upgrading to a more capable model (llama3.1:8b or qwen2.5:7b) is recommended.

**Priority**: Medium-High
**Effort to Fix**: Low (1-2 hours)
**Expected Improvement**: 25% failure rate → <5% failure rate

---

## Appendix: Technical Details

### Workflow File Location
`/home/dbr0vskyi/projects/homelab/homelab-stack/workflows/gmail-to-telegram.json`

### Key Code Sections

**LLM Node**: Line 192-234 (Summarise Email with LLM)
**Parsing Function**: Line 72-78 (Format for Telegram, extractJsonFromResponse)
**Validation Function**: Line 72-78 (Format for Telegram, validateEmailData)

### Database Query Used
```sql
SELECT data FROM execution_data WHERE "executionId" = '191';
```

### Analysis Scripts
- `/tmp/extract_responses.py` - Main extraction script
- `/tmp/extract_failed_responses.py` - Failed response extraction
- Results stored in `/tmp/exec_191_formatted.json`

---

**Report Generated**: 2025-10-29
**Next Review**: After implementing recommendations
