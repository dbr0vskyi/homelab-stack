# Investigation Tooling Improvements

**Date**: 2025-11-02
**Context**: Analysis of manual actions during execution #200 investigation
**Goal**: Identify workflow-agnostic automation opportunities to streamline future investigations

---

## Executive Summary

During the investigation of execution #200, several manual analysis steps were performed that could be automated into reusable, workflow-agnostic scripts. This document proposes **7 new script commands** that would significantly reduce investigation time and improve consistency.

**Key Benefits**:
- ⚡ **80% faster investigations** (auto-detect regressions, baselines, schema issues)
- 🎯 **Consistent analysis** (standardized metrics and comparisons)
- 🔧 **Workflow-agnostic** (works with any n8n workflow)
- 📊 **Better insights** (automated performance trending and comparison)

**Implementation Priority**:
- **P0 (Critical)**: `exec-baseline`, `exec-regression` → 3-5 hours, instant regression detection
- **P1 (High)**: `exec-compare`, `exec-validate-schema` → 5-7 hours, performance comparison + data quality
- **P2 (Medium)**: `exec-report`, `workflow-config` → 8 hours, report automation + config audits

**Total Effort**: 18-24 hours for full implementation
**Quick Win**: Implement P0 scripts first (3-5 hours for highest value)

---

## Current State: What's Already Automated

The existing investigation tooling provides excellent data gathering capabilities:

| Command | Purpose | Status |
|---------|---------|--------|
| `exec-details <id>` | Get execution metadata (duration, status, timestamps) | ✅ Automated |
| `exec-llm <id>` | Analyze LLM responses (model, validation, summary) | ✅ Automated |
| `exec-monitoring <id>` | Get system metrics (temp, CPU, memory, throttling) | ✅ Automated |
| `exec-history <count>` | List recent executions | ✅ Automated |
| `exec-parse <id>` | Extract node outputs from execution | ✅ Automated |
| `exec-data <id> <file>` | Export raw execution data | ✅ Automated |

**Gap**: These commands provide raw data but require **manual analysis** to derive insights.

---

## Manual Actions Performed (Execution #200 Investigation)

### 1. LLM Response Deep Dive
**What I did manually**:
```python
# Custom Python script to parse /tmp/llm-analysis-200.json
import json
with open('/tmp/llm-analysis-200.json') as f:
    llm_data = json.load(f)

# Calculate metrics
total_time = sum(item['executionTime'] for item in llm_data) / 60000
avg_time = total_time / len(llm_data)

# Parse and display response content
for item in llm_data:
    resp = json.loads(item['response'])
    print(f"Subject: {resp.get('subject')}")
    print(f"Category: {resp.get('category')}")
```

**Insight gained**: Email #2 took 2.2x longer than Email #1 (19.5 min vs 8.7 min)

**Automation opportunity**: `exec-llm-detail <id>`

---

### 2. Cross-Execution Comparison
**What I did manually**:
```python
# Created comparison table for executions 193, 194, 200
executions = {
    193: {"duration_mins": 4.42, "model": "qwen2.5:7b", "emails": 1},
    194: {"duration_mins": 46.4, "model": "llama3.1:8b", "emails": None},
    200: {"duration_mins": 28.63, "model": "llama3.2:3b", "emails": 2}
}

# Calculate performance delta
baseline = 4.42  # exec 193
current = 28.63 / 2  # exec 200 avg per email
regression = (current - baseline) / baseline * 100  # +224%
```

**Insight gained**: Execution #200 is 3.2x slower than baseline (exec #193)

**Automation opportunity**: `exec-compare <id1> <id2> [id3]...`

---

### 3. Schema Violation Detection
**What I did manually**:
```python
# Analyzed LLM response #2 to detect schema mismatch
response = json.loads(llm_data[1]['response'])

# Expected schema
expected = ["subject", "from", "summary", "category", "actions", "gmailUrl", "receivedDate"]

# Actual schema
actual = response.keys()  # ['@context', '@type', 'mainEntity', 'datePublished', 'author']

# Detected: schema.org NewsArticle instead of expected format
```

**Insight gained**: 50% schema compliance failure (1/2 emails used wrong schema)

**Automation opportunity**: `exec-validate-schema <id> [--schema file.json]`

---

### 4. Baseline Identification
**What I did manually**:
```bash
# Visually scanned exec-history output
./scripts/manage.sh exec-history 10

# Manually selected exec 193 as baseline:
# - Shortest duration (4.4 min)
# - Success status
# - Same workflow
# - Recent (2025-10-29)

# Retrieved baseline details for comparison
./scripts/manage.sh exec-details 193
./scripts/manage.sh exec-llm 193
```

**Insight gained**: Exec #193 (qwen2.5:7b, 4.4 min/email) is optimal baseline

**Automation opportunity**: `exec-baseline [workflow_name]`

---

### 5. Model Configuration Extraction
**What I did manually**:
```bash
# Find configured model in workflow JSON
grep -A 10 '"name": "model"' workflows/gmail-to-telegram.json

# Extract LLM parameters
python3 -c "import json; data=json.load(open('workflows/gmail-to-telegram.json')); ..."
```

**Insight gained**: Workflow configured with llama3.2:3b (changed from qwen2.5:7b)

**Automation opportunity**: `workflow-config <workflow_name>`

---

### 6. Performance Regression Detection
**What I did manually**:
```python
# Calculated performance delta
baseline_time_per_email = 4.42  # min (exec 193)
current_time_per_email = 14.31  # min (exec 200)

regression_pct = (current - baseline) / baseline * 100  # +224%
severity = "HIGH" if regression_pct > 100 else "MEDIUM"
```

**Insight gained**: 3.2x performance regression, HIGH severity

**Automation opportunity**: `exec-regression <id> [--baseline <baseline_id>]`

---

### 7. Report Generation
**What I did manually**:
- Created markdown structure (executive summary, sections, tables)
- Filled in all metrics from previous analysis
- Generated recommendations with code examples
- Formatted with proper markdown syntax
- Saved to `docs/investigations/`

**Time spent**: ~30 minutes

**Automation opportunity**: `exec-report <id> [--template full|quick]`

---

## Proposed New Script Commands

### Priority 0: Critical (Implement First)

#### 1. `exec-baseline [workflow_name] [--count N]`

**Purpose**: Auto-identify the best recent execution to use as performance baseline

**Algorithm**:
```python
def find_baseline(workflow_name, count=10):
    # Get last N successful executions
    executions = get_executions(workflow_name, status='success', limit=count)

    # Rank by:
    # 1. Success rate (100% preferred)
    # 2. Duration (prefer fastest)
    # 3. Recency (prefer recent within 7 days)

    baseline = min(executions, key=lambda e: (
        e.duration_seconds,  # Primary: fastest
        -e.timestamp         # Secondary: most recent
    ))

    return baseline
```

**Output**:
```
[INFO] Finding baseline execution for 'gmail-to-telegram'...

Baseline Execution: #193
  Date: 2025-10-29
  Duration: 4.4 min
  Status: success
  Model: qwen2.5:7b (extracted from LLM analysis)

Reason: Fastest successful execution in last 10 runs
Compared to 10 recent executions:
  - 8 successful (80% success rate)
  - Avg duration: 154.3 min
  - #193 is 35x faster than average

Use: ./scripts/manage.sh exec-compare 200 193
```

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_baseline()`
- Database query: PostgreSQL, `executions` table
- Dependencies: `exec-details`, `exec-llm` (for model extraction)

**Workflow-Agnostic**: ✅ Yes - uses workflow_name or infers from execution ID

**Estimated Effort**: 1-2 hours

---

#### 2. `exec-regression <id> [--baseline <baseline_id>] [--threshold PCT]`

**Purpose**: Auto-detect performance regressions by comparing against baseline

**Algorithm**:
```python
def detect_regression(execution_id, baseline_id=None, threshold=50):
    # Get current execution
    current = get_execution(execution_id)

    # Auto-find baseline if not specified
    if not baseline_id:
        baseline = find_baseline(current.workflow_name)
    else:
        baseline = get_execution(baseline_id)

    # Calculate deltas
    duration_delta = (current.duration - baseline.duration) / baseline.duration * 100

    # Classify severity
    if duration_delta > 200:
        severity = "CRITICAL"
    elif duration_delta > 100:
        severity = "HIGH"
    elif duration_delta > threshold:
        severity = "MEDIUM"
    else:
        severity = "NORMAL"

    return {
        "regression_detected": duration_delta > threshold,
        "severity": severity,
        "duration_delta_pct": duration_delta,
        "baseline": baseline,
        "current": current
    }
```

**Output**:
```
Performance Regression Analysis: Execution #200
═══════════════════════════════════════════════════════════
Baseline: #193 (auto-detected)
  Date: 2025-10-29
  Duration: 4.4 min
  Model: qwen2.5:7b

Current: #200
  Date: 2025-11-02
  Duration: 28.6 min
  Model: llama3.2:3b

⚠️  REGRESSION DETECTED
  Duration: +549% (4.4 min → 28.6 min)
  Severity: CRITICAL (>200% slower)

Root Cause Hints:
  - Model change detected: qwen2.5:7b → llama3.2:3b
  - Model downgrade: 7B → 3B parameters

Recommendations:
  1. Investigate model change reason
  2. Run: ./scripts/manage.sh exec-compare 200 193
  3. Consider: /investigate 200
```

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_regression()`
- Dependencies: `exec-baseline`, `exec-details`, `exec-llm`
- Default threshold: 50% (configurable)

**Workflow-Agnostic**: ✅ Yes

**Estimated Effort**: 2-3 hours

---

### Priority 1: High Value

#### 3. `exec-compare <id1> <id2> [id3] ... [--format table|json]`

**Purpose**: Compare multiple executions side-by-side with performance metrics

**Output**:
```
═══════════════════════════════════════════════════════════════════════
EXECUTION COMPARISON
═══════════════════════════════════════════════════════════════════════
ID    Date        Duration   Status   Model          Notes
───────────────────────────────────────────────────────────────────────
193   2025-10-29  4.4 min    success  qwen2.5:7b     ✓ Baseline (fastest)
194   2025-10-29  46.4 min   success  llama3.1:8b    ⚠ 10.5x slower
200   2025-11-02  28.6 min   success  llama3.2:3b    ⚠ 6.5x slower

Performance Deltas (vs #193 baseline):
  #194: +954% duration
  #200: +549% duration

Model Analysis:
  qwen2.5:7b (7B params)  → 4.4 min/email  ✓ Best performance
  llama3.1:8b (8B params) → 46.4 min       ⚠ Slow (needs preprocessing)
  llama3.2:3b (3B params) → 14.3 min/email ⚠ 3.2x slower than baseline

Recommendation: Revert to qwen2.5:7b for optimal performance
```

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_compare()`
- Accepts: 2-10 execution IDs
- Dependencies: `exec-details`, `exec-llm` (for model extraction)

**Workflow-Agnostic**: ✅ Yes - can compare executions from different workflows

**Estimated Effort**: 2-3 hours

---

#### 4. `exec-validate-schema <id> [--schema file.json] [--auto-detect]`

**Purpose**: Validate LLM responses against expected JSON schema

**Algorithm**:
```python
def validate_schema(execution_id, expected_schema=None, auto_detect=False):
    # Get LLM responses
    llm_data = get_llm_responses(execution_id)

    if auto_detect:
        # Find a successful similar execution and extract schema
        baseline = find_baseline(workflow_name)
        expected_schema = extract_schema_from_execution(baseline.id)

    violations = []
    for response in llm_data:
        parsed = json.loads(response['response'])

        # Check for schema.org contamination
        if '@context' in parsed or '@type' in parsed:
            violations.append({
                'response_id': response['executionIndex'],
                'issue': 'schema.org format detected (wrong schema)',
                'expected': list(expected_schema.keys()),
                'actual': list(parsed.keys())
            })

        # Check for missing required fields
        missing = set(expected_schema.keys()) - set(parsed.keys())
        if missing:
            violations.append({
                'response_id': response['executionIndex'],
                'issue': f'missing fields: {", ".join(missing)}',
                'missing_fields': list(missing)
            })

    return violations
```

**Output**:
```
Schema Validation: Execution #200
═══════════════════════════════════════════════════════════
Expected Schema: gmail-email-summary
  Fields: subject, from, isImportant, summary, category, actions, gmailUrl, receivedDate

Total LLM Responses: 2
Valid Schema: 1 (50%)
Schema Violations: 1 (50%)

❌ Response #2 (exec index 7): SCHEMA VIOLATION
  Issue: schema.org NewsArticle format detected
  Expected: {subject, from, summary, category, actions, gmailUrl, receivedDate, isImportant}
  Got: {@context, @type, mainEntity, datePublished, dateModified, author}
  Empty fields: name, description, image, reviewBody

  Root cause: LLM hallucinated alternative schema
  Recommendation: Upgrade model or add schema validation to prompt

Summary:
  Schema Compliance Rate: 50%
  Quality Status: ⚠️  POOR (below 80% threshold)
  Action: Investigate model performance or prompt clarity
```

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_validate_schema()`
- Schema detection: Auto-detect from successful executions or manual JSON file
- Dependencies: `exec-llm`, `exec-parse`

**Workflow-Agnostic**: ⚠️ Partially
- Auto-detect mode: Yes (learns schema from successful executions)
- Manual mode: Requires schema file per workflow type

**Estimated Effort**: 3-4 hours

---

### Priority 2: Medium Value

#### 5. `workflow-config <workflow_name> [--output json]`

**Purpose**: Extract and display workflow configuration (models, prompts, parameters)

**Output**:
```
Workflow Configuration: gmail-to-telegram
═══════════════════════════════════════════════════════════
File: workflows/gmail-to-telegram.json
Workflow ID: 7bLE5ERoJS3R6hwf
Last Updated: 2025-11-02 19:35:17

LLM Nodes: 1 found

Node #1: "Summarise Email with LLM"
  Type: HTTP Request (Ollama)
  Model: llama3.2:3b
  Endpoint: http://ollama:11434/api/generate

  Parameters:
    - temperature: 0.1 (low, deterministic)
    - top_p: 0.9
    - repeat_penalty: 1.1
    - num_threads: 4
    - format: json (enforced)
    - keep_alive: 5m

  Timeout: 3600000 ms (60 min)

  System Prompt: (1,234 characters)
    "You are an email analysis agent. Your goal is to analyze an email..."
    [Truncated - use --show-prompts to view full]

Other Nodes: 7 (Schedule Trigger, Get Unread Emails, Loop, Format, Send)

Recommendations:
  ⚠️  Model llama3.2:3b is suboptimal for this task
      Consider: qwen2.5:7b (4.4 min/email vs 14.3 min/email)
```

**Implementation**:
- Location: `scripts/lib/workflows.sh`
- Function: `workflow_config()`
- Parses: `workflows/<workflow_name>.json`
- Extracts: LLM nodes, models, parameters, prompts, timeouts

**Workflow-Agnostic**: ✅ Yes - parses any n8n workflow JSON

**Estimated Effort**: 2 hours

---

#### 6. `exec-llm-detail <id> [--show-content]`

**Purpose**: Enhanced LLM response analysis (extends existing `exec-llm`)

**Enhancements over current `exec-llm`**:
- Show parsed response content (subject, summary, category)
- Calculate min/max/avg/variance in processing time
- Show token usage breakdown
- Identify quality issues (schema violations, empty fields)

**Output**:
```
LLM Response Details: Execution #200
═══════════════════════════════════════════════════════════
Model: llama3.2:3b
Total Responses: 2
Processing Time: 28.28 min total, 14.14 min avg (σ=5.41 min)

Response #1 (exec index 5):
  Time: 8.73 min (62% of avg, -38%)
  Tokens: 2,083 prompt, 445 output (1:4.7 ratio)
  Prompt eval: 8.76 sec, Gen: 2.49 min

  Content (parsed):
    Subject: "Executive Briefing: 3 Key Ways AI-Native Companies..."
    Category: education
    Summary: "Nate discusses the importance of institutional AI fluency..."
    Actions: 3 (all with valid URLs)

  Quality: ✅ Valid schema, complete data

Response #2 (exec index 7):
  Time: 19.55 min (138% of avg, +38%)  ⚠️  Outlier
  Tokens: 4,096 prompt, 127 output (1:32 ratio)  ⚠️  High prompt/output ratio
  Prompt eval: 230.85 sec, Gen: 0.69 min

  Content (parsed):
    Subject: N/A  ❌ Missing
    Category: NewsArticle  ⚠️  Wrong schema
    Summary: N/A  ❌ Empty
    @type: NewsArticle  ❌ schema.org format

  Quality: ❌ Schema violation (schema.org format)

Performance Analysis:
  Variance: 2.2x (high - response #2 is 2.2x slower than #1)
  Token efficiency: Response #2 has 2x longer prompt but much shorter output
  Quality issues: 50% schema compliance (1/2 responses valid)

Recommendations:
  ⚠️  High performance variance suggests model struggling with complex input
  ❌ Schema violations indicate model capacity insufficient
  → Consider upgrading to qwen2.5:7b (more reliable)
```

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_llm_detail()` (enhances existing `exec_llm()`)
- Dependencies: `exec-llm`, response parsing logic

**Workflow-Agnostic**: ✅ Yes

**Estimated Effort**: 2 hours

---

### Priority 3: Nice to Have

#### 7. `exec-report <id> [--template full|quick|summary] [--output file.md]`

**Purpose**: Auto-generate investigation report in markdown format

**Templates**:
- `summary`: Executive summary only (2-3 paragraphs + key findings)
- `quick`: Summary + metrics + recommendations (1 page)
- `full`: Complete investigation report (like execution #200 report)

**Output**: Markdown file saved to `docs/investigations/`

**Auto-Generated Sections** (full template):
1. **Executive Summary**
   - Key findings (auto-detected)
   - Performance metrics
   - System health status
   - Impact assessment

2. **Execution Details**
   - Metadata (started, finished, duration, status)
   - Comparison table with recent executions
   - Baseline comparison

3. **System Health & Monitoring**
   - Thermal performance (from `exec-monitoring`)
   - CPU utilization
   - Memory usage
   - Throttling status

4. **Performance Analysis**
   - Processing breakdown by node
   - Performance issues (auto-detected)
   - Comparison with baseline

5. **LLM Response Analysis** (if applicable)
   - Model performance
   - Schema compliance
   - Quality metrics

6. **Root Cause Analysis**
   - Auto-detected issues (template-based)
   - Severity classification
   - User must fill in specific details

7. **Recommendations**
   - Template-based suggestions
   - Priority classification
   - User must customize based on findings

8. **Appendix**
   - Commands used
   - Metrics table
   - Related reports

**Implementation**:
- Location: `scripts/lib/executions.sh`
- Function: `exec_report()`
- Templates: `scripts/templates/investigation-*.md`
- Dependencies: All other exec-* commands

**Workflow-Agnostic**: ✅ Yes - template-based

**Estimated Effort**: 6-8 hours

---

## Implementation Plan

### Phase 1: Quick Wins (Week 1)
**Goal**: Implement P0 scripts for instant regression detection

1. `exec-baseline` (1-2 hours)
   - Implement baseline detection algorithm
   - Test with gmail-to-telegram workflow
   - Validate against manual baseline selection

2. `exec-regression` (2-3 hours)
   - Implement regression detection logic
   - Add severity classification
   - Test with executions 193, 194, 200

**Total**: 3-5 hours
**Deliverable**: Automatic regression detection for all workflows

---

### Phase 2: Performance Analysis (Week 2)
**Goal**: Implement P1 scripts for comprehensive comparison

3. `exec-compare` (2-3 hours)
   - Multi-execution comparison table
   - Performance delta calculations
   - Model analysis

4. `exec-validate-schema` (3-4 hours)
   - Schema extraction from successful executions
   - Violation detection (schema.org, missing fields)
   - Quality scoring

**Total**: 5-7 hours
**Deliverable**: Performance comparison + data quality validation

---

### Phase 3: Enhanced Tooling (Week 3)
**Goal**: Implement P2 scripts for workflow auditing

5. `workflow-config` (2 hours)
   - Workflow JSON parser
   - LLM node extraction
   - Configuration display

6. `exec-llm-detail` (2 hours)
   - Enhance existing `exec-llm`
   - Add content parsing
   - Performance variance analysis

**Total**: 4 hours
**Deliverable**: Workflow configuration audits + enhanced LLM analysis

---

### Phase 4: Report Automation (Week 4)
**Goal**: Implement P3 scripts for automated reporting

7. `exec-report` (6-8 hours)
   - Create report templates
   - Implement section generators
   - Auto-fill metrics and comparisons

**Total**: 6-8 hours
**Deliverable**: Automated investigation report generation

---

## Success Metrics

**Before Automation** (Current State):
- Investigation time: 45-60 minutes
- Manual analysis: ~70% of time
- Inconsistent metrics across investigations
- No automatic regression detection

**After Automation** (Target State):
- Investigation time: 10-15 minutes (73% faster)
- Manual analysis: ~20% of time (auto-detected issues, user validates)
- Consistent metrics (standardized commands)
- Automatic regression alerts

**ROI Calculation**:
- Implementation effort: 18-24 hours
- Time saved per investigation: 30-45 minutes
- Break-even: After 24-36 investigations (~1-2 months at current pace)
- Long-term value: Faster issue detection, better performance trending

---

## Integration with Existing System

### File Structure
```
scripts/
├── lib/
│   ├── executions.sh (enhanced with new functions)
│   ├── workflows.sh (new: workflow config extraction)
│   └── common.sh (shared utilities)
├── templates/
│   ├── investigation-full.md
│   ├── investigation-quick.md
│   └── investigation-summary.md
└── manage.sh (add new command handlers)
```

### Database Schema (No Changes Required)
All new commands use existing `executions` table and n8n execution data format.

### Dependencies
- PostgreSQL (existing)
- Python 3 with json module (existing)
- jq for JSON parsing (existing)
- Existing exec-* commands

---

## Testing Strategy

For each new command:

1. **Unit Testing**
   - Test with gmail-to-telegram workflow (known baseline)
   - Test with successful execution (193)
   - Test with problematic execution (200)
   - Test with failed execution (199)

2. **Workflow Agnostic Testing**
   - Create minimal test workflow with LLM node
   - Verify command works across different workflow types
   - Test with workflows without LLM nodes

3. **Edge Cases**
   - Empty execution history
   - All failed executions (no baseline)
   - Missing monitoring data
   - Corrupted execution data

---

## Documentation Updates

### Update CLAUDE.md
Add new commands to "Execution Logs" section:
```markdown
### Advanced Execution Analysis

```bash
./scripts/manage.sh exec-baseline gmail-to-telegram    # Find optimal baseline
./scripts/manage.sh exec-regression 200                # Detect performance regression
./scripts/manage.sh exec-compare 200 193 194           # Compare multiple executions
./scripts/manage.sh exec-validate-schema 200           # Check LLM schema compliance
./scripts/manage.sh workflow-config gmail-to-telegram  # Show workflow configuration
./scripts/manage.sh exec-report 200 --template full    # Generate investigation report
```

Auto-detect performance issues, compare against baseline, and validate data quality.
```

### Create docs/investigation-commands.md
Comprehensive guide for all investigation commands with examples.

---

## Conclusion

These 7 workflow-agnostic commands will transform the investigation process from manual analysis to automated insights:

| Command | Replaces Manual Action | Time Saved | Value |
|---------|----------------------|------------|-------|
| `exec-baseline` | Manual baseline selection | 5 min | High |
| `exec-regression` | Manual performance comparison | 10 min | Very High |
| `exec-compare` | Manual multi-exec analysis | 15 min | High |
| `exec-validate-schema` | Manual schema validation | 10 min | High |
| `workflow-config` | Manual workflow JSON parsing | 5 min | Medium |
| `exec-llm-detail` | Manual LLM response parsing | 5 min | Medium |
| `exec-report` | Manual report writing | 30 min | Very High |

**Total Time Saved per Investigation**: 80 minutes → **73% faster**

**Recommended Implementation Order**:
1. Week 1: `exec-baseline`, `exec-regression` (instant regression detection)
2. Week 2: `exec-compare`, `exec-validate-schema` (comprehensive analysis)
3. Week 3: `workflow-config`, `exec-llm-detail` (enhanced tooling)
4. Week 4: `exec-report` (full automation)

**Next Steps**:
1. Review and approve this proposal
2. Prioritize which scripts to implement first (recommend P0)
3. Create implementation issues/tasks
4. Begin development in `scripts/lib/executions.sh`
