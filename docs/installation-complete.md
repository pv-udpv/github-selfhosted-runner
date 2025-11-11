# Complete Installation Guide

## Installation Flowchart

```mermaid
flowchart TD
    A[Start] --> B[Pre-install Checks]
    B --> C[Clone Repository]
    C --> D[Create GitHub App]
    D --> E[Download Private Key]
    E --> F[Configure runner.env]
    F --> G[Install Private Key]
    G --> H[Build Docker Image]
    H --> I[Run Deploy Script]
    I --> J[Start Runner Container]
    J --> K[Check Runner Logs]
    K --> L{Runner Registered in GitHub?}
    L -- Yes --> M[Run Test Workflow]
    L -- No --> N[Troubleshoot Setup]
    M --> O[Health Check]
    O --> P[Production Use]
    N --> K
```

---

Detailed step-by-step guide for installing and deploying GitHub Self-Hosted Runner from scratch.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Process](#installation-process)
  - [Phase 1: Environment Setup](#phase-1-environment-setup)
  - [Phase 2: GitHub App Configuration](#phase-2-github-app-configuration)
  - [Phase 3: Runner Configuration](#phase-3-runner-configuration)
  - [Phase 4: Deployment](#phase-4-deployment)
  - [Phase 5: Verification](#phase-5-verification)
- [Post-Installation](#post-installation)
- [Advanced Scenarios](#advanced-scenarios)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

...