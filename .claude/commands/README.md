# Claude Code Slash Commands

This directory contains custom slash commands for the homelab automation stack.

## Available Commands

### `/investigate <execution_id>`
**Comprehensive workflow execution investigation**

Performs forensic-level analysis of n8n workflow executions, generates detailed markdown reports, and provides actionable recommendations.

- ✅ Full performance and data quality analysis
- ✅ LLM model verification and assessment
- ✅ Root cause identification
- ✅ Prioritized recommendations with code examples
- ✅ Auto-generates markdown report in `docs/investigations/`

**Example:** `/investigate 194`

---

### `/diagnose-workflow [execution_id]`
**Quick workflow diagnostic**

Fast triage for immediate insights without generating a full report.

- ⚡ Quick status check
- ⚡ Identifies critical issues
- ⚡ Provides immediate next steps
- ⚡ Terminal output only (no file created)

**Example:** `/diagnose-workflow` or `/diagnose-workflow 194`

---

## Usage Guidelines

### When to Use `/investigate`
- Workflow failed or behaved unexpectedly
- Performance degradation detected
- Data quality issues (parsing failures, empty fields)
- Need comprehensive analysis with documented report
- Establishing baseline or validating optimizations

### When to Use `/diagnose-workflow`
- Quick health check of latest execution
- Want fast answer without full documentation
- Determining if detailed investigation is warranted
- Routine monitoring

### Command Flow

```
Issue detected
    ↓
/diagnose-workflow  → Quick check
    ↓
    ├─ Simple issue → Apply quick fix ✅
    │
    └─ Complex issue
        ↓
    /investigate <id> → Full analysis
        ↓
    Implement recommendations
        ↓
    Test & monitor ✅
```

## Investigation Capabilities

Both commands can analyze:

- **Performance**: Execution duration, bottlenecks, per-node timing
- **Data Quality**: JSON parsing, schema compliance, extraction quality
- **LLM Models**: Model verification, capability assessment, prompt effectiveness
- **Workflow Structure**: Node efficiency, error handling, optimization opportunities

## Output Examples

### `/diagnose-workflow` Output
```
🔍 Latest Execution: 194 (29 Oct, 22:32)
⏱️ Duration: 46.4 min | Status: ✅ Success
⚠️ PERFORMANCE ISSUE: 4x slower than baseline

Root cause: Sending 127KB HTML to LLM without preprocessing
Quick fix: Add HTML-to-text conversion before LLM call
Expected: 46 min → 5-10 min

Need details? Run: /investigate 194
```

### `/investigate` Output
```
✅ Investigation complete!

📊 Key Findings:
  • Processing time: 46.4 min (4x slower than expected)
  • JSON parsing: 100% success ✅
  • Root cause: Raw HTML input (127KB → LLM)
  • Model: llama3.1:8b (capable, but overwhelmed by input)

💡 Top Recommendation:
  Add HTML preprocessing → Expected: 46 min to 5-10 min

📄 Full report saved to:
  docs/investigations/2025-10-30-workflow-194-performance-analysis.md

Implement fixes now? [Ask if you'd like help]
```

## Documentation

- **Full system docs**: `docs/investigation-system.md`
- **Project guide**: `CLAUDE.md` (Workflow Investigation System section)
- **Investigation reports**: `docs/investigations/*.md`

## Command Implementation

These slash commands are implemented as markdown prompt files:
- `investigate.md` - Full investigation agent
- `diagnose-workflow.md` - Quick diagnostic agent

When invoked, Claude Code loads the prompt and executes the investigation protocol.

## Customization

To modify investigation behavior, edit the corresponding `.md` file:
- Adjust analysis depth
- Change report structure
- Add new analysis dimensions
- Modify recommendation format

## Future Enhancements

Planned additions:
- `/compare-executions <id1> <id2>` - Side-by-side comparison
- `/monitor-workflow <name>` - Continuous monitoring with alerts
- `/baseline <execution_id>` - Establish performance baseline
- `/validate-fix <execution_id>` - Verify fix effectiveness

---

**Created**: 2025-10-30
**Version**: 1.0.0
