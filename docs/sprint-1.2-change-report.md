# Sprint 1.2 Engineering Remediation & Final Verification Report

**Project:** Elrehan Azure Deployment Wizard  
**Milestone:** Sprint 1.2 — Final Engineering Corrections & Azure Portal Readiness  
**Author:** Senior Azure Infrastructure Architect, Bicep/ARM Engineer, Azure Portal UX Specialist & QA Engineer  
**Date:** November 2026  
**Status:** **RELEASE CANDIDATE READY FOR INDEPENDENT REVIEW**  

---

## 1. Executive Summary

Sprint 1.2 resolves all identified defects from Sprint 1.1 review, focusing on explicit deployment-time validation, security hardening, parameter mapping integrity, and Azure Resource Manager compatibility.

All silent failure fallbacks (silent suppression of VM deployment, silent fallback to default subnet) have been completely removed and replaced with deterministic, explicit pre-flight validation guards using native Bicep and ARM `fail()` evaluation logic. Resource tag mapping for `Microsoft.Common.TagsByResource` has been normalized to prevent runtime tagging failures in Azure Resource Manager.

The automated verification harness was expanded to **29 comprehensive checks**, including an 8-case deterministic network calculation suite and a 9-case ARM evaluation simulation suite. All **29 checks passed with 100% success**.

---

## 2. Remediation Matrix & Defect Tracking

| Defect ID | Severity | Defect Description | Remediation Implemented | Affected Files | Verification Evidence |
|---|---|---|---|---|---|
| **DEF-1.2-01** | **HIGH** | Silent VM deployment suppression (`shouldDeployVm = deployVm && hasValidAuth`) when credentials are missing or invalid. | Replaced silent suppression with explicit `fail()` validation guards. Provisioning is wired directly via `if (deployVm)`. If `deployVm` is true and credentials are missing/invalid, deployment fails with an explicit error. | `main.bicep`<br>`main-rg.bicep`<br>`modules/compute.bicep` | Automated simulation test: `deployVm=true` + missing auth rejected (`fail()`); `deployVm=false` succeeds without VM. |
| **DEF-1.2-02** | **HIGH** | Unsupported ECDSA SSH key allowed in UI and Bicep validation (`startsWith ecdsa-sha2-`), which Azure Linux VM provisioning rejects at runtime. | Removed ECDSA support from Bicep authentication checks and UI definitions. Strictly enforce OpenSSH RSA (`ssh-rsa`, min 2048-bit) and ED25519 (`ssh-ed25519`) keys supported by Azure VM agent. | `main.bicep`<br>`main-rg.bicep`<br>`modules/compute.bicep`<br>`ui/*.json` | Automated simulation test rejects ECDSA; UI regex and tooltips updated and validated against official schema. |
| **DEF-1.2-03** | **HIGH** | Silent VM subnet fallback: `targetSubnetName = contains(...) ? selectedSubnetName : subnets[0].name` silently changes requested subnet. | Removed silent fallback completely. Added explicit `fail()` guard: if `deployVm` is true and `selectedSubnetName` is empty or not in `subnets`, template fails explicitly. | `main.bicep`<br>`main-rg.bicep` | Automated simulation test: invalid subnet with `deployVm=true` rejected (`fail()`); valid subnet accepted. |
| **DEF-1.2-04** | **MEDIUM** | Runtime tag failure with `Microsoft.Common.TagsByResource` output format (`{"Microsoft.Resources/deployments": {...}}`) passed directly to ARM resource tags. | Added Bicep tag normalization: `var effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags`. Supports both nested Portal tags and flat CLI/bicepparam dictionaries. | `main.bicep`<br>`main-rg.bicep` | Bicep clean compilation; ARM JSON output inspection; parameter mapping verified. |
| **DEF-1.2-05** | **MEDIUM** | Lack of deployment-time duplicate subnet name detection in Bicep modules. | Added pre-flight duplicate subnet name validation guard in `modules/network.bicep` using `length(union(...)) != length(...)` and `fail()`. | `modules/network.bicep` | Bicep clean compilation; simulation test rejects duplicate subnet names. |
| **DEF-1.2-06** | **LOW** | Parameter and documentation version markers out of date with Sprint 1.2 milestone. | Updated `main.bicepparam` Sprint tag to `1.2`, refreshed build scripts, and updated all documentation. | `main.bicepparam`<br>`scripts/validate.sh`<br>`docs/*` | Parameter check in `scripts/validate.sh` passes with zero embedded secrets. |

---

## 3. Technical Implementation Details

### 3.1. Explicit Pre-Flight Validation Guards (`fail()`)
In Bicep v0.49.2, experimental `assert` statements require experimental compiler flags that generate non-standard `languageVersion: "2.1-experimental"` ARM schemas. To remain 100% compliant with standard Azure Resource Manager production deployment schemas (`2018-05-01` and `2019-04-01`), we implemented pre-flight validation using Bicep's native `fail()` function inside short-circuiting conditionals:

```bicep
// Explicit validation failure guards (no silent fallback or silent suppression)
var authCheck = deployVm ? (!hasValidAuth ? fail('VM deployment is enabled, but valid authentication credentials were not provided. Linux requires an RSA (ssh-rsa) or ED25519 (ssh-ed25519) SSH public key; Windows requires a password between 12 and 123 characters satisfying complexity requirements.') : true) : true
var subnetCheck = deployVm ? (!isSubnetValid ? fail('VM deployment is enabled, but the selected subnet "${selectedSubnetName}" does not match any configured subnet in the subnets array.') : true) : true
```

These compile to standard ARM expressions:
```json
"authCheck": "[if(parameters('deployVm'), if(not(variables('hasValidAuth')), fail('VM deployment is enabled, but valid authentication credentials were not provided...'), true()), true())]",
"subnetCheck": "[if(parameters('deployVm'), if(not(variables('isSubnetValid')), fail(format('VM deployment is enabled, but the selected subnet \"{0}\" does not match any configured subnet in the subnets array.', parameters('selectedSubnetName'))), true()), true())]"
```

Because `subnetId: (authCheck && subnetCheck) ? '${networkModule.outputs.vnetId}/subnets/${selectedSubnetName}' : ''` is passed to the compute module, the ARM evaluation engine deterministically validates credentials and subnet placement before provisioning compute resources.

### 3.2. Network Validation Enforcement: Local vs. Azure Resource Manager

| Network Rule | Enforced By | Local Test Evidence | Azure Resource Manager Error |
|---|---|---|---|
| **Subnet containment within VNet** | ARM Resource Provider (`Microsoft.Network`) & Python Validator | `TC-NET-02` (PASS) | `NetcfgInvalidSubnet: Subnet 'snet-x' does not fall within any of the address prefixes of the virtual network.` |
| **Overlapping subnets** | ARM Resource Provider (`Microsoft.Network`) & Python Validator | `TC-NET-03`, `TC-NET-04` (PASS) | `NetcfgInvalidSubnet: Subnet 'snet-x' overlaps with subnet 'snet-y'.` |
| **Duplicate subnet names** | Bicep Module Guard (`fail()`) & Python Validator | `TC-NET-05` (PASS) | Bicep / ARM `fail('Duplicate subnet names detected in subnets array.')` |
| **Invalid IPv4 octets (>255)** | UI Regex, Python Validator & ARM Provider | `TC-NET-06` (PASS) | UI regex blocks entry; ARM fails with `InvalidAddressPrefix` |
| **Non-canonical CIDR (host bits set)** | Python Validator & ARM Resource Provider | `TC-NET-07` (PASS) | `InvalidAddressPrefix: Subnet address prefix must be specified in CIDR notation and host bits must be zero.` |
| **Azure unsupported subnet sizes (/30, /31, /32)** | Python Validator & ARM Resource Provider | `TC-NET-08` (PASS) | `NetcfgInvalidSubnet: The minimum subnet size for IPv4 is /29.` (Azure reserves 5 IP addresses per subnet) |

### 3.3. Microsoft.Common.TagsByResource Normalization
Azure Portal's `Microsoft.Common.TagsByResource` outputs a dictionary keyed by resource type:
```json
{
  "Microsoft.Resources/deployments": {
    "Environment": "Pilot",
    "Project": "Elrehan"
  }
}
```
If assigned directly to an Azure resource's `tags` property, Azure Resource Manager throws a validation error because ARM tag values must be primitive strings.
In `main.bicep` and `main-rg.bicep`, we introduced:
```bicep
#disable-next-line use-safe-access
var effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags
```
This seamlessly unpacks nested tags from the Portal Form View while preserving flat key-value dictionaries supplied via `main.bicepparam` or CLI deployments.

---

## 4. Automated Verification Results

Execution command: `bash scripts/validate.sh`  
**Overall Result: 29/29 CHECKS PASSED (100% SUCCESS | 0 FAILED | 0 BLOCKED)**

1. **Bicep Compilation (5/5 PASS):** `main.bicep`, `main-rg.bicep`, `modules/network.bicep`, `modules/compute.bicep`, `modules/nsg.bicep` compile with exit code 0 and zero warnings.
2. **ARM Template Scope Integrity (2/2 PASS):** `dist/main.json` matches `subscriptionDeploymentTemplate.json`; `dist/main-rg.json` matches `deploymentTemplate.json`.
3. **Official UI Schema Compliance (3/3 PASS):** `uiFormDefinition.json`, `uiFormDefinition.rg.json`, `uiFormDefinition.subscription.json` validated against official Microsoft schema `2021-09-09`.
4. **UI Output-to-ARM Parameter Mapping (2/2 PASS):** 0 unmatched UI outputs and 0 missing mandatory parameters across both Resource Group and Subscription scopes.
5. **Security & Credentials Audit (2/2 PASS):** Zero mock keys, zero hardcoded passwords, separate `@secure()` parameters, silent suppression removed, explicit `fail()` guard present, ECDSA rejected.
6. **VM Subnet Validation (1/1 PASS):** Silent fallback to `subnets[0].name` removed; explicit `fail()` guard on invalid subnet placement.
7. **Network Validation & Duplicate Subnet Guard (2/2 PASS):** Bicep duplicate name guard active; 8/8 network math test cases passed deterministically.
8. **Tags Normalization (1/1 PASS):** `effectiveTags` normalization present in both orchestrators.
9. **ARM Evaluation Simulation Suite (9/9 PASS):**
   - Baseline (`deployVm=false`): Valid (network only)
   - Negative (missing SSH key): Rejected
   - Negative (unsupported ECDSA key): Rejected
   - Negative (short Windows password): Rejected
   - Negative (nonexistent subnet): Rejected
   - Negative (duplicate subnet names): Rejected
   - Positive (valid RSA SSH key): Valid
   - Positive (valid ED25519 SSH key): Valid
   - Positive (valid Windows password): Valid
10. **Baseline Parameter Verification (1/1 PASS):** `main.bicepparam` safe (`deployVm = false`, no secrets).
11. **Distribution Artifacts (1/1 PASS):** All 6 distribution files verified in `dist/`.

---

## 5. Deployment Safety Guarantee

The pilot configuration guarantees:
1. **Zero compute billing:** `deployVm = false` by default in all Bicep sources, parameter files, and UI definitions.
2. **Zero credentials at rest:** All passwords and SSH public keys default to empty strings; zero embedded credentials exist in Git or distribution artifacts.
3. **Zero unintended scope changes:** Resource Group creation is strictly conditioned on `createNewResourceGroup`.
4. **Safe operator publishing:** `scripts/publish-template-spec.sh` requires explicit user confirmation and operates in dry-run mode by default.
