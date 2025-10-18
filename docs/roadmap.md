# 🗺️ Homelab Stack Roadmap

This document tracks planned improvements, fixes, and enhancements for the homelab automation stack.

## 📋 Current TODOs

### 🔥 High Priority

#### 1. Lightweight Monitoring & Logging

**Status:** Planning  
**Priority:** High  
**Estimated Effort:** 2-3 days

**Description:**  
Implement a lightweight monitoring and logging stack optimized for Raspberry Pi 5 with LLM workloads.

**Requirements:**

- [ ] Monitor system metrics (temperature, CPU throttling, RAM, disk space)
- [ ] Collect Docker container/service metrics
- [ ] Centralize logs with minimal disk I/O
- [ ] Provide dashboards and alerts for critical thresholds
- [ ] Ensure resource usage stays within 1.5 GB RAM

**Technical Approach:**

- **Metrics Collection:** Prometheus (30–60s scrape, 7–15d retention) + Node Exporter + cAdvisor
- **Log Aggregation:** Loki (7–14d retention, drop noisy logs) + Promtail
- **Visualization:** Grafana (RAM limit ≤ 350 MB, refresh ≥ 30s)
- **Access:** Tailscale or reverse-proxy under single TLS endpoint

**Implementation Steps:**

1. Add Prometheus, Loki, Grafana to `docker-compose.yml`
2. Configure Node Exporter and cAdvisor for metrics
3. Set up Promtail for log shipping
4. Create Grafana dashboards for metrics and logs
5. Configure alerting rules for critical metrics
6. Document setup and usage

**Files to Modify:**

- `docker-compose.yml` - Add monitoring stack services
- `config/` - Add monitoring configurations
- `docs/` - Add monitoring documentation

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

#### 5. Performance Optimization

- [ ] Pin LLM cores: dedicate 3–4 cores to Ollama, 1 core to monitoring
- [ ] Resource usage monitoring and optimization
- [ ] Database performance tuning

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

| Feature           | Impact | Effort | Priority | Status      |
| ----------------- | ------ | ------ | -------- | ----------- |
| System Monitoring | High   | Medium | 1        | Planning    |
| Traefik Proxy     | High   | Medium | 3        | Planning    |
| Enhanced Backups  | Medium | Low    | 4        | Improvement |
| Performance       | Medium | Low    | 5        | Future      |

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

_Last Updated: October 18, 2025_  
_Next Review: Weekly during active development_
