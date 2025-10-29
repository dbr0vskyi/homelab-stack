# Workflow Investigation System

## Overview

This homelab stack includes a comprehensive investigation system for analyzing n8n workflow executions, identifying issues, and providing actionable recommendations.

## Available Commands

### `/investigate <execution_id>`

**Purpose**: Comprehensive forensic analysis of a workflow execution

**What it does:**
- Gathers complete execution data and metrics
- Analyzes LLM performance and data quality
- Identifies root causes of issues
- Provides prioritized, actionable recommendations
- Generates detailed markdown investigation report
- Saves report to `docs/investigations/`

**When to use:**
- Workflow failed or behaved unexpectedly
- Performance degradation detected
- Data quality issues observed
- Need detailed analysis for optimization
- Want documented investigation for future reference

**Example:**
```bash
/investigate 194
```

**Output:**
- Terminal summary of findings
- Full markdown report in `docs/investigations/`
- Specific code examples and fixes
- Quantified impact estimates

---

### `/diagnose-workflow [execution_id]`

**Purpose**: Quick triage and immediate guidance

**What it does:**
- Fast analysis of latest or specified execution
- Identifies critical issues immediately
- Provides one-line status and quick fix
- Recommends escalation to full investigation if needed

**When to use:**
- Quick health check needed
- Want fast answer without full report
- Checking if investigation is warranted
- Rapid troubleshooting

**Example:**
```bash
/diagnose-workflow          # Analyze latest execution
/diagnose-workflow 194      # Quick check specific execution
```

**Output:**
- Concise terminal summary only
- Key metrics and immediate fix
- Link to run full investigation

---

## Investigation Workflow

```
┌─────────────────────────────────────────┐
│  Workflow Execution Completes           │
└────────────────┬────────────────────────┘
                 │
                 ├─ Seems fine → Done ✅
                 │
                 ├─ Quick question?
                 │  └─→ /diagnose-workflow
                 │       ├─ Simple issue → Apply quick fix ✅
                 │       └─ Complex → Escalate ↓
                 │
                 └─ Need detailed analysis?
                    └─→ /investigate <id>
                         ├─ Generate report
                         ├─ Implement recommendations
                         └─ Monitor next execution ✅
```

## Investigation Reports

### Structure

All investigation reports follow this standard structure:

1. **Executive Summary**: Key findings and impact
2. **Execution Details**: Metrics, timing, status
3. **Analysis Sections**: Performance, data quality, model performance
4. **Root Cause Analysis**: Primary issues and contributing factors
5. **Recommendations**: Prioritized actions (immediate/short-term/long-term)
6. **Testing Recommendations**: Validation approach
7. **Conclusion**: Summary and action plan
8. **Appendix**: Technical details, commands used, metrics table

### Report Location

`docs/investigations/YYYY-MM-DD-workflow-[execution-id]-[brief-description].md`

### Existing Reports

- **2025-10-29-workflow-191-llm-parsing-failures.md**
  - Issue: 25% LLM JSON parsing failures
  - Root cause: Missing `format: json` parameter
  - Fix: Add format parameter to Ollama API call
  - Impact: 75% → 100% success rate

- **2025-10-30-workflow-194-performance-analysis.md** (if created)
  - Issue: 46-minute processing time for 1 email
  - Root cause: Raw HTML input without preprocessing
  - Fix: Add HTML-to-text conversion
  - Impact: 46 min → 5-10 min (estimated)

## Analysis Capabilities

The investigation system can analyze:

### Performance Metrics
- ⏱️ Execution duration (total and per-node)
- 📊 Throughput (emails/minute, items processed)
- 🔄 Comparison with historical executions
- 🎯 Bottleneck identification
- 💾 Resource utilization patterns

### Data Quality
- ✅ JSON parsing success rates
- 📝 Schema compliance
- 🔍 Content extraction quality
- 🌐 Multilingual handling
- ⚠️ Error patterns and edge cases

### Model Performance
- 🤖 Model identification and verification
- 💪 Capability assessment
- 📏 Token usage and context limits
- 🎨 Prompt effectiveness
- ⚙️ Configuration validation (format parameters, etc.)

### Workflow Structure
- 🏗️ Node efficiency
- 🔁 Loop optimization
- 🛡️ Error handling quality
- 📥 Input preprocessing
- 📤 Output formatting

## Best Practices

### When to Investigate

**Always investigate:**
- ❌ Execution failures or errors
- 🐌 Significant performance degradation (>2x slower)
- 📉 Data quality issues (>10% parsing failures)
- 🔄 Repeating problems (same issue 2+ times)

**Consider investigating:**
- 🤔 Unexpected behavior (works but output is weird)
- 🎲 Inconsistent results (sometimes works, sometimes doesn't)
- 🔍 Before optimization (establish baseline)

**Quick diagnose sufficient:**
- ✅ Success but want to verify
- ⚡ Quick performance check
- 📊 Routine health check

### Investigation Tips

1. **Verify the model**: Always ask user if model was changed via UI
2. **Check recent history**: Context from `exec-history 10` is valuable
3. **Compare wisely**: Don't auto-compare unless meaningful baseline exists
4. **Quantify impact**: Use numbers (46 min → 5 min, 75% → 100%)
5. **Provide examples**: Show actual code, not just descriptions
6. **Prioritize clearly**: Immediate vs. short-term vs. long-term

### After Investigation

1. **Review the report** - Check findings make sense
2. **Implement high-priority fixes** - Start with immediate actions
3. **Test changes** - Run new execution to validate
4. **Monitor next executions** - Verify improvement
5. **Update documentation** - Capture lessons learned

## Manual Investigation Commands

If you prefer manual investigation without the slash commands:

```bash
# Get execution details
./scripts/manage.sh exec-details <execution_id>

# Analyze LLM responses
./scripts/manage.sh exec-llm <execution_id>

# Parse all node outputs
./scripts/manage.sh exec-parse <execution_id>

# Extract raw data
./scripts/manage.sh exec-data <execution_id> output.json

# Check recent history
./scripts/manage.sh exec-history 10

# View failed executions
./scripts/manage.sh exec-failed 10

# Get statistics
./scripts/manage.sh exec-stats
```

See `CLAUDE.md` for complete command reference.

## Integration with Workflow Development

### Development Cycle

```
1. Develop workflow in n8n UI
   ↓
2. Test with sample data
   ↓
3. Run /diagnose-workflow → Quick check
   ↓
4. If issues: /investigate <id> → Get report
   ↓
5. Implement recommendations
   ↓
6. Test again
   ↓
7. Export workflow: ./scripts/manage.sh export-workflows
   ↓
8. Commit changes with investigation report
```

### Before Production

Run comprehensive investigation on:
- ✅ Successful test execution (establish baseline)
- ❌ Edge case/failure execution (verify error handling)
- 🔄 Batch execution (verify scalability)

Document baseline metrics for future comparison.

## Troubleshooting the Investigation System

### Investigation command not found

```bash
# Verify command exists
ls -la .claude/commands/investigate.md

# If missing, it should be created automatically
# Check Claude Code settings
```

### Can't access execution data

```bash
# Verify PostgreSQL is running
./scripts/manage.sh status

# Check if execution ID exists
./scripts/manage.sh exec-history 20
```

### Report not generated

Check:
1. Do you have write permissions to `docs/investigations/`?
2. Is there disk space available?
3. Did the investigation complete without errors?

## Future Enhancements

Potential additions to the investigation system:

- 🔔 **Automatic alerting**: Monitor executions and auto-investigate failures
- 📈 **Trend analysis**: Track metrics over time, identify degradation patterns
- 🔬 **A/B comparison**: Compare two executions side-by-side
- 🎯 **Recommendation tracking**: Mark which fixes were implemented
- 📊 **Dashboard**: Visual overview of workflow health
- 🤖 **Auto-fix**: Implement simple fixes automatically (with approval)

---

## Examples

### Example 1: LLM Parsing Failure Investigation

```
/investigate 191

→ Identified: 25% JSON parsing failures (5/20 emails)
→ Root cause: Missing `format: json` parameter
→ Fix: Add parameter to Ollama API call
→ Report: docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md
→ Result: Next execution 100% success rate ✅
```

### Example 2: Performance Issue Diagnostic

```
/diagnose-workflow 194

→ Quick finding: 46 min for 1 email (4x slower than expected)
→ Immediate cause: Sending 127KB raw HTML to LLM
→ Quick fix: Add HTML preprocessing
→ Escalated: /investigate 194 for detailed analysis
```

### Example 3: Routine Health Check

```
/diagnose-workflow

→ Latest execution: 195 | 5.2 min | Success ✅
→ LLM: 100% JSON parsing | Model: llama3.1:8b
→ Performance: Within expected range
→ Status: All systems operational
```

---

**Last Updated**: 2025-10-30
**Maintained By**: Workflow Investigation Agent
