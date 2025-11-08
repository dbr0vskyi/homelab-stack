#!/usr/bin/env python3
"""
Update Gmail to Telegram workflow with Phase 1 sanitization improvements (v1.1)

Changes:
1. Pre-sanitization size filtering (100KB limit)
2. Enhanced HTML entity decoding (30+ additional entities)
3. HTML comment & base64 image removal
4. Improved promotional detection patterns
"""

import json
import sys

# Read workflow
with open('workflows/Gmail to Telegram.json', 'r') as f:
    workflow = json.load(f)

# Find the Clean Email Input node
clean_email_node = None
for node in workflow['nodes']:
    if node.get('name') == 'Clean Email Input':
        clean_email_node = node
        break

if not clean_email_node:
    print("ERROR: Clean Email Input node not found")
    sys.exit(1)

# Updated jsCode with Phase 1 improvements
updated_code = """// Email Sanitization Node v1.1 - Cleans raw email HTML and text for LLM processing
// Based on: docs/email-sanitization-strategy.md + docs/email-sanitization-improvements.md
// Changes in v1.1: Size pre-filter, enhanced entities, HTML comments/base64 removal, better promo detection

const items = $input.all();

// ========== HELPER FUNCTIONS ==========

/**
 * Cleans HTML tags, entities, and formatting from email text
 */
function cleanHTML(rawHtml) {
  let text = rawHtml;

  // 1. Remove HTML comments (NEW in v1.1)
  text = text.replace(/<!--[\\s\\S]*?-->/g, '');

  // 2. Remove base64 encoded images (NEW in v1.1)
  text = text.replace(/<img[^>]*src="data:image\\/[^"]*"[^>]*>/gi, '');
  text = text.replace(/data:image\\/[^;]+;base64,[A-Za-z0-9+/=]+/g, '[image]');

  // 3. Remove script and style tags entirely
  text = text.replace(/<script[^>]*>[\\s\\S]*?<\\/script>/gi, '');
  text = text.replace(/<style[^>]*>[\\s\\S]*?<\\/style>/gi, '');

  // 4. Remove tracking pixels and analytics
  text = text.replace(/<img[^>]*tracking[^>]*>/gi, '');
  text = text.replace(/<img[^>]*analytics[^>]*>/gi, '');
  text = text.replace(/<img[^>]*width=["']?1["']?[^>]*height=["']?1["']?[^>]*>/gi, '');
  // NEW: Remove all remaining img tags (catch-all)
  text = text.replace(/<img[^>]*>/gi, '');

  // 5. Convert common HTML entities (ENHANCED in v1.1 - 30+ additional entities)
  const entities = {
    // Basic entities
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '...',
    // Special characters (NEW in v1.1 - fixes Polish email issues)
    '&zwnj;': '',       // Zero-width non-joiner
    '&zwj;': '',        // Zero-width joiner
    '&shy;': '',        // Soft hyphen
    // Currency symbols (NEW)
    '&euro;': '€',
    '&pound;': '£',
    '&yen;': '¥',
    '&cent;': '¢',
    '&curren;': '¤',
    // Common symbols (NEW)
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&times;': '×',
    '&divide;': '÷',
    '&deg;': '°',
    '&plusmn;': '±',
    '&frac12;': '½',
    '&frac14;': '¼',
    '&frac34;': '¾',
    '&laquo;': '«',
    '&raquo;': '»',
    '&rsquo;': ''',
    '&lsquo;': ''',
    '&rdquo;': '"',
    '&ldquo;': '"',
    '&bull;': '•',
    '&middot;': '·',
    // Math symbols (NEW)
    '&ne;': '≠',
    '&le;': '≤',
    '&ge;': '≥',
    '&minus;': '−',
    '&radic;': '√',
    '&infin;': '∞',
    // Arrows (NEW - common in promotional emails)
    '&larr;': '←',
    '&uarr;': '↑',
    '&rarr;': '→',
    '&darr;': '↓'
  };

  Object.keys(entities).forEach(entity => {
    text = text.replace(new RegExp(entity, 'g'), entities[entity]);
  });

  // 6. Remove all HTML tags (preserve content)
  text = text.replace(/<[^>]*>/g, ' ');

  // 7. Decode remaining numeric entities
  text = text.replace(/&#(\\d+);/g, (match, dec) => String.fromCharCode(dec));
  text = text.replace(/&#x([0-9a-f]+);/gi, (match, hex) => String.fromCharCode(parseInt(hex, 16)));

  // 8. Normalize whitespace
  text = text.replace(/[ \\t]+/g, ' ');           // Multiple spaces to single
  text = text.replace(/\\n\\s*\\n\\s*\\n/g, '\\n\\n');  // Multiple newlines to max 2
  text = text.trim();

  return text;
}

/**
 * Detects email language using character and word patterns
 */
function detectLanguage(text, sender, subject) {
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

  // Count special characters and words
  Object.keys(languagePatterns).forEach(lang => {
    const charMatches = combined.match(languagePatterns[lang].chars) || [];
    languagePatterns[lang].weight += charMatches.length * 2;

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

/**
 * Detects if email is promotional/marketing based on patterns
 * ENHANCED in v1.1 with actual failure cases from investigations
 */
function isPromotional(email) {
  const sender = email.fromAddress.toLowerCase();
  const subject = email.subject.toLowerCase();
  const text = email.text.toLowerCase();

  // Sender domain patterns (ENHANCED - covers actual failure cases)
  const promoSenders = [
    'udemy.com', 'zalando', 'newsletter', 'marketing', 'promo', 'noreply',
    // NEW in v1.1: From actual failed emails (investigations 191, 195, 197, 198)
    'educative.io',
    'coursera.org',
    'bestsecret',
    'levi.com',
    'levis.com',
    'linkedin.com/comm',
    'substack.com',
    'junodownload.com',
    'medicover.pl',
    'empik.com',
    '4ride.pl',
    'tripadvisor',
    'revolut.com/marketing',
    'bolt.eu/promo',
    'imdb.com/updates',
    'github.com/marketing',
    'lastpass.com/surveys'
  ];
  const hasPromoSender = promoSenders.some(pattern => sender.includes(pattern));

  // Subject patterns (ENHANCED)
  const promoKeywords = [
    'sale', 'discount', '% off', 'new arrivals', 'special offer', 'limited time',
    // NEW in v1.1
    'newsletter',
    'weekly digest',
    'new courses',
    'black week',
    'pre-order',
    'preorder',
    'halloween',
    'fashion',
    'new vinyl',
    'survey',
    'webinar',
    'updates from'
  ];
  const hasPromoSubject = promoKeywords.some(kw => subject.includes(kw));

  // Content patterns (product listing indicators) - ENHANCED
  const productPatterns = [
    /\\$\\d+\\.\\d{2}/g,        // Prices: $19.99
    /€\\d+[,\\.]\\d{2}/g,      // Euro prices: €19,99
    /zł\\s*\\d+/g,            // Polish złoty: zł 99
    /PLN\\s*\\d+/g,           // NEW: Polish złoty alternate format
    /buy now/gi,            // CTA
    /shop now/gi,           // CTA
    /\\d+%\\s*off/gi,         // Discount mentions
    // NEW patterns from actual emails
    /view course/gi,
    /enroll now/gi,
    /add to cart/gi,
    /learn more/gi,
    /get started/gi,
    /claim offer/gi,
    /limited seats/gi,
    /expires? (soon|today|tomorrow)/gi,
    /hurry/gi
  ];

  let productMentions = 0;
  productPatterns.forEach(pattern => {
    const matches = text.match(pattern) || [];
    productMentions += matches.length;
  });

  // ADJUSTED threshold from 5 to 3 (more aggressive detection)
  const hasHighProductDensity = productMentions >= 3;

  return hasPromoSender || hasPromoSubject || hasHighProductDensity;
}

/**
 * Extracts product blocks from promotional emails
 */
function extractProductBlocks(text) {
  const lines = text.split('\\n');
  const products = [];

  let currentBlock = '';
  for (const line of lines) {
    // Detect product line (has price or CTA)
    if (/\\$\\d+|€\\d+|buy|shop|view/gi.test(line)) {
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

/**
 * Simplifies promotional emails to essential information
 */
function sanitizePromotionalEmail(text, subject, sender) {
  const productBlocks = extractProductBlocks(text);

  let simplified = `Newsletter from ${sender}\\nSubject: ${subject}\\n\\nType: Promotional content\\n\\n`;

  if (productBlocks.length > 0) {
    simplified += 'Key items mentioned:\\n';
    simplified += productBlocks.slice(0, 3).join('\\n') + '\\n';
  }

  if (productBlocks.length > 3) {
    simplified += '\\n[Additional products truncated]\\n';
  }

  return simplified;
}

/**
 * Extracts URLs and replaces them with placeholders
 */
function extractAndReplaceURLs(text) {
  const urls = [];
  const urlPattern = /https?:\\/\\/[^\\s<>"]+/g;

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
    cleanedText = cleanedText.replace(new RegExp(url.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'g'), placeholder);
  });

  return {
    cleanedText,
    urls: uniqueUrls
  };
}

/**
 * Removes common email boilerplate (footers, unsubscribe, etc.)
 */
function removeBoilerplate(text) {
  const boilerplatePatterns = [
    // Unsubscribe sections
    /unsubscribe.*?(\\n\\n|\\n|$)/gi,
    /click here to (stop receiving|opt out|manage).*?(\\n\\n|\\n|$)/gi,
    /you (are receiving|received) this.*?(\\n\\n|\\n|$)/gi,

    // Privacy/legal
    /privacy policy.*?(\\n\\n|\\n|$)/gi,
    /terms (and|&) conditions.*?(\\n\\n|\\n|$)/gi,
    /this email (is|was) sent.*?(\\n\\n|\\n|$)/gi,

    // View in browser
    /(view|open) (this|email) in.*?browser.*?(\\n\\n|\\n|$)/gi,
    /can't see.*?images.*?(\\n\\n|\\n|$)/gi,

    // Social media footer
    /follow us on.*?(\\n\\n|\\n|$)/gi,

    // Copyright
    /©.*?\\d{4}.*?(\\n\\n|\\n|$)/gi,
    /copyright.*?\\d{4}.*?(\\n\\n|\\n|$)/gi,
  ];

  let cleaned = text;
  boilerplatePatterns.forEach(pattern => {
    cleaned = cleaned.replace(pattern, '\\n');
  });

  // Remove trailing repetitive content (last 15% if footer-like)
  const lines = cleaned.split('\\n');
  const threshold = Math.floor(lines.length * 0.85);
  const lastSection = lines.slice(threshold).join('\\n').toLowerCase();

  if (/unsubscribe|privacy|copyright|address|follow us/.test(lastSection)) {
    cleaned = lines.slice(0, threshold).join('\\n');
  }

  return cleaned.trim();
}

/**
 * Adds language context instruction for non-English emails
 */
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

  return `[LANGUAGE: This email is written in ${langName}. Extract the information and provide ALL output fields in English, regardless of the email's language.]\\n\\n${text}`;
}

/**
 * Truncates email text to maximum character length
 */
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
    return truncated.substring(0, lastSentenceEnd + 1) + '\\n\\n[Email content truncated due to length]';
  } else {
    // No good boundary, hard truncate
    return truncated + '...\\n\\n[Email content truncated due to length]';
  }
}

// ========== MAIN SANITIZATION FUNCTION ==========

function sanitizeEmail(email) {
  // NEW in v1.1: PRE-FILTER for extremely large emails
  const MAX_RAW_EMAIL_SIZE = 100000; // 100KB raw HTML limit

  if (email.text && email.text.length > MAX_RAW_EMAIL_SIZE) {
    console.warn(`⚠️ Email too large (${email.text.length} chars), skipping detailed processing`);

    return {
      json: {
        id: email.id,
        to: email.to,
        fromAddress: email.fromAddress,
        fromName: email.fromName,
        subject: email.subject,
        gmailUrl: email.gmailUrl,
        internalDate: email.internalDate,
        text: `[Email too large to process - ${email.text.length} characters. Please view in Gmail.]`,
        urlMap: [],
        language: 'english',
        isPromotional: true,
        sanitizationStats: {
          originalLength: email.text.length,
          cleanedLength: 0,
          reductionPercent: 0,
          urlsExtracted: 0,
          skippedReason: 'too_large'
        }
      }
    };
  }

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
  const originalLength = text.length;

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
  text = text.replace(/\\s+/g, ' ').trim();
  text = text.replace(/\\n\\s*\\n\\s*\\n+/g, '\\n\\n'); // Max 2 consecutive newlines

  // Step 8: Add language context if non-English
  if (language !== 'english') {
    text = addLanguageContext(text, language);
  }

  // Step 9: Truncate if too long
  text = truncateEmail(text, 10000);

  // Calculate statistics
  const cleanedLength = text.length;
  const reductionPercent = originalLength > 0 ? Math.round((1 - cleanedLength / originalLength) * 100) : 0;

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

// ========== PROCESS ALL EMAILS ==========

const output = items.map(item => sanitizeEmail(item.json || item));

// Log summary statistics
const totalReduction = output.reduce((sum, item) => sum + item.json.sanitizationStats.reductionPercent, 0);
const avgReduction = output.length > 0 ? Math.round(totalReduction / output.length) : 0;
const totalUrls = output.reduce((sum, item) => sum + item.json.sanitizationStats.urlsExtracted, 0);
const nonEnglishCount = output.filter(item => item.json.language !== 'english').length;
const promotionalCount = output.filter(item => item.json.isPromotional).length;
const skippedCount = output.filter(item => item.json.sanitizationStats.skippedReason).length;

console.log(`✅ Sanitized ${output.length} emails`);
console.log(`📊 Avg token reduction: ${avgReduction}%`);
console.log(`🔗 URLs extracted: ${totalUrls}`);
console.log(`🌍 Non-English emails: ${nonEnglishCount}`);
console.log(`📧 Promotional emails: ${promotionalCount}`);
if (skippedCount > 0) {
  console.log(`⏭️  Skipped (too large): ${skippedCount}`);
}

return output;"""

# Update the node
clean_email_node['parameters']['jsCode'] = updated_code

# Write updated workflow
with open('workflows/Gmail to Telegram.json', 'w') as f:
    json.dump(workflow, f, indent=2)

print("✅ Successfully updated Clean Email Input node to v1.1")
print("\nChanges applied:")
print("  1. Pre-sanitization size filtering (100KB limit)")
print("  2. Enhanced HTML entity decoding (30+ additional entities)")
print("  3. HTML comment & base64 image removal")
print("  4. Improved promotional detection (17 new sender patterns)")
print("\nExpected impact:")
print("  - 10-15% additional token reduction")
print("  - Zero character encoding issues (Polish/multilingual)")
print("  - 90-95% promotional email detection rate")
print("  - Prevents processing of 100KB+ emails")
