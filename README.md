# Azure Infrastructure Deployment Studio

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FmainTemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FuiFormDefinition.json)

An enterprise-grade, Azure-native deployment wizard providing a polished, multi-step Portal experience for provisioning Azure infrastructure.

Created and maintained by **Mohamed Elrehan** for **Elrehan Academy**.

All source code and configurations are maintained locally, compile deterministic ARM deployment artifacts, and support direct **Deploy to Azure** portal execution as well as manual publishing to **Azure Template Specs**, without requiring custom React applications, external hosting, or workstation-initiated deployments.

---

## Deploy to Azure

Click the **Deploy to Azure** button above to launch the multi-step deployment wizard directly inside the Azure Portal:

```
https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FmainTemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FuiFormDefinition.json
```

> [!IMPORTANT]
> **Repository Visibility Requirement:** For the Azure Portal's `CustomDeploymentBlade` to fetch the ARM template and custom UI form definition anonymously via `raw.githubusercontent.com`, the GitHub repository must be **Public**. In a private repository, Azure Portal will receive an unauthenticated `404 Not Found` unless authenticated via a token.

---

## Key Features

* **100% Azure-Native UX:** Built on official Microsoft Azure Portal Form View technology (`uiFormDefinition.json`) and Azure Resource Manager / Bicep.
* **Multi-Step Wizard Experience:**
  * **Tab 1 — Basics:** Subscription picker, native Resource Group selector (New vs. Existing), region selector (filtered by resource provider), and tags. Contradictory manual provisioning toggles are eliminated; `Microsoft.Common.ResourceScope` natively governs the lifecycle.
  * **Tab 2 — Networking:** VNet name, top-level IPv4 CIDR, and dynamic multi-subnet configuration using `Microsoft.Common.EditableGrid` with dynamic add/remove rows and CIDR regex validation.
  * **Tab 3 — Virtual Machines:** OS platform selection (Linux/Windows), VM name, region-aware dual `Microsoft.Compute.SizeSelector` controls reflecting OS-specific licensing costs, target subnet binding, pilot safety toggle, and conditional credential boxes.
  * **Tab 4 — Review + Create:** Native Azure Portal review synthesis, client-side parameter validation, live pricing estimates, and deployment dispatch.
* **Explicit Pre-Flight Deployment Validation:**
  * **Elimination of Silent Suppression:** Silent suppression (`shouldDeployVm = deployVm && hasValidAuth`) has been completely replaced with explicit `fail()` validation guards. If `deployVm` is true and credentials are invalid or missing, deployment explicitly fails with a descriptive error.
  * **Elimination of Silent Subnet Fallback:** Silent fallback to the first subnet (`subnets[0].name`) has been removed. If `deployVm` is true and the requested subnet does not exist in the configured subnets array, deployment explicitly fails.
  * **SSH Public Key Hardening:** In compliance with Azure Linux VM agent capabilities, authentication strictly permits OpenSSH RSA (`ssh-rsa`, min 2048-bit) and ED25519 (`ssh-ed25519`) keys. Incompatible ECDSA keys are rejected at validation time.
  * **Windows Password Complexity:** Strict length (12-123 characters) and complexity validation.
  * **Zero Hardcoded Credentials:** Zero mock keys, zero placeholder passwords; all credentials default to empty strings.
* **Resource Tag Normalization (`TagsByResource`):**
  * Seamlessly normalizes nested `Microsoft.Common.TagsByResource` Portal output structures (`{"Microsoft.Resources/deployments": {...}}`) to ensure Azure Resource Manager accepts primitive string tag values without runtime failure. Flat parameter dictionaries are simultaneously preserved.
* **Deterministic Network Validation Suite:**
  * Embedded Python network math engine (`scripts/network_validator.py`) validating CIDR containment, subnet overlaps, canonical prefixes, /8 to /29 Azure prefix bounds, and reserved subnet constraints across 8 mandatory test cases.
  * Duplicate subnet name pre-flight validation in `modules/network.bicep`.
* **Modular Bicep Architecture:** Clean separation of concerns with `main.bicep` (subscription-scope orchestrator), `main-rg.bicep` (resource-group scope orchestrator), `modules/network.bicep`, `modules/compute.bicep`, and `modules/nsg.bicep`.
* **Zero Workstation Side-Effects:** No automatic Azure login, subscription alterations, or unsolicited cloud deployments.
* **30-Point Automated QA Test Harness:** Automated test suite verifying Bicep compilation, ARM JSON scope schemas, official UI schema compliance, parameter alignment, security scans, network math, portal artifacts integrity, and 9 ARM evaluation simulation scenarios (**30/30 checks passed**).

---

## Repository Structure

```
azure-infrastructure-deployment-studio/
├── portal/                               # Published artifacts for direct "Deploy to Azure" button
│   ├── mainTemplate.json                 # Resource Group-scope ARM deployment template
│   └── uiFormDefinition.json             # Azure Portal multi-step UI form definition
├── main.bicep                            # Subscription-scope orchestrator with conditional RG logic
├── main.bicepparam                       # Safe baseline parameters file (deployVm = false)
├── main-rg.bicep                         # Resource Group-scope orchestrator (Primary Template Spec)
├── modules/                              # Reusable Bicep infrastructure modules
│   ├── network.bicep                     # Virtual Network and dynamic Subnets loop (UDT typed, dup check)
│   ├── compute.bicep                     # Virtual Machine, NIC, and OS disk (fail() auth validation)
│   └── nsg.bicep                         # Network Security Group modular component
├── ui/                                   # Azure Portal UI definitions
│   ├── uiFormDefinition.json             # Primary target: Template Specs Form view (RG scope)
│   ├── uiFormDefinition.rg.json          # Template Specs Form view (RG scope variant)
│   ├── uiFormDefinition.subscription.json# Template Specs Form view (Subscription scope variant)
│   └── createUiDefinition.json           # Managed Applications & Portal Sandbox definition
├── scripts/                              # Automation & validation scripts
│   ├── build.sh                          # Compiles Bicep to ARM, packages dist/ and portal/, scans secrets
│   ├── network_validator.py              # Deterministic network math & CIDR containment engine
│   ├── validate.sh                       # 30-point local QA verification suite
│   └── publish-template-spec.sh          # Manual Azure CLI publishing helper (dry-run default)
├── docs/                                 # Architectural documentation & test guides
│   ├── sprint-1.2-change-report.md       # Issue-by-issue Sprint 1.2 remediation and audit report
│   ├── validation-report.md              # Automated QA suite results (30/30 passed)
│   ├── portal-test-checklist.md          # Project owner acceptance testing checklist
│   ├── known-limitations.md              # Documented limitations & roadmap
│   ├── feasibility-report.md             # Feasibility analysis across all 8 mandatory criteria
│   └── publishing-guide.md               # Step-by-step Azure Portal publishing guide
├── dist/                                 # Generated deployment outputs
│   ├── main.json                         # Compiled ARM subscription template
│   ├── main-rg.json                      # Compiled ARM resource group template
│   ├── uiFormDefinition.json             # Packaged Primary UI form definition (RG scope)
│   ├── uiFormDefinition.rg.json          # Packaged RG UI form definition
│   ├── uiFormDefinition.subscription.json# Packaged Subscription UI form definition
│   └── createUiDefinition.json           # Packaged Sandbox / Managed App UI definition
├── .gitignore
└── README.md                             # Repository documentation (this file)
```

---

## Deployment Options

### Option 1: Direct Portal Deployment (Deploy to Azure)
Click the [Deploy to Azure](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FmainTemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FuiFormDefinition.json) button at the top of this README.

1. Sign in to the Azure Portal.
2. Select your target **Subscription** and choose to **Create new** or **Use existing** Resource Group.
3. Configure the **Virtual Network** and dynamic subnets in Tab 2.
4. Optionally configure a **Virtual Machine** in Tab 3 (disabled by default in pilot mode).
5. Review settings and select **Create** in Tab 4.

### Option 2: Azure Template Specs (Form View)
Publish the compiled artifacts to an Azure Template Spec:
```bash
az ts create \
  --name "elrehan-infrastructure-wizard" \
  --version "1.2.0" \
  --resource-group "rg-elrehan-templates" \
  --location "westeurope" \
  --template-file "dist/main-rg.json" \
  --ui-form-definition "dist/uiFormDefinition.json" \
  --yes
```
Deploy via the Azure Portal Template Specs blade to experience the Form View wizard.

### Option 3: Local CLI Deployment (Bicep)
Deploy directly via Azure CLI:
```bash
az deployment group create \
  --resource-group "rg-elrehan-demo" \
  --template-file "main-rg.bicep" \
  --parameters @main.bicepparam
```

---

## Local Build & QA Verification Suite

### 1. Build Artifacts
```bash
./scripts/build.sh
```
Compiles Bicep sources to ARM JSON, synchronizes `dist/` and `portal/`, and performs secret scanning.

### 2. Run Comprehensive QA Verification
```bash
./scripts/validate.sh
```
Runs the 30-point verification suite:
* Bicep compilation (clean, 0 warnings across all 5 files).
* ARM JSON schema scope validation.
* UI Form Definition official schema compliance (`2021-09-09`).
* Parameter mapping completeness (100% aligned).
* Security audit (zero hardcoded secrets, separate `@secure()` parameters).
* Deterministic network validation (8/8 test cases).
* ARM simulation suite (9/9 positive and negative test cases).
* Deploy to Azure portal artifacts integrity.

---

## Security & Billing Safety Guarantee

* **Zero billable compute by default:** `deployVm` defaults to `false`. Network-only deployment occurs unless explicitly opted in.
* **Zero credentials stored:** All credentials default to empty strings; zero secrets in Git or distribution templates.
* **Pre-flight failure guards:** Missing credentials or unmatched subnets trigger immediate pre-flight deployment errors via `fail()` rather than silent redirection or silent skipping.
