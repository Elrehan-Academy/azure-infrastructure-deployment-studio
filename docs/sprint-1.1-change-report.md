# Sprint 1.1 Engineering Remediation & QA Change Report

**Project:** Elrehan Azure Deployment Wizard  
**Milestone:** Sprint 1.1 — Remediation, Verification & Release Candidate  
**Author:** Principal Azure Infrastructure Architect, Senior Bicep/ARM Engineer, Azure Portal UX Specialist, Security-focused QA Engineer  
**Date:** November 2026  
**Status:** **RELEASE CANDIDATE READY FOR REVIEW**  

---

## 1. Executive Summary

Sprint 1.1 addresses all architectural, security, network calculation, and UI consistency defects identified in the Sprint 1 pilot. Without disrupting the approved modular Bicep architecture or native Azure UX, focused engineering corrections were implemented, thoroughly verified locally, and compiled into a verified release candidate.

Key achievements in Sprint 1.1:
1. **Critical VM Authentication Remediation:** Removed all hardcoded credentials and mock keys. Implemented separate `@secure()` parameters for Windows password and Linux SSH public keys. Added an authentication guard preventing VM creation if credentials are missing or invalid. Default `deployVm` remains `false`.
2. **Resource Group Selection Reconciliation:** Eliminated the redundant and contradictory `rgModeOptions` toggle from the primary Form View. `Microsoft.Common.ResourceScope` natively governs new vs. existing Resource Group creation in the Azure Portal without race conditions or conflicting settings.
3. **Deterministic Network Validation Suite:** Implemented `scripts/network_validator.py` executing deterministic CIDR math across all 8 mandatory test cases (containment, overlaps, non-canonical prefixes, Azure prefix limits /8 to /29, and reserved subnets).
4. **Compute UX & Dual SizeSelector Implementation:** Resolved the fixed Linux platform limitation in `Microsoft.Compute.SizeSelector` by introducing conditionally visible Linux and Windows SizeSelectors with dynamic pricing calculations and safe fallback subnet binding.
5. **Enhanced QA Test Harness:** Expanded `scripts/validate.sh` from 12 checks to 19 rigorous automated tests covering Bicep compilation, ARM scope schemas, UI schema validation, parameter mappings, security scans, and network tests (19/19 PASSED).

---

## 2. Issue-by-Issue Remediation Table

| ID | Original Issue | Files Changed | Fix Implemented | Verification | Status |
|:---|:---|:---|:---|:---|:---|
| **SEC-01** | Hardcoded Windows administrator password fallback (`Elrehan#Pilot2026!`) | `modules/compute.bicep` | Removed hardcoded fallback completely. Enforced `adminPassword: isWindows ? adminPassword : null`. | Bicep compilation & secret scanner in `scripts/build.sh` | **RESOLVED** |
| **SEC-02** | Hardcoded Linux SSH public key placeholder (`pilot-mock-key`) | `modules/compute.bicep` | Removed placeholder variable. Enforced `keyData: adminSshPublicKey` with `disablePasswordAuthentication: true`. | Code inspection, regex scan in `scripts/validate.sh` | **RESOLVED** |
| **SEC-03** | Shared `adminPasswordOrKey` parameter for incompatible authentication methods | `modules/compute.bicep`, `main.bicep`, `main-rg.bicep`, `main.bicepparam`, UI definitions | Split into two distinct `@secure()` parameters: `adminPassword` and `adminSshPublicKey`. Windows cannot use SSH keys; Linux cannot use passwords. | Strict Bicep linter, UI parameter alignment matrix | **RESOLVED** |
| **SEC-04** | Missing authentication guard allowed VM deployment with empty credentials | `main.bicep`, `main-rg.bicep` | Implemented `hasValidAuth` check requiring valid OpenSSH key prefix for Linux or 12+ char password for Windows. `shouldDeployVm = deployVm && hasValidAuth`. | Automated logic test in `scripts/validate.sh` (Check 5) | **RESOLVED** |
| **SEC-05** | Baseline parameter file had secret references | `main.bicepparam` | Reset `adminPassword = ''` and `adminSshPublicKey = ''` with `deployVm = false`. | Automated secret pattern scanner in `scripts/validate.sh` (Check 8) | **RESOLVED** |
| **UX-01** | Redundant and contradictory `rgModeOptions` toggle in Basics step | `ui/uiFormDefinition.json`, `ui/uiFormDefinition.rg.json` | Removed `rgModeOptions` OptionsGroup. `Microsoft.Common.ResourceScope` natively governs New vs. Existing RG creation in Azure Portal. | Schema validation against official `2021-09-09` schema | **RESOLVED** |
| **UX-02** | `Microsoft.Compute.SizeSelector` fixed to Linux platform | `ui/uiFormDefinition.json`, `ui/uiFormDefinition.rg.json`, `ui/uiFormDefinition.subscription.json`, `ui/createUiDefinition.json` | Implemented dual conditional SizeSelectors (`vmSizeLinux` and `vmSizeWindows`) toggled by `osTypeOptions`. Selected size resolved dynamically in outputs. | Official schema validation & dynamic expression check | **RESOLVED** |
| **UX-03** | Free-text VM subnet field could point to non-existent subnet | `main.bicep`, `main-rg.bicep`, UI definitions | Added Bicep subnet resolution logic falling back safely to `subnets[0].name` if `selectedSubnetName` is invalid or unconfigured. | Bicep compilation & parameter resolution test | **RESOLVED** |
| **NET-01** | Network CIDR containment and overlap checks lacked deterministic verification | `scripts/network_validator.py`, `scripts/validate.sh` | Built deterministic Python validation engine implementing IPv4 math, subnet containment, overlap detection, canonical prefix checks, and /8-/29 limits. | 8/8 mandatory test cases executed and passed (Check 7) | **RESOLVED** |
| **NET-02** | Bicep subnet parameters lacked type safety and minimum length | `modules/network.bicep`, `main.bicep`, `main-rg.bicep` | Defined Bicep User-Defined Type `type subnetType` and added `@minLength(1)` constraints. | Clean Bicep compilation (0 warnings, 0 errors) | **RESOLVED** |
| **PUB-01** | Publishing helper lacked dry-run safety and confirmation controls | `scripts/publish-template-spec.sh` | Configured default DRY-RUN mode. Live execution requires explicit `--execute` flag and interactive `yes` confirmation prompt. | Script dry-run execution test | **RESOLVED** |

---

## 3. Scope and Architectural Decisions

1. **Primary Template Spec Scope (Resource Group Scope):**
   * **Decision:** The primary Template Spec deployment artifact ([`dist/uiFormDefinition.json`](file:///home/jana/Projects/elrehan-azure-deployment-wizard/dist/uiFormDefinition.json) paired with [`dist/main-rg.json`](file:///home/jana/Projects/elrehan-azure-deployment-wizard/dist/main-rg.json)) uses `outputs.kind: "ResourceGroup"`.
   * **Rationale:** In Azure Template Specs, `Microsoft.Common.ResourceScope` natively delegates Resource Group creation to the Azure Portal blade before template dispatch. This completely eliminates race conditions, avoids requiring subscription-level deployment write rights for consumers, and eliminates the contradictory `rgModeOptions` toggle.
2. **Subscription-Scope Alternative Retained:**
   * **Decision:** [`main.bicep`](file:///home/jana/Projects/elrehan-azure-deployment-wizard/main.bicep) (Subscription Scope orchestrator with conditional `resource targetResourceGroup = if (createNewResourceGroup)`) and [`ui/uiFormDefinition.subscription.json`](file:///home/jana/Projects/elrehan-azure-deployment-wizard/ui/uiFormDefinition.subscription.json) (using `Microsoft.Common.ResourceGroupSelector` with direct `mode` mapping) are preserved for enterprise landing zone CLI/pipeline deployments.
3. **VM Compute Provisioning Deferral:**
   * **Decision:** `deployVm` remains `false` by default. If `deployVm` is toggled to `true`, the Bicep template evaluates `hasValidAuth` before deploying `modules/compute.bicep`. This ensures that leaving authentication blank in pilot testing safely validates all UI inputs without deploying billable VM or NIC resources.

---

## 4. Local Verification Summary

* **Build Script:** `./scripts/build.sh` — PASSED (Compiles all Bicep sources to `dist/`, performs secret scanning).
* **Network Math Suite:** `python3 scripts/network_validator.py` — PASSED (8/8 test cases).
* **Validation Suite:** `./scripts/validate.sh` — PASSED (**19/19 checks passed, 0 failed, 0 blocked**).
