# Sprint 1.3 Engineering & MCP Integration Validation Report

**Project:** Azure Infrastructure Deployment Studio  
**Milestone:** Sprint 1.3 — Microsoft MCP Tooling Validation, Schema Verification & Architecture Baseline  
**Branch:** `sprint-1.3` (Work in progress, not merged into `main`)  
**Date:** November 2026  
**Status:** **PASSED — STOPPED AT LIVE AZURE PORTAL TESTING CHECKPOINT**

---

## 1. Executive Summary

Sprint 1.3 integrates and formally documents the verification of infrastructure definitions and Azure Portal user interface controls using the official **Microsoft Model Context Protocol (MCP)** toolsets:
1. **`bicep` MCP Server:** Bundled Bicep compiler schemas, best-practices engine, and compilation diagnostic tools.
2. **`microsoft-learn` MCP Server:** Direct semantic querying and documentation retrieval from official Microsoft Learn documentation.

All verifications were executed under strict read-only parameters without modifying reference repositories (`elrehan-azure-deployment-wizard`), without altering `main` branch directly, and without deploying billable Azure cloud resources.

---

## 2. Mandatory MCP Investigation & Findings Matrix

| Focus Area | MCP Server & Tool Invoked | Key Findings & Verified Capabilities | Architectural Impact & Guidance |
| :--- | :--- | :--- | :--- |
| **Azure Resource Schemas & API Versions** | `bicep`<br>`get_azure_resource_type_schema` | * Query: `Microsoft.Network/virtualNetworks`<br>* Returned Schema: `Microsoft.Network/virtualNetworks@2026-03-01` (with stable support `2024-05-01`).<br>* Scopes: Readable and writable at `ResourceGroup` scope.<br>* Supported child types: `subnets`, `virtualNetworkPeerings`.<br>* Verified definitions: `AddressSpace`, `Subnet`, `DhcpOptions`. | Confirms the project's use of `Microsoft.Network/virtualNetworks@2024-05-01` in `modules/network.bicep` conforms strictly to Azure Resource Manager contracts. |
| **Bicep Authoring Best Practices** | `bicep`<br>`get_bicep_best_practices` | * Avoid setting `name` on `module` statements where unneeded.<br>* Use User-Defined Types (UDT) for grouped inputs/outputs instead of open `object` or `array`.<br>* Do not reference child resources with `/` in names; use `parent` symbolic property.<br>* Always enforce `@secure()` on credentials.<br>* Avoid multiple `resourceId()` calls where symbolic names suffice.<br>* Use safe-dereferencing (`.?`) and coalesce (`??`). | Confirms existing architecture adheres to best practices: `modules/network.bicep` uses `type subnetType`, `@secure()` decorators on `adminPassword` and `adminSshPublicKey`, and symbolic module referencing. |
| **Portal Form View Controls & Selectors** | `microsoft-learn`<br>`microsoft_docs_search` | * Article: *"Elements supported in Form view"* (`azure-resource-manager/templates/form-view-elements`).<br>* Supported Controls: `Microsoft.Compute.SizeSelector`, `Microsoft.Network.VirtualNetworkCombo`, `Microsoft.Solutions.ResourceSelector`, `Microsoft.Solutions.ArmApiControl`, `Microsoft.Solutions.BladeInvokeControl`.<br>* ResourceSelector: Resource Graph-backed resource picker across subscriptions/resource groups (`resourceType`, `filter: onBasics/all`).<br>* VirtualNetworkCombo: Built-in selector supporting existing or new VNets and subnet mapping. | Proves native Form View capability exists for both `Microsoft.Solutions.ResourceSelector` and `Microsoft.Network.VirtualNetworkCombo` for dynamic Azure resource selection. |
| **Cross-RG Deployment & Existing References** | `microsoft-learn`<br>`microsoft_docs_search` | * Article: *"Reference existing resources in Bicep"* (`azure-resource-manager/bicep/existing-resource`).<br>* Syntax: `resource res '...' existing = { scope: resourceGroup(rgName) }` or `scope: resourceGroup(subId, rgName)`.<br>* Nested cross-RG module deployments: `module mod '...' = { scope: resourceGroup(...) }`.<br>* Subnet child references from existing VNets: `parent: existingVnet`. | Establishes the exact supported pattern for referencing existing resources across resource groups and subscriptions in Bicep without runtime failures. |
| **Bicep Compilation & Diagnostics** | `bicep`<br>`build_bicep` | * Source 1: `main-rg.bicep` -> Compiled successfully (`success: true`, 0 diagnostics, template generated).<br>* Source 2: `main.bicep` -> Compiled successfully (`success: true`, 0 diagnostics, template generated). | Validates that all Bicep sources compile cleanly into standard ARM template definitions without relying on experimental compiler flags. |

---

## 3. Automated Verification & Quality Assurance Suite

All automated tests in `scripts/validate.sh` were executed on the active `sprint-1.3` branch.

### Test Results Breakdown (30/30 Checks Passed)
1. **Bicep Compilation (5/5 PASS):** `main.bicep`, `main-rg.bicep`, `modules/network.bicep`, `modules/compute.bicep`, `modules/nsg.bicep` compiled with exit code 0 and zero warnings.
2. **ARM Template Scope Integrity (2/2 PASS):** `dist/main.json` matches `subscriptionDeploymentTemplate.json`; `dist/main-rg.json` matches `deploymentTemplate.json`.
3. **Official UI Schema Compliance (3/3 PASS):** `uiFormDefinition.json`, `uiFormDefinition.rg.json`, `uiFormDefinition.subscription.json` validated against official Microsoft schema `2021-09-09`.
4. **UI Output-to-ARM Parameter Mapping (2/2 PASS):** 0 unmatched UI outputs and 0 missing mandatory parameters across Resource Group and Subscription scopes.
5. **Security & Credentials Audit (2/2 PASS):** Zero mock keys, zero hardcoded passwords, separate `@secure()` parameters, explicit `fail()` guard present, ECDSA rejected.
6. **VM Subnet Validation (1/1 PASS):** Silent fallback to `subnets[0].name` removed; explicit `fail()` guard on invalid subnet placement.
7. **Network Calculation Engine (2/2 PASS):** Bicep duplicate name guard active; 8/8 network math test cases passed deterministically (`scripts/network_validator.py`).
8. **Tags Normalization (1/1 PASS):** `effectiveTags` normalization present in both orchestrators.
9. **Deterministic ARM Evaluation Simulation Suite (9/9 PASS):**
   * Baseline (`deployVm=false`): Valid (network only)
   * Negative (missing SSH key): Rejected
   * Negative (unsupported ECDSA key): Rejected
   * Negative (short password <12 chars): Rejected
   * Negative (nonexistent subnet selection): Rejected
   * Negative (duplicate subnet names): Rejected
   * Positive (RSA key + valid subnet): Accepted
   * Positive (ED25519 key + valid subnet): Accepted
   * Positive (16-char password + valid subnet): Accepted
10. **Baseline Parameter Security (1/1 PASS):** `main.bicepparam` verified with `deployVm = false` and 0 secrets.
11. **Distribution Packaging Completeness (1/1 PASS):** All 6 artifacts present in `dist/`.
12. **Deploy to Azure Portal Artifacts Integrity (1/1 PASS):** `portal/mainTemplate.json` and `portal/uiFormDefinition.json` verified.

---

## 4. Architectural Rules Compliance

- [x] **Reuse Approved Architecture:** Maintained existing modular structure (`network.bicep`, `compute.bicep`, `nsg.bicep`, `main-rg.bicep`, `main.bicep`).
- [x] **Reference Repositories Untouched:** `/home/jana/Projects/elrehan-azure-deployment-wizard` remains completely unmodified on `sprint-1.2-remediation`.
- [x] **No Direct Main Modification / No Merge:** All work tracked on branch `sprint-1.3` in `/home/jana/Projects/azure-infrastructure-deployment-studio`.
- [x] **Zero Cloud Deployments:** No Azure subscriptions touched; no resources provisioned.
- [x] **Checkpoint Enforced:** Execution stopped at the live Azure Portal testing checkpoint.

---

## 5. Live Azure Portal Testing Checkpoint

As mandated by project constraints, the implementation is stopped at the **Live Azure Portal Testing Checkpoint**.

The project owner can execute the manual portal acceptance suite using the published direct button:
```
https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FmainTemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FElrehan-Academy%2Fazure-infrastructure-deployment-studio%2Fmain%2Fportal%2FuiFormDefinition.json
```
Refer to [`docs/portal-test-checklist.md`](file:///home/jana/Projects/azure-infrastructure-deployment-studio/docs/portal-test-checklist.md) for the complete acceptance testing procedure.
