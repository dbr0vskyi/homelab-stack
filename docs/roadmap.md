# 🗺️ Homelab Stack Roadmap

This document tracks planned improvements, fixes, and enhancements for the homelab automation stack.

## 📋 Current TODOs

### 🔥 High Priority

#### 1. Lightweight Monitoring & Logging

**Status:** ✅ Completed
**Priority:** High
**Completed:** December 2024

**Description:**
Implement a lightweight monitoring and logging stack optimized for Raspberry Pi 5 with LLM workloads.

**Completed Features:**

- [x] Query workflow execution history from database
- [x] Monitor system metrics (temperature, CPU throttling, RAM, disk space)
- [x] Collect Docker container/service metrics
- [x] Provide dashboards and alerts for critical thresholds
- [x] Optimized resource usage for Raspberry Pi

**Implementation:**

- **Metrics Collection:** Prometheus + Node Exporter + thermal-exporter
- **Visualization:** Grafana with Pi-optimized dashboards
- **Quick Setup:** Included by default in `./scripts/setup.sh` or `./scripts/deploy-monitoring.sh`
- **Management:** `./scripts/manage.sh monitoring-*` commands

**Files Modified:**

- ✅ `docker-compose.yml` - Added monitoring profile
- ✅ `config/` - Added monitoring configurations
- ✅ `docs/monitoring.md` - Complete setup guide
- ✅ `scripts/lib/monitoring.sh` - Modular monitoring library

---

#### 2. Reverse Proxy with Traefik Integration

**Status:** Planning  
**Priority:** Medium-High  
**Estimated Effort:** 2-3 days

**Description:**  
Implement Traefik reverse proxy for better Docker integration, SSL termination, and service routing.

**Requirements:**

- [ ] Replace direct port access with domain-based routing
- [ ] Automatic SSL certificate management (Let's Encrypt integration)
- [ ] Docker service auto-discovery
- [ ] Centralized access control

**Implementation Steps:**

1. Add Traefik service to `docker-compose.yml`
2. Configure Traefik with Docker provider
3. Add labels to existing services for auto-discovery
4. Set up SSL certificate management
5. Update Tailscale integration for new routing
6. Document new URLs and setup

**Files to Modify:**

- `docker-compose.yml` - Add Traefik service and labels
- `config/traefik/` - New directory for Traefik configuration
- `docs/` - Update documentation with new service URLs

---

### 🔧 Medium Priority

#### 3. Enhanced Backup System

**Status:** Improvement  
**Priority:** Medium  
**Estimated Effort:** 1 day

**Description:**  
Improve existing backup system with automated scheduling, retention policies, and health checks.

**Requirements:**

- [ ] Automated backup scheduling (cron integration)
- [ ] Configurable retention policies
- [ ] Backup health verification
- [ ] Disk hygiene: NVMe trim + log rotation

---

#### 4. N8N Task Runner Implementation

**Status:** Research Required  
**Priority:** Medium  
**Estimated Effort:** 1-2 days

**Description:**  
Investigate and implement the n8n task runner to improve workflow reliability and performance.

**Requirements:**

- [ ] Research n8n task runner capabilities and benefits
- [ ] Assess current workflow performance bottlenecks
- [ ] Implement task runner configuration
- [ ] Test workflow performance improvements
- [ ] Update documentation

**Implementation Steps:**

1. Review n8n official task runner documentation
2. Analyze current n8n configuration and performance
3. Configure task runner in docker-compose or n8n settings
4. Test existing workflows with task runner enabled
5. Document configuration and performance improvements

**Files to Modify:**

- `docker-compose.yml` - Potentially update n8n service configuration
- `docs/workflows.md` - Document task runner setup and benefits

---

### 🎯 Low Priority / Future Enhancements

#### 5. Hardware Performance Optimization

**Status:** Research & Testing  
**Priority:** Low  
**Estimated Effort:** 1-2 days

**Description:**  
Implement and test hardware optimizations from the hardware setup guide to improve system performance.

**Requirements:**

- [ ] Pin LLM cores: dedicate 3–4 cores to Ollama, 1 core to monitoring
- [ ] Test different memory configurations for optimal performance
- [ ] Implement CPU governor tuning for better performance/efficiency balance
- [ ] Compare performance results before and after optimizations
- [ ] Document performance improvements and resource usage

**Implementation Steps:**

1. Establish baseline performance metrics
2. Apply hardware optimizations from hardware-setup.md
3. Test CPU core pinning for Ollama workloads
4. Benchmark memory configuration changes
5. Document performance comparisons and recommendations

**Files to Modify:**

- System configuration files (boot config, systemd)
- `docs/hardware-setup.md` - Update with tested optimizations and results

---

## 🔄 Workflow Improvements

### 📧 Gmail to Telegram Workflow Enhancements

#### 1. Multi-User Support Implementation

**Status:** Planning  
**Priority:** Medium  
**Estimated Effort:** 2-3 days

**Description:**  
Enhance the Gmail to Telegram workflow to support multiple users instead of the current single hardcoded chat implementation.

**Current Limitations:**

- Only one hardcoded chat ID is supported
- No user authorization flow
- Manual setup required for each new user

**Requirements:**

- [ ] Implement dynamic chat ID recording and storage
- [ ] Create user authorization flow for Gmail access
- [ ] Store chat IDs persistently (database or file-based)
- [ ] Implement setup actions when bot is started
- [ ] Trigger automatic schedule creation for new users
- [ ] Add user management interface or commands

**Technical Approach:**

- **Chat ID Storage:** Use Redis or PostgreSQL to store user chat IDs
- **Authorization Flow:** Implement OAuth callback handling for Gmail
- **Bot Interaction:** Add /setup command to initialize user configuration
- **Schedule Management:** Automatically create individual schedules per user

**Implementation Steps:**

1. Modify n8n workflow to support dynamic chat ID lookup
2. Implement user registration flow via Telegram bot commands
3. Add Gmail OAuth authorization handling
4. Create persistent storage for user configurations
5. Implement automatic schedule creation per user
6. Add user management and cleanup functionality
7. Update documentation with multi-user setup instructions

**Files to Modify:**

- `workflows/gmail-to-telegram.json` - Update workflow for multi-user support
- `config/postgres/init.sql` - Add user management tables (if using PostgreSQL)
- `docs/workflows.md` - Document multi-user setup process

#### 2. Enhanced Error Handling & Notifications

**Status:** Future Enhancement  
**Priority:** Low  
**Estimated Effort:** 1 day

**Description:**  
Improve workflow reliability with better error handling and user notifications.

**Requirements:**

- [ ] Implement retry mechanisms for failed API calls
- [ ] Add user notifications for workflow failures
- [ ] Create workflow health monitoring
- [ ] Add rate limiting awareness for Gmail API

---

## 🔒 Infrastructure & Security

### 1. Workflow Security Hardening

**Status:** Critical - Immediate Action Required  
**Priority:** High  
**Estimated Effort:** 1-2 days

**Description:**  
Address security vulnerabilities in existing workflow configurations and implement secure practices for credential management and sensitive data handling.

**Current Security Issues:**

- [ ] **Hardcoded sensitive data:** Chat IDs, credential references, and webhook IDs exposed in workflow JSON files
- [ ] **Public repository exposure:** Sensitive workflow configurations committed to public GitHub repository
- [ ] **No environment variable usage:** Direct embedding of sensitive values in workflow definitions
- [ ] **Missing credential rotation:** No process for regular credential updates

**Requirements:**

- [ ] Remove all hardcoded sensitive values from workflow files
- [ ] Implement environment variable-based configuration
- [ ] Create secure credential management process
- [ ] Add git history cleanup for exposed sensitive data
- [ ] Establish credential rotation schedule

**Implementation Steps:**

1. **Immediate Security Actions:**

   - [ ] Regenerate all exposed Telegram bot tokens
   - [ ] Recreate Gmail OAuth credentials
   - [ ] Update n8n credential references
   - [ ] Clean sensitive data from git history using `git filter-branch`

2. **Environment Variable Migration:**

   - [ ] Create `.env.template` files for all workflows
   - [ ] Replace hardcoded values with `{{ $env.VARIABLE_NAME }}` expressions
   - [ ] Update workflow JSON files to use environment variables
   - [ ] Add comprehensive `.env` documentation

3. **Repository Security:**
   - [ ] Update `.gitignore` to exclude sensitive workflow files
   - [ ] Create workflow templates with placeholder values
   - [ ] Add security guidelines to project documentation
   - [ ] Implement pre-commit hooks for sensitive data detection

**Files to Modify:**

- `workflows/gmail-to-telegram.json` - Remove hardcoded sensitive values
- `workflows/.env.template` - Create environment template
- `.gitignore` - Add sensitive file patterns
- `docs/security-guidelines.md` - New security documentation

---

### 2. Workflow Modularity & Reusability

**Status:** Planning  
**Priority:** Medium-High  
**Estimated Effort:** 2-3 days

**Description:**  
Refactor workflows to be modular, configurable, and easily reusable by other users without hardcoded dependencies.

**Current Limitations:**

- [ ] Workflows contain user-specific hardcoded values
- [ ] No standardized configuration approach
- [ ] Missing setup automation for new users
- [ ] Lack of workflow documentation templates

**Requirements:**

- [ ] Create configurable workflow templates
- [ ] Implement dynamic configuration loading
- [ ] Add automated setup scripts for new installations
- [ ] Develop standardized workflow documentation

**Implementation Steps:**

1. **Workflow Template Creation:**

   - [ ] Extract configuration variables from all workflows
   - [ ] Create parameterized workflow templates
   - [ ] Implement configuration validation
   - [ ] Add default value handling

2. **Configuration Management:**

   - [ ] Design unified configuration schema
   - [ ] Implement environment-based configuration loading
   - [ ] Add configuration validation and error handling
   - [ ] Create configuration migration tools

3. **Setup Automation:**

   - [ ] Create interactive setup script for new users
   - [ ] Implement automatic environment file generation
   - [ ] Add workflow import/export functionality
   - [ ] Develop configuration backup and restore

4. **Documentation & Templates:**
   - [ ] Create workflow setup guide templates
   - [ ] Add configuration reference documentation
   - [ ] Implement automated documentation generation
   - [ ] Create troubleshooting guides

**Files to Create:**

- `workflows/templates/` - Directory for workflow templates
- `scripts/workflow-setup.sh` - Interactive workflow setup script
- `config/workflows/` - Centralized workflow configurations
- `docs/workflow-setup-guide.md` - User setup documentation

**Files to Modify:**

- All workflow JSON files - Convert to templates
- `scripts/setup.sh` - Add workflow configuration steps
- `docs/workflows.md` - Update with new setup process

---

### 3. Credential Management System

**Status:** Planning  
**Priority:** Medium  
**Estimated Effort:** 2-3 days

**Description:**  
Implement a secure credential management system for storing and rotating API keys, tokens, and sensitive configuration.

**Requirements:**

- [ ] Secure credential storage (encrypted at rest)
- [ ] Automated credential rotation capabilities
- [ ] Audit logging for credential access
- [ ] Integration with existing n8n workflows

**Technical Approach:**

- **Storage:** Utilize existing PostgreSQL with encryption for credential storage
- **Access:** Environment variable injection with secure defaults
- **Rotation:** Automated scripts for supported APIs (Telegram, Gmail OAuth)
- **Audit:** Log all credential access and rotation events

**Implementation Steps:**

1. **Database Schema:**

   - [ ] Design encrypted credential storage tables
   - [ ] Implement credential versioning for rotation
   - [ ] Add audit logging tables
   - [ ] Create database migration scripts

2. **Management Interface:**

   - [ ] Create CLI tool for credential management
   - [ ] Implement credential encryption/decryption
   - [ ] Add credential rotation automation
   - [ ] Build audit log querying

3. **Integration:**
   - [ ] Update n8n environment variable injection
   - [ ] Modify workflows to use managed credentials
   - [ ] Add health checks for credential validity
   - [ ] Implement graceful fallback mechanisms

**Files to Create:**

- `scripts/credential-manager.sh` - CLI credential management tool
- `config/postgres/credentials.sql` - Credential storage schema
- `lib/credentials.sh` - Credential management library
- `docs/credential-management.md` - Usage documentation

---

### 4. Security Monitoring & Alerting

**Status:** Future Enhancement  
**Priority:** Medium  
**Estimated Effort:** 1-2 days

**Description:**  
Implement security monitoring and alerting for unauthorized access attempts, credential misuse, and system security events.

**Requirements:**

- [ ] Monitor failed authentication attempts
- [ ] Alert on unusual API usage patterns
- [ ] Track credential access and rotation events
- [ ] Integration with existing monitoring stack

**Implementation Steps:**

1. **Security Event Collection:**

   - [ ] Add security logging to all workflows
   - [ ] Implement API rate limit monitoring
   - [ ] Track authentication events
   - [ ] Monitor system access patterns

2. **Alert Configuration:**
   - [ ] Define security alert thresholds
   - [ ] Implement Telegram notifications for security events
   - [ ] Add email alerting for critical issues
   - [ ] Create security dashboard in Grafana

**Files to Modify:**

- Monitoring configuration files - Add security metrics
- Alert rule definitions - Security-specific alerts
- `docs/security-monitoring.md` - Security monitoring guide

---

## 🏗️ Architecture Decisions

### Monitoring Stack Choice: Prometheus + Loki + Grafana

**Rationale:**

- **Prometheus:** Industry standard for metrics, excellent Docker integration
- **Loki:** Lightweight log aggregation, pairs well with Prometheus
- **Grafana:** Unified dashboard for both metrics and logs, extensive visualization options
- **Alternative considered:** ELK stack (too resource-heavy for Raspberry Pi)

### Reverse Proxy Choice: Traefik

**Rationale:**

- **Excellent Docker integration:** Auto-discovery via labels
- **SSL automation:** Built-in Let's Encrypt support
- **Lightweight:** Suitable for Raspberry Pi resources
- **Configuration:** File-based and dynamic configuration support
- **Alternative considered:** Nginx Proxy Manager (less Docker-native)

---

## 📊 Implementation Priority Matrix

| Feature                 | Impact       | Effort  | Priority | Status       |
| ----------------------- | ------------ | ------- | -------- | ------------ |
| **Workflow Security**   | **Critical** | **Low** | **0**    | **Critical** |
| System Monitoring       | High         | Medium  | 1        | Planning     |
| Traefik Proxy           | High         | Medium  | 2        | Planning     |
| Workflow Modularity     | High         | Medium  | 3        | Planning     |
| Multi-User Workflows    | Medium       | High    | 4        | Planning     |
| Credential Management   | Medium       | Medium  | 5        | Planning     |
| Enhanced Backups        | Medium       | Low     | 6        | Improvement  |
| Security Monitoring     | Medium       | Low     | 7        | Future       |
| Hardware Optimization   | Medium       | Low     | 8        | Research     |
| Workflow Error Handling | Low          | Low     | 9        | Future       |

---

## 🔄 Update Process

1. **Planning Phase:** Research and document requirements
2. **Implementation:** Create feature branch, implement changes
3. **Testing:** Validate on development environment
4. **Documentation:** Update relevant docs and this roadmap
5. **Deployment:** Merge to main, update production

---

## 📝 Notes

- All implementations should maintain Raspberry Pi compatibility
- Prioritize resource efficiency given hardware constraints
- Ensure backward compatibility with existing workflows
- Document all changes for team knowledge sharing

---

_Last Updated: October 20, 2025_  
_Next Review: Weekly during active development_
