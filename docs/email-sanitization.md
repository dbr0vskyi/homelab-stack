# Email Input Sanitization Strategy for Gmail to Telegram Workflow

**Based on Investigation**: Execution 191 Analysis (2025-10-29)
**Failure Rate**: 25% (5/20 emails with LLM parsing failures)
**Primary Issues**: Raw HTML/text causing token overflow, promotional content confusion, language switching

---

## Problem Analysis from Execution 191

### Failed Email Categories

| Exec Index | Email Type | Issue | Tokens | Duration | Root Cause |
|------------|-----------|-------|--------|----------|------------|
| 5 | Udemy Promo | Meta-analysis instead of data extraction | 2,696 prompt | 9.2 min | Complex promotional HTML |
| 7 | Zalando (Polish) | Responded in Polish, no JSON | 4,096 prompt (MAX) | 19 min | Context overflow + language |
| 15 | Udemy Spam | Security advice instead of extraction | 4,096 prompt (MAX) | 18 min | Spam detection override |
| 21 | Zalando (Polish) | Polish text response, no JSON | 1,902 prompt | 5.3 min | Language switching |
| 41 | Udemy Course | Marketing analysis, no JSON | 600 prompt | 1.6 min | Interpretive stance |

### Pattern Recognition

**Common Failure Triggers:**
1. **Promotional emails** (Udemy, Zalando) - 100% of failures
2. **Non-English content** (Polish) - 40% of failures
3. **Context limit hits** (4,096 tokens) - 40% of failures
4. **Marketing-heavy content** - triggers "helpful explanation" mode

---

## Sanitization Strategy by Email Type

### 1. Promotional/Newsletter Emails (Udemy, Zalando Pattern)

**Detection Signals:**
```javascript
function isPromotional(email) {
  const sender = email.fromAddress.toLowerCase();
  const subject = email.subject.toLowerCase();
  const text = email.text.toLowerCase();

  // Sender domain patterns
  const promoSenders = ['udemy.com', 'zalando', 'newsletter', 'marketing', 'promo', 'noreply'];
  const hasPromoSender = promoSenders.some(pattern => sender.includes(pattern));

  // Subject patterns
  const promoKeywords = ['sale', 'discount', '% off', 'new arrivals', 'special offer', 'limited time'];
  const hasPromoSubject = promoKeywords.some(kw => subject.includes(kw));

  // Content patterns (product listing indicators)
  const productPatterns = [
    /\$\d+\.\d{2}/g,        // Prices: $19.99
    /€\d+[,\.]\d{2}/g,      // Euro prices: €19,99
    /zł\s*\d+/g,            // Polish złoty: zł 99
    /buy now/gi,            // CTA
    /shop now/gi,           // CTA
    /\d+%\s*off/gi,         // Discount mentions
  ];

  let productMentions = 0;
  productPatterns.forEach(pattern => {
    const matches = text.match(pattern) || [];
    productMentions += matches.length;
  });

  // If 5+ product mentions, likely promotional
  const hasHighProductDensity = productMentions >= 5;

  return hasPromoSender || hasPromoSubject || hasHighProductDensity;
}
```

**Sanitization for Promotional Emails:**

```javascript
function sanitizePromotionalEmail(text, subject, sender) {
  let cleaned = text;

  // 1. Extract only first 3 product mentions (discard rest)
  const productBlocks = extractProductBlocks(cleaned);
  if (productBlocks.length > 3) {
    cleaned = productBlocks.slice(0, 3).join('\n') + '\n[Additional products truncated]';
  }

  // 2. Remove promotional boilerplate
  cleaned = removeBoilerplate(cleaned, [
    /unsubscribe/gi,
    /click here if you can't view/gi,
    /add.*to.*safe senders/gi,
    /view in browser/gi,
    /terms and conditions/gi,
    /privacy policy/gi,
  ]);

  // 3. Simplify to essential info
  const simplified = {
    sender: sender,
    topic: subject,
    contentType: 'promotional newsletter',
    keyItems: productBlocks.slice(0, 3),
    context: 'This is a marketing email'
  };

  return `Newsletter from ${simplified.sender}
Subject: ${simplified.topic}

Type: Promotional content

Key items mentioned:
${simplified.keyItems.join('\n')}

${simplified.context}`;
}

function extractProductBlocks(text) {
  // Split by common product separators
  const lines = text.split('\n');
  const products = [];

  let currentBlock = '';
  for (const line of lines) {
    // Detect product line (has price or CTA)
    if (/\$\d+|\€\d+|buy|shop|view/gi.test(line)) {
      if (currentBlock.length > 10) {
        products.push(currentBlock.trim());
      }
      currentBlock = line;
    } else {
      currentBlock += ' ' + line;
    }
  }

  if (currentBlock.length > 10) {
    products.push(currentBlock.trim());
  }

  return products.slice(0, 3); // Max 3 products
}
```

**Expected Reduction:**
- **Udemy emails**: 2,696 tokens → ~800 tokens (-70%)
- **Zalando emails**: 4,096 tokens → ~1,200 tokens (-71%)

---

### 2. Non-English Content (Polish, German, etc.)

**Language Detection:**

```javascript
function detectLanguage(text, sender, subject) {
  // Simple heuristic-based detection
  const combined = (text + ' ' + subject + ' ' + sender).toLowerCase();

  const languagePatterns = {
    polish: {
      chars: /[ąćęłńóśźż]/g,
      words: ['jest', 'wiadomość', 'promocja', 'rabatu', 'sklep', 'dostaw'],
      weight: 0
    },
    german: {
      chars: /[äöüß]/g,
      words: ['das', 'ist', 'und', 'der', 'die', 'mit', 'für'],
      weight: 0
    },
    french: {
      chars: /[àâæçéèêëïîôùûü]/g,
      words: ['est', 'pour', 'avec', 'dans', 'votre', 'merci'],
      weight: 0
    }
  };

  // Count special characters
  Object.keys(languagePatterns).forEach(lang => {
    const charMatches = combined.match(languagePatterns[lang].chars) || [];
    languagePatterns[lang].weight += charMatches.length * 2;

    // Count word matches
    languagePatterns[lang].words.forEach(word => {
      if (combined.includes(word)) {
        languagePatterns[lang].weight += 5;
      }
    });
  });

  // Find highest weight
  let detectedLang = 'english';
  let maxWeight = 20; // Threshold for non-English

  Object.keys(languagePatterns).forEach(lang => {
    if (languagePatterns[lang].weight > maxWeight) {
      detectedLang = lang;
      maxWeight = languagePatterns[lang].weight;
    }
  });

  return detectedLang;
}
```

**Handling Non-English Emails:**

```javascript
function addLanguageContext(text, detectedLanguage) {
  if (detectedLanguage === 'english') {
    return text;
  }

  const languageHints = {
    polish: 'Polish',
    german: 'German',
    french: 'French'
  };

  const langName = languageHints[detectedLanguage] || detectedLanguage;

  // Prepend clear instruction to LLM
  return `[LANGUAGE: This email is written in ${langName}. Extract the information and provide ALL output fields in English, regardless of the email's language.]

${text}`;
}
```

**Enhanced System Prompt Addition:**

```
CRITICAL LANGUAGE RULE:
- If the email is in a non-English language (Polish, German, French, etc.):
  1. Read and understand the content in that language
  2. Extract all information accurately
  3. Output EVERY field in English (subject, from, summary, category, actions)
  4. Do NOT respond in the email's original language
  5. Translate summary and action labels to English

Example: If email is in Polish about "Promocja 10% rabatu":
CORRECT: {"summary": "10% discount promotion", "category": "promotion"}
INCORRECT: {"summary": "Promocja 10% rabatu", ...}
```

**Expected Improvement:**
- **Execution 7 & 21 (Polish emails)**: Should now return English JSON instead of Polish text responses

---

### 3. HTML & Formatting Cleanup

**HTML Removal Strategy:**

```javascript
function cleanHTML(rawHtml) {
  let text = rawHtml;

  // 1. Remove script and style tags entirely
  text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

  // 2. Remove tracking pixels and analytics
  text = text.replace(/<img[^>]*tracking[^>]*>/gi, '');
  text = text.replace(/<img[^>]*analytics[^>]*>/gi, '');
  text = text.replace(/<img[^>]*width=["']?1["']?[^>]*height=["']?1["']?[^>]*>/gi, '');

  // 3. Convert common HTML entities
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '...'
  };

  Object.keys(entities).forEach(entity => {
    text = text.replace(new RegExp(entity, 'g'), entities[entity]);
  });

  // 4. Remove all HTML tags (preserve content)
  text = text.replace(/<[^>]*>/g, ' ');

  // 5. Decode remaining numeric entities
  text = text.replace(/&#(\d+);/g, (match, dec) => String.fromCharCode(dec));
  text = text.replace(/&#x([0-9a-f]+);/gi, (match, hex) => String.fromCharCode(parseInt(hex, 16)));

  // 6. Normalize whitespace
  text = text.replace(/[ \t]+/g, ' ');           // Multiple spaces to single
  text = text.replace(/\n\s*\n\s*\n/g, '\n\n');  // Multiple newlines to max 2
  text = text.trim();

  return text;
}
```

**Expected Token Reduction:**
- **Average**: 40-60% reduction in token count
- **HTML-heavy emails**: Up to 75% reduction

---

### 4. URL Extraction & Replacement

**Why This Matters:**
- Long tracking URLs can be 100-200 characters each
- Example: `https://click.udemy.com/track?id=12345&uid=abcdef&campaign=xyz&utm_source=newsletter&utm_medium=email&utm_campaign=spring_sale_2025`
- LLM doesn't need full URL to understand email purpose

**Implementation:**

```javascript
function extractAndReplaceURLs(text) {
  const urls = [];
  const urlPattern = /https?:\/\/[^\s<>"]+/g;

  // Extract all URLs
  let match;
  while ((match = urlPattern.exec(text)) !== null) {
    urls.push(match[0]);
  }

  // Remove duplicates
  const uniqueUrls = [...new Set(urls)];

  // Replace URLs with short placeholders
  let cleanedText = text;
  uniqueUrls.forEach((url, index) => {
    const placeholder = `[LINK_${index + 1}]`;
    cleanedText = cleanedText.replace(new RegExp(url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), placeholder);
  });

  return {
    cleanedText,
    urls: uniqueUrls
  };
}

function restoreURLs(llmResponse, urlMap) {
  // After LLM processing, restore full URLs
  let response = llmResponse;

  urlMap.forEach((url, index) => {
    const placeholder = `[LINK_${index + 1}]`;
    response = response.replace(new RegExp(placeholder, 'g'), url);
  });

  return response;
}
```

**Add to LLM System Prompt:**

```
URL HANDLING:
- URLs in the email are represented as [LINK_1], [LINK_2], etc.
- When extracting actions, use these placeholders: {"label": "View Course", "url": "[LINK_1]"}
- Do NOT invent or modify URL placeholders
- If no relevant link for an action, omit the url field
```

**Expected Improvement:**
- **Token savings**: 30-50 tokens per URL (typically 5-10 URLs per promotional email)
- **Total savings**: ~200-400 tokens per promotional email

---

### 5. Boilerplate & Footer Removal

**Common Patterns to Remove:**

```javascript
function removeBoilerplate(text) {
  const boilerplatePatterns = [
    // Unsubscribe sections
    /unsubscribe.*?(\n\n|\n|$)/gi,
    /click here to (stop receiving|opt out|manage).*?(\n\n|\n|$)/gi,
    /you (are receiving|received) this.*?(\n\n|\n|$)/gi,

    // Privacy/legal
    /privacy policy.*?(\n\n|\n|$)/gi,
    /terms (and|&) conditions.*?(\n\n|\n|$)/gi,
    /this email (is|was) sent.*?(\n\n|\n|$)/gi,
    /confidential.*?not.*?intended recipient.*?(\n\n|\n|$)/gi,

    // View in browser
    /(view|open) (this|email) in.*?browser.*?(\n\n|\n|$)/gi,
    /can't see.*?images.*?(\n\n|\n|$)/gi,
    /trouble viewing.*?(\n\n|\n|$)/gi,

    // Footer contact info (aggressive)
    /our (mailing )?address (is)?:.*?(\n\n|\n|$)/gi,
    /\d{1,5}\s+\w+\s+(street|avenue|road|blvd).*?(\n\n|\n|$)/gi,

    // Social media footer
    /follow us on.*?(\n\n|\n|$)/gi,
    /(facebook|twitter|instagram|linkedin)\s*[:|].*?(\n\n|\n|$)/gi,

    // Copyright
    /©.*?\d{4}.*?(\n\n|\n|$)/gi,
    /copyright.*?\d{4}.*?(\n\n|\n|$)/gi,

    // Safe sender requests
    /add.*?(to|as).*?safe.*?sender.*?(\n\n|\n|$)/gi,
    /whitelist.*?email.*?(\n\n|\n|$)/gi,
  ];

  let cleaned = text;
  boilerplatePatterns.forEach(pattern => {
    cleaned = cleaned.replace(pattern, '\n');
  });

  // Remove trailing repetitive content (last 15% if similar to footer patterns)
  const lines = cleaned.split('\n');
  const threshold = Math.floor(lines.length * 0.85);
  const lastSection = lines.slice(threshold).join('\n').toLowerCase();

  if (/unsubscribe|privacy|copyright|address|follow us/.test(lastSection)) {
    cleaned = lines.slice(0, threshold).join('\n');
  }

  return cleaned.trim();
}
```

**Expected Savings:**
- **10-30%** additional token reduction on promotional emails
- Removes noise that confuses LLM categorization

---

### 6. Length Truncation (Final Step)

**Smart Truncation Strategy:**

```javascript
function truncateEmail(text, maxChars = 10000) {
  if (text.length <= maxChars) {
    return text;
  }

  // Try to truncate at sentence boundary
  const truncated = text.substring(0, maxChars);

  // Find last sentence ending
  const lastPeriod = truncated.lastIndexOf('.');
  const lastQuestion = truncated.lastIndexOf('?');
  const lastExclaim = truncated.lastIndexOf('!');

  const lastSentenceEnd = Math.max(lastPeriod, lastQuestion, lastExclaim);

  if (lastSentenceEnd > maxChars * 0.8) {
    // Good sentence boundary found (within last 20%)
    return truncated.substring(0, lastSentenceEnd + 1) + '\n\n[Email content truncated due to length]';
  } else {
    // No good boundary, hard truncate
    return truncated + '...\n\n[Email content truncated due to length]';
  }
}
```

**Why 10,000 Characters:**
- ~2,500 tokens after encoding
- Leaves room for system prompt (~500 tokens) and output (~500 tokens)
- Prevents hitting 4,096 token context limit (as seen in exec 7 & 15)
- Based on investigation 200 recommendation

---

## Complete Sanitization Pipeline

**Workflow Node: "Clean Email Input" (Place after "Map Email Fields")**

```javascript
// Complete sanitization implementation
const items = $input.all();

function sanitizeEmail(email) {
  // Extract metadata (already clean from Gmail API)
  const metadata = {
    id: email.id,
    to: email.to,
    fromAddress: email.fromAddress,
    fromName: email.fromName,
    subject: email.subject,
    gmailUrl: email.gmailUrl,
    internalDate: email.internalDate
  };

  // Get raw text
  let text = email.text || '';

  // Step 1: Clean HTML
  text = cleanHTML(text);

  // Step 2: Detect language
  const language = detectLanguage(text, email.fromAddress, email.subject);

  // Step 3: Detect if promotional
  const isPromo = isPromotional(email);

  // Step 4: Apply promotional simplification if needed
  if (isPromo) {
    text = sanitizePromotionalEmail(text, email.subject, email.fromName);
  }

  // Step 5: Extract and replace URLs
  const { cleanedText, urls } = extractAndReplaceURLs(text);
  text = cleanedText;

  // Step 6: Remove boilerplate
  text = removeBoilerplate(text);

  // Step 7: Normalize whitespace (final cleanup)
  text = text.replace(/\s+/g, ' ').trim();
  text = text.replace(/\n\s*\n\s*\n+/g, '\n\n'); // Max 2 consecutive newlines

  // Step 8: Add language context if non-English
  if (language !== 'english') {
    text = addLanguageContext(text, language);
  }

  // Step 9: Truncate if too long
  text = truncateEmail(text, 10000);

  // Calculate statistics
  const originalLength = email.text?.length || 0;
  const cleanedLength = text.length;
  const reductionPercent = Math.round((1 - cleanedLength / originalLength) * 100);

  return {
    json: {
      ...metadata,
      text: text,
      urlMap: urls,
      language: language,
      isPromotional: isPromo,
      sanitizationStats: {
        originalLength,
        cleanedLength,
        reductionPercent,
        urlsExtracted: urls.length
      }
    }
  };
}

// Process all emails
return items.map(item => sanitizeEmail(item.json));
```

---

## Expected Results for Execution 191 Failed Emails

**If sanitization was applied:**

| Exec Index | Original Tokens | After Sanitization | Time Saved | Schema Compliance |
|------------|----------------|-------------------|------------|-------------------|
| 5 (Udemy) | 2,696 | ~900 (-67%) | ~6 min | ✅ Expected success |
| 7 (Zalando PL) | 4,096 (MAX) | ~1,200 (-71%) | ~12 min | ✅ English output expected |
| 15 (Udemy) | 4,096 (MAX) | ~800 (-80%) | ~12 min | ✅ Expected success |
| 21 (Zalando PL) | 1,902 | ~700 (-63%) | ~2 min | ✅ English output expected |
| 41 (Udemy) | 600 | ~300 (-50%) | ~1 min | ✅ Expected success |
| **Total** | **13,390 tokens** | **~3,900 tokens (-71%)** | **~33 min saved** | **5/5 expected success (100%)** |

---

## Testing Plan

### Test Case 1: Udemy Promotional Email (Exec 5 Pattern)

**Before Sanitization:**
- Long HTML promotional content with course listings
- Multiple tracking URLs
- Result: LLM provides meta-analysis instead of extraction

**After Sanitization:**
- HTML stripped → plain text
- Truncated to first 3 courses
- URLs replaced with [LINK_1], [LINK_2], etc.
- Boilerplate removed

**Expected Outcome:**
```json
{
  "subject": "New AI courses available",
  "from": "Udemy",
  "isImportant": false,
  "summary": "Udemy newsletter featuring new AI and machine learning courses with limited-time discounts.",
  "category": "education",
  "actions": [
    {"label": "View AI Course", "url": "[LINK_1]"},
    {"label": "Browse Discounts", "url": "[LINK_2]"}
  ]
}
```

### Test Case 2: Polish Zalando Email (Exec 7 Pattern)

**Before Sanitization:**
- 4,096 tokens (context overflow)
- Polish language content
- Result: Polish text response, no JSON structure

**After Sanitization:**
- Language detected as Polish
- Context prepended: `[LANGUAGE: This email is written in Polish...]`
- Promotional simplification applied
- Truncated from 4,096 → ~1,200 tokens
- System prompt enforces English output

**Expected Outcome:**
```json
{
  "subject": "New Vinyl & PreOrders",
  "from": "Zalando Lounge",
  "isImportant": false,
  "summary": "Weekly promotional email from Zalando Lounge featuring 10% discount on all products.",
  "category": "promotion",
  "actions": [
    {"label": "View Offers", "url": "[LINK_1]"},
    {"label": "Shop Now", "url": "[LINK_2]"}
  ]
}
```
*Note: All fields in English despite Polish email*

---

## Implementation Priority

### Phase 1: Critical (Implement First) - **Effort: 2-3 hours**
1. ✅ HTML tag stripping (`cleanHTML`)
2. ✅ Length truncation (`truncateEmail`)
3. ✅ Whitespace normalization
4. ✅ Language detection and context addition

**Expected Impact:** 60-70% failure rate reduction

### Phase 2: High Priority (Week 1) - **Effort: 3-4 hours**
5. ✅ URL extraction and replacement
6. ✅ Boilerplate removal
7. ✅ Promotional email detection

**Expected Impact:** Additional 20-25% failure rate reduction

### Phase 3: Polish (Week 2) - **Effort: 2 hours**
8. ✅ Promotional simplification
9. ✅ Smart truncation (sentence boundaries)
10. ✅ Statistics tracking

**Expected Impact:** Quality and monitoring improvements

---

## Monitoring & Validation

**Add to Daily Summary:**

```javascript
// In "Format for Telegram" daily summary
if (stats.sanitization) {
  summaryMessage += `\n\n📊 Sanitization Stats:`;
  summaryMessage += `\n• Avg token reduction: ${stats.avgReduction}%`;
  summaryMessage += `\n• URLs extracted: ${stats.totalUrls}`;
  summaryMessage += `\n• Non-English emails: ${stats.nonEnglishCount}`;
  summaryMessage += `\n• Promotional emails: ${stats.promotionalCount}`;
}
```

**Track Metrics:**
- Token count before/after sanitization
- Processing time per email
- Schema compliance rate
- Language distribution
- Promotional email detection accuracy

---

## Success Criteria

**After implementing sanitization, execution 191 should achieve:**
- ✅ **0% parsing failures** (down from 25%)
- ✅ **100% schema compliance**
- ✅ **Average 70% token reduction** on promotional emails
- ✅ **English-only output** regardless of email language
- ✅ **No context overflows** (4,096 token limit)
- ✅ **30-40% faster processing** due to reduced token count

---

## References

- **Investigation Report**: `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md`
- **Workflow File**: `workflows/Gmail to Telegram.json`
- **Current Prompt Location**: Line 242 (system parameter)
- **Recommended Model**: qwen2.5:7b (per investigation 200)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-08
**Status**: Ready for Implementation
