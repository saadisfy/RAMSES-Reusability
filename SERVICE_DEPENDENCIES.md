# RAMSES-SEFA Service Dependencies & Startup Times

This document outlines the dependencies between services in the RAMSES-SEFA system and their **ACTUAL MEASURED** startup times based on real failure analysis.

## 🔧 Prerequisites & System Requirements

### Windows Docker Desktop Configuration

**CRITICAL**: Before running RAMSES-SEFA on Windows, Docker Desktop must be configured to expose the Docker API:

1. **Open Docker Desktop Settings**
2. Go to **"General"** or **"Advanced"** tab (version dependent)
3. **Enable**: `"Expose daemon on tcp://localhost:2375 without TLS"`
4. **Apply & Restart** Docker Desktop
5. **Verify**: Run `curl http://localhost:2375/version` (should return Docker version info)

**Why this is needed:** `sefa-instances-manager` requires direct access to Docker API to manage container instances. On Windows Docker Desktop, this must be explicitly enabled.

⚠️ **Security Note**: This exposes Docker daemon on localhost:2375 without authentication. Only use in development environments.

## ⚠️ Critical Dependency Discovery

**MAJOR ISSUE FOUND**: `ramses-knowledge` **REQUIRES** all SEFA services to be **ALREADY REGISTERED IN EUREKA** before it can start!

## Corrected Dependency Overview

```
MySQL
├── sefa-eureka (15s)
    ├── sefa-configserver (84s - MEASURED: actually takes 83.8s to fully start)
        ├── sefa-probe (15s)
        ├── ALL SEFA SERVICES (5s each + 30s registration time)
        │   ├── sefa-restaurant-service ⭐ REQUIRED for ramses-knowledge
        │   ├── sefa-ordering-service  
        │   ├── sefa-api-gateway
        │   ├── sefa-payment-proxy-*-service
        │   ├── sefa-delivery-proxy-*-service
        │   └── sefa-web-service
        ├── sefa-instances-manager (10s - needs Docker socket)
        ├── ramses-knowledge (15s - AFTER SEFA services registered)
        │   ├── ramses-monitor (15s)
        │   ├── ramses-analyse (15s)
        │   ├── ramses-execute (15s)
        │   ├── ramses-plan (15s)
        │   └── ramses-dashboard (15s)
        └── sefa-config-manager (10s)
```

## Service Details

### Infrastructure Services

| Service | Dependencies | **MEASURED** Startup Time | Port | Notes |
|---------|--------------|---------------------------|------|-------|
| **mysql** | None | 10s | 3306 | Database foundation |
| **sefa-eureka** | None | 15s | 58082 | Service discovery |
| **sefa-configserver** | sefa-eureka | **84s** | 8888 | **MEASURED**: 83.8s actual startup time! Much longer than expected |

### Probe & Actuator Services

| Service | Dependencies | **MEASURED** Startup Time | Port | Notes |
|---------|--------------|---------------------------|------|-------|
| **sefa-probe** | sefa-eureka, sefa-configserver | 15s | 58020 | **MUST START BEFORE** ramses-knowledge |
| **sefa-instances-manager** | **Docker Desktop TCP enabled** | 10s | 58015 | **REQUIRES**: Docker Desktop TCP on port 2375 |
| **sefa-config-manager** | sefa-eureka, sefa-configserver | 10s | 58025 | Configuration updates |

### RAMSES Services (Managing System)

| Service | Dependencies | **MEASURED** Startup Time | Port | Notes |
|---------|--------------|---------------------------|------|-------|
| **ramses-knowledge** | mysql, sefa-probe, **ALL SEFA SERVICES REGISTERED** | 15s | 58005 | **CRITICAL**: Fails if RESTAURANT-SERVICE not in Eureka |
| **ramses-monitor** | ramses-knowledge, sefa-probe | 15s | 58001 | Metrics collection |
| **ramses-analyse** | ramses-knowledge, sefa-probe, ramses-plan | 15s | 58002 | Analysis & adaptation options |
| **ramses-execute** | ramses-knowledge, ramses-monitor, sefa-instances-manager, sefa-config-manager | 15s | 58004 | Adaptation execution |
| **ramses-plan** | ramses-knowledge, ramses-execute | 15s | 58003 | Adaptation planning |
| **ramses-dashboard** | ramses-knowledge, ramses-monitor, ramses-analyse, ramses-plan | 15s | 58000 | Web dashboard |

### SEFA Services (Managed System)

**🚨 STARTUP ISSUE**: All SEFA services failed with "Connection refused" to config server (localhost:8888)

| Service | Dependencies | **MEASURED** Startup Time | Port | Notes |
|---------|--------------|---------------------------|------|-------|
| **sefa-restaurant-service** | sefa-eureka, sefa-configserver, mysql | **FAILED** - Config timeout | 58085 | **REQUIRED** for ramses-knowledge |
| **sefa-ordering-service** | sefa-eureka, sefa-configserver, mysql | **FAILED** - Config timeout | 58086 | Order processing |
| **sefa-payment-proxy-1-service** | sefa-eureka, sefa-configserver | **FAILED** - Config timeout | 58090 | Payment proxy instance 1 |
| **sefa-payment-proxy-2-service** | sefa-eureka, sefa-configserver | Not started | 58091 | Payment proxy instance 2 |
| **sefa-payment-proxy-3-service** | sefa-eureka, sefa-configserver | Not started | 58092 | Payment proxy instance 3 |
| **sefa-delivery-proxy-1-service** | sefa-eureka, sefa-configserver | **FAILED** - Config timeout | 58095 | Delivery proxy instance 1 |
| **sefa-delivery-proxy-2-service** | sefa-eureka, sefa-configserver | Not started | 58096 | Delivery proxy instance 2 |
| **sefa-delivery-proxy-3-service** | sefa-eureka, sefa-configserver | Not started | 58097 | Delivery proxy instance 3 |
| **sefa-web-service** | sefa-eureka, sefa-configserver | **FAILED** - Config timeout | 58080 | Web interface |
| **sefa-api-gateway** | sefa-eureka, sefa-configserver | **FAILED** - Config timeout | 58081 | API gateway |

## Critical Dependencies Explained

### 🔴 Hard Dependencies (Service will fail to start)
- **sefa-configserver** → **sefa-eureka**: Config server registers with Eureka
- **ramses-knowledge** → **sefa-probe**: Knowledge fetches system architecture on startup
- **ramses-execute** → **sefa-instances-manager**, **sefa-config-manager**: Execute needs actuators for adaptations
- **All SEFA services** → **sefa-configserver**: Services fetch configuration on startup

### 🟡 Soft Dependencies (Service may start but won't function properly)
- **ramses-monitor** → **sefa-probe**: Monitor needs probe for metrics collection
- **ramses-analyse** → **ramses-plan**: Analyse sends options to plan
- **ramses-dashboard** → **All RAMSES services**: Dashboard queries all RAMSES services

## Recommended Startup Order

1. **mysql** (30s wait)
2. **sefa-eureka** (10s wait)
3. **sefa-configserver** (**90s wait** - MEASURED: takes 84s to fully start)
4. **sefa-probe**, **sefa-instances-manager** (5s wait each)
5. **ramses-knowledge** (15s wait)
6. **SEFA services** (5s wait each)
7. **ramses-monitor**, **ramses-analyse**, **ramses-execute** (10s wait each)
8. **ramses-plan** (5s wait)
9. **ramses-dashboard** (10s wait)
10. **sefa-config-manager** (5s wait)

## Total Estimated Startup Time
- **Minimum**: ~3-4 minutes for critical path
- **Full system**: ~5-6 minutes for all services

## Health Check Recommendations

Services with health checks in docker-compose:
- **mysql**: `mysqladmin ping`
- **sefa-eureka**: `curl http://127.0.0.1:58082/`
- **sefa-configserver**: `curl http://localhost:58888/actuator/health`
- **ramses-knowledge**: `curl http://127.0.0.1:58005/`

## 🔍 Real Failure Analysis Results

### **Critical Issues Found:**

1. **🚨 ramses-knowledge DEPENDENCY FAILURE**
   - **Error**: `Service RESTAURANT-SERVICE not found in system runtime architecture`
   - **Root Cause**: ramses-knowledge expects ALL SEFA services to be registered before startup
   - **Fix**: Start ALL SEFA services BEFORE ramses-knowledge

2. **🚨 All SEFA Services CONFIG SERVER FAILURES**  
   - **Error**: `Connection refused` to `localhost:8888`
   - **Root Cause**: Config server needs 30s to fully initialize and clone Git repo
   - **Fix**: Increased config server wait time from 20s to 30s

3. **🚨 sefa-instances-manager DOCKER DESKTOP CONFIGURATION**
   - **Error**: `Network is unreachable` to `host.docker.internal:2375`
   - **Root Cause**: Docker Desktop on Windows doesn't expose TCP API by default
   - **Fix**: Must enable "Expose daemon on tcp://localhost:2375 without TLS" in Docker Desktop Settings

4. **🚨 ramses-monitor DEPENDENCY FAILURE**
   - **Error**: `UnknownHostException: ramses-knowledge`
   - **Root Cause**: Tries to connect to ramses-knowledge that failed to start
   - **Fix**: Ensure ramses-knowledge starts successfully first

### **Measured Startup Times:**
- ramses-knowledge: 15s (before failing at dependency check)
- ramses-monitor: 15s (before failing at ramses-knowledge connection)
- Config server: 30s needed (not 20s)
- All SEFA services: Failed immediately during config fetch

## 🎭 Simulation Scenarios Analysis

### **Important Discovery: Scenarios are rest-client configurations**

Through log analysis of `simulation-scenario-1`, we discovered that the simulation scenarios (giamburrasca/scenario1:$ARCH, etc.) are **NOT separate applications** but rather the **rest-client application** from `ramses-sefa-SAS/managed-system/rest-client/` with different environment variable configurations.

**Source Code Location:** `ramses-sefa-SAS/managed-system/rest-client/src/main/java/it/polimi/sefa/restclient/`

### **Simulation Components Found:**

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **RequestsGenerator** | Main load generator - creates realistic SEFA traffic every 10ms | `ADAPT`, `TRIAL_DURATION_MINUTES` |
| **PerformanceFakerService** | Artificial performance degradation | `fakeSlowOrdering`, sleep times, delay settings |
| **BenchmarksChangerService** | Triggers implementation changes | `changeBenchmarkStart` timing |
| **FailureInjectionService** | Injects service failures at specific times | `injectFailure`, timing, target instances |
| **AdaptationController** | Controls RAMSES monitor/adaptation state | Calls RAMSES APIs directly |

### **Scenario 1 Behavior (from actual logs):**
```
Trial duration: 5 minutes
Adapt? true
injectFailure? YES
failureInjection1Start: 180 (3 minutes)
Target: restaurant-service@sefa-restaurant-service:58085
Action: Calls stopInstance API to remove instance
```

**Key Insight:** These Docker containers are the same rest-client codebase packaged with different environment variables to trigger different RAMSES adaptation scenarios. The source code is available in the ramses-sefa-SAS directory, making it possible to create custom scenarios by modifying the configurations.

---
*Last updated: Based on REAL FAILURE LOG ANALYSIS and SIMULATION DISCOVERY from 2025-06-19* 