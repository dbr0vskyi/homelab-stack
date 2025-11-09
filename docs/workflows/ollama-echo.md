# Ollama Echo Workflow

Test and benchmark local LLM performance with detailed metrics.

## Overview

**Workflow File**: `workflows/ollama-echo.json`
**Trigger**: Telegram bot messages
**Status**: Active (Testing/Development)

## Purpose

A diagnostic and testing workflow that processes messages through Ollama LLM and returns detailed performance metrics. Useful for:

- Testing Ollama setup and model availability
- Benchmarking model performance
- Debugging LLM issues
- Comparing different models
- Monitoring inference speed and token processing

## Flow Diagram

```
Telegram Trigger
  → Filter (Check user & message)
  → Send Processing Notification
  → Call Ollama API
  → Format Metrics & Response
  → Send Results to Telegram
```

## Key Features

### Model Selection

The workflow supports dynamic model selection via message prefix:

**Default**:
```
Hello, how are you?
```
Uses: `llama3.2:3b` (default)

**Specify Model**:
```
model:qwen2.5:7b What is the capital of France?
```
Uses: `qwen2.5:7b`

**Available Models** (check with `./scripts/manage.sh models`):
- `llama3.2:1b` - Fastest, smallest
- `llama3.2:3b` - Good balance
- `llama3.1:8b` - High quality
- `qwen2.5:7b` - Recommended for production
- `qwen2.5:14b` - Best quality (requires 16GB+ RAM)

### Metrics Reported

The workflow returns comprehensive performance data:

**Timing Metrics**:
- Total duration (end-to-end)
- Model load time
- Load time percentage
- Prompt processing time
- Response generation time

**Token Metrics**:
- Prompt tokens count
- Output tokens count
- Prompt tokens/second (TPS)
- Output tokens/second
- End-to-end TPS
- IO token ratio (output/input)

**Per-Token Metrics**:
- Milliseconds per prompt token
- Milliseconds per output token

### User Filtering

The workflow includes a filter to only respond to authorized users:

- Username: `dbr0vskyi` (configurable)
- Prevents accidental execution by unauthorized users
- Ignores bot's own "Starting processing message" notifications

## Configuration

### Required Credentials

Configure these in the n8n UI after importing:

1. **Telegram Bot**
   - Bot Token (from @BotFather)
   - Bot Name: "Ollama Echo Bot" (or customize)

### Customize Authorized User

Edit the "Filter" node:

```javascript
{
  "conditions": [
    {
      "leftValue": "={{ $json.message.from.username }}",
      "rightValue": "YOUR_USERNAME",  // Change this
      "operator": "equals"
    }
  ]
}
```

### Change Default Model

Edit the "Summarise Email with LLM" node (parameter extraction):

```javascript
// Find this line:
$('Filter').item.json.message.text.match(/\bmodel:\s*([a-z0-9_.:-]+)/i)[1] : 'llama3.2:3b'

// Change 'llama3.2:3b' to your preferred default
```

## Usage Examples

### Basic Test

**Input**:
```
Hello!
```

**Output**:
```
📊 LLM Run Metrics

• Model: llama3.2:3b

• Total time: 2.45 s
• Load time: 0.12 s
• Load share: 4.9%

• Prompt tokens: 8
• Prompt time: 0.15 s
• Prompt TPS: 53.33 tok/s
• Prompt ms/token: 18.8 ms

• Output tokens: 15
• Output time: 2.18 s
• Output TPS: 6.88 tok/s
• Output ms/token: 145.3 ms

• End-to-end TPS: 9.39 tok/s
• IO token ratio (out/in): 1.88

— — —
Response:
Hello! How can I assist you today?
```

### Model Comparison

**Test 1**:
```
model:llama3.2:1b Write a haiku about coding
```

**Test 2**:
```
model:qwen2.5:7b Write a haiku about coding
```

Compare the metrics to see performance differences.

### Stress Test

**Input**:
```
model:qwen2.5:14b Explain quantum computing in detail
```

Monitor memory usage and processing time for large models.

## Troubleshooting

### Issue: No response from bot

**Check**:
1. Telegram credentials are valid
2. Workflow is active
3. Your username matches the filter
4. Check logs: `docker compose logs n8n | grep telegram`

### Issue: "Model not found" error

**Solution**:
```bash
# List available models
./scripts/manage.sh models

# Download missing model
./scripts/manage.sh pull llama3.2:3b
```

### Issue: Timeout errors

**Causes**:
- Model too large for available RAM
- First inference (model loading)
- Complex prompt requiring long processing

**Solutions**:
1. Use smaller model: `llama3.2:1b`
2. Wait for model to load (first message after restart is slower)
3. Increase timeout in HTTP Request node (default: 3600s/1hr)

### Issue: Out of memory

**Solution**:
```bash
# Check memory usage
docker stats ollama

# Use smaller model or increase Docker memory limit
# Edit docker-compose.yml:
#   ollama:
#     deploy:
#       resources:
#         limits:
#           memory: 16G  # Increase this
```

## Monitoring

### Check Execution History

```bash
# Latest execution
./scripts/manage.sh exec-latest

# Workflow-specific
./scripts/manage.sh exec-workflow ollama-echo
```

### Performance Tracking

Create a spreadsheet to track metrics over time:

| Date | Model | Prompt Tokens | Output Tokens | Total Time | TPS |
|------|-------|---------------|---------------|------------|-----|
| 2025-11-09 | llama3.2:3b | 25 | 150 | 12.5s | 14.0 |
| 2025-11-09 | qwen2.5:7b | 25 | 150 | 18.2s | 9.6 |

### Benchmark Script

```bash
#!/bin/bash
# Send test messages and collect metrics

echo "Testing llama3.2:3b..."
# Send: model:llama3.2:3b Write a 100-word essay about AI

echo "Testing qwen2.5:7b..."
# Send: model:qwen2.5:7b Write a 100-word essay about AI

# Compare execution times in n8n
./scripts/manage.sh exec-history 5
```

## Use Cases

### 1. Model Selection

Test different models with the same prompt to find the best balance of speed and quality for your use case.

### 2. Performance Regression Testing

After Ollama updates or system changes, verify performance hasn't degraded.

### 3. Memory Profiling

Monitor `docker stats ollama` while testing different models to understand memory requirements.

### 4. Prompt Engineering

Test how different prompt styles affect token usage and processing time.

### 5. Capacity Planning

Determine how many concurrent LLM requests your system can handle.

## Performance Metrics

**Expected Performance** (Raspberry Pi 5 16GB):

| Model | Load Time | Prompt TPS | Output TPS | Memory |
|-------|-----------|------------|------------|--------|
| llama3.2:1b | 0.05s | 100+ | 20-30 | ~2GB |
| llama3.2:3b | 0.10s | 60-80 | 12-18 | ~4GB |
| llama3.1:8b | 0.20s | 30-50 | 6-10 | ~8GB |
| qwen2.5:7b | 0.18s | 35-55 | 8-12 | ~8GB |
| qwen2.5:14b | 0.30s | 20-35 | 4-8 | ~14GB |

## Related Documentation

- **Workflow Management**: `docs/workflows/README.md`
- **Ollama Setup**: `docs/api-setup.md`
- **Model Analysis**: `docs/model-context-window-analysis.md`
- **Hardware Setup**: `docs/hardware-setup.md`

## Maintenance

### Update Metrics Format

Edit the "Send a text message" node to customize the metrics display:

```javascript
// Current format uses Telegram markdown
// Customize the template string to add/remove metrics
```

### Add More Models

Download additional models:

```bash
./scripts/manage.sh pull llama3.2:1b
./scripts/manage.sh pull mistral:7b
./scripts/manage.sh pull codellama:7b
```

Then test with:
```
model:mistral:7b Your prompt here
```

---

**Last Updated**: 2025-11-09
**Version**: 1.0
**Status**: Testing/Development
**Purpose**: Diagnostic and benchmarking tool
