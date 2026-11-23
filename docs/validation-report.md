# Validation Report: Automated QA Test Suite Results

**Project:** Elrehan Azure Deployment Wizard — Sprint 1.2 Release Candidate  
**Date:** November 2026  
**Test Suite:** `scripts/validate.sh`, `scripts/network_validator.py`, and ARM Evaluation Simulation Engine  
**Execution Environment:** Linux x86_64, Azure CLI 2.92.0, Bicep CLI v0.49.2, Python 3.12  
**Result:** **30/30 CHECKS PASSED (100% SUCCESS | 0 FAILED | 0 BLOCKED)**  

---

## 1. Summary of QA Test Results

| Test Area | Check Description | Scope / Target | Expected Behavior | Actual Outcome | Status |
|---|---|---|---|---|---|
| **Bicep Compilation** | Compile `main.bicep` | Subscription Scope Orchestrator | Exit code 0, 0 linter warnings | Exit code 0, clean compilation | **PASS** |
| **Bicep Compilation** | Compile `main-rg.bicep` | Resource Group Scope Orchestrator | Exit code 0, 0 linter warnings | Exit code 0, clean compilation | **PASS** |
| **Bicep Compilation** | Compile `modules/network.bicep` | VNet & Subnet Modular Component | Exit code 0, 0 linter warnings | Exit code 0, clean compilation | **PASS** |
| **Bicep Compilation** | Compile `modules/compute.bicep` | VM & NIC Modular Component | Exit code 0, 0 linter warnings | Exit code 0, clean compilation | **PASS** |
| **Bicep Compilation** | Compile `modules/nsg.bicep` | Network Security Group Component | Exit code 0, 0 linter warnings | Exit code 0, clean compilation | **PASS** |
| **ARM Schema Scope** | Schema scope of `dist/main.json` | Subscription ARM Template | Schema matches `subscriptionDeploymentTemplate.json` | Valid schema, 15 parameters | **PASS** |
| **ARM Schema Scope** | Schema scope of `dist/main-rg.json` | Resource Group ARM Template | Schema matches `deploymentTemplate.json` | Valid schema, 13 parameters | **PASS** |
| **UI Schema Compliance** | Validate `dist/uiFormDefinition.json` | Official Schema `2021-09-09` | Schema validation passes without errors | Validation passed | **PASS** |
| **UI Schema Compliance** | Validate `dist/uiFormDefinition.rg.json` | Official Schema `2021-09-09` | Schema validation passes without errors | Validation passed | **PASS** |
| **UI Schema Compliance** | Validate `dist/uiFormDefinition.subscription.json` | Official Schema `2021-09-09` | Schema validation passes without errors | Validation passed | **PASS** |
| **Parameter Mapping** | UI Outputs to `main-rg.json` (RG Scope) | Template Spec Primary Target | 0 unmatched UI keys, 0 missing mandatory | Unmatched: 0, Missing: 0 (13/13 mapped) | **PASS** |
| **Parameter Mapping** | UI Outputs to `main.json` (Subscription Scope) | Subscription Alternative Target | 0 unmatched UI keys, 0 missing mandatory | Unmatched: 0, Missing: 0 (15/15 mapped) | **PASS** |
| **Security & Auth** | VM Credentials in `modules/compute.bicep` | Security Audit | No mock keys, no hardcoded passwords, separate `@secure()` | MockKey=False, HardcodedPass=False, SeparateSecure=True, ComputeFail=True | **PASS** |
| **Security & Auth** | Silent VM Suppression Removal & `fail()` Guard | Infrastructure Safety | `shouldDeployVm` removed, `deployVm` defaults to `false`, explicit `fail()` guard | Silent suppression removed, `fail()` guard active, ECDSA rejected | **PASS** |
| **Subnet Placement** | Silent VM Subnet Fallback Removal & `fail()` Guard | Network Placement Safety | Silent fallback removed; explicit `fail()` if requested subnet not found | Fallback removed; explicit `fail()` guard active | **PASS** |
| **Network Guard** | Duplicate subnet name guard in `modules/network.bicep` | Pre-flight Network Guard | Uniqueness evaluated; fails if duplicate subnet names configured | Duplicate guard active via `fail()` | **PASS** |
| **Network Math** | Deterministic Network Validation Engine | 8 Mandatory Test Cases | All 8 test cases pass exact expected outcomes | 8/8 test cases passed | **PASS** |
| **Tags Mapping** | Resource tag normalization (`TagsByResource`) | Tagging Contract | Unpacks nested `TagsByResource` object or preserves flat dictionary | Normalization active in both orchestrators | **PASS** |
| **ARM Simulation** | Baseline: `deployVm = false` (network only) | ARM Evaluation Engine | Valid configuration, zero compute resources | Valid=True, Errors=[] | **PASS** |
| **ARM Simulation** | Negative: `deployVm = true` + missing SSH key | ARM Evaluation Engine | Explicit validation failure via `fail()` | Valid=False, Error: missing credentials | **PASS** |
| **ARM Simulation** | Negative: `deployVm = true` + unsupported ECDSA key | ARM Evaluation Engine | Explicit validation failure via `fail()` | Valid=False, Error: unsupported key | **PASS** |
| **ARM Simulation** | Negative: `deployVm = true` + short Windows password | ARM Evaluation Engine | Explicit validation failure via `fail()` | Valid=False, Error: password complexity | **PASS** |
| **ARM Simulation** | Negative: `deployVm = true` + bad subnet selection | ARM Evaluation Engine | Explicit validation failure via `fail()` | Valid=False, Error: unmatched subnet | **PASS** |
| **ARM Simulation** | Negative: duplicate subnet names in configuration | ARM Evaluation Engine | Explicit validation failure via `fail()` | Valid=False, Error: duplicate names | **PASS** |
| **ARM Simulation** | Positive: `deployVm = true` + valid RSA SSH key | ARM Evaluation Engine | Valid configuration, compute provisioned | Valid=True, Errors=[] | **PASS** |
| **ARM Simulation** | Positive: `deployVm = true` + valid ED25519 SSH key | ARM Evaluation Engine | Valid configuration, compute provisioned | Valid=True, Errors=[] | **PASS** |
| **ARM Simulation** | Positive: `deployVm = true` + valid Windows password | ARM Evaluation Engine | Valid configuration, compute provisioned | Valid=True, Errors=[] | **PASS** |
| **Baseline Parameters** | Security check on `main.bicepparam` | Parameter Audit | `deployVm = false` and no embedded secrets | `deployVm = false`, zero secrets found | **PASS** |
| **Packaging** | Distribution Artifacts in `dist/` | Build Inventory | All 6 required artifacts present in `dist/` | Present: 6/6 artifacts verified | **PASS** |
| **Deploy to Azure** | Portal Artifacts in `portal/` | Deploy to Azure Integrity | `mainTemplate.json` & `uiFormDefinition.json` present and contract-compliant | Present: 2/2 artifacts verified, RG scope contract | **PASS** |

---

## 2. Network Calculation Test Results (8 Mandatory Cases)

Executed deterministically via `scripts/network_validator.py` using Python's standard `ipaddress` library:

1. **TC-NET-01: Standard valid subnet containment**
   * Input: VNet `10.20.0.0/16`, subnet `10.20.1.0/24`
   * Expected: **Accept** | Actual: **Accepted** | Status: **PASS**
2. **TC-NET-02: Subnet outside VNet address space**
   * Input: VNet `10.20.0.0/16`, subnet `10.21.1.0/24`
   * Expected: **Reject** | Actual: **Rejected** (`Subnet 'snet-workload' (10.21.1.0/24) is not contained within VNet address space 10.20.0.0/16`) | Status: **PASS**
3. **TC-NET-03: Two identical subnet CIDRs**
   * Input: VNet `10.20.0.0/16`, subnets `10.20.1.0/24` and `10.20.1.0/24`
   * Expected: **Reject** | Actual: **Rejected** (`Subnet 'snet-2' (10.20.1.0/24) overlaps with subnet 'snet-1' (10.20.1.0/24)`) | Status: **PASS**
4. **TC-NET-04: Two partially overlapping subnets**
   * Input: VNet `10.20.0.0/16`, subnets `10.20.0.0/24` and `10.20.0.128/25`
   * Expected: **Reject** | Actual: **Rejected** (`Subnet 'snet-child' (10.20.0.128/25) overlaps with subnet 'snet-parent' (10.20.0.0/24)`) | Status: **PASS**
5. **TC-NET-05: Duplicate subnet names**
   * Input: VNet `10.20.0.0/16`, subnets `snet-dup` (10.20.1.0/24) and `snet-dup` (10.20.2.0/24)
   * Expected: **Reject** | Actual: **Rejected** (`Duplicate subnet name detected: 'snet-dup'`) | Status: **PASS**
6. **TC-NET-06: Invalid IPv4 octet (> 255)**
   * Input: VNet `10.256.0.0/16`, subnet `10.256.1.0/24`
   * Expected: **Reject** | Actual: **Rejected** (`Octet 256 (> 255) not permitted in '10.256.0.0'`) | Status: **PASS**
7. **TC-NET-07: Noncanonical network prefix (host bits set)**
   * Input: VNet `10.20.0.0/16`, subnet `10.20.1.5/24`
   * Expected: **Reject** | Actual: **Rejected** (`Subnet 'snet-1' prefix '10.20.1.5/24' is non-canonical (host bits are set)`) | Status: **PASS**
8. **TC-NET-08: Azure-unsupported subnet prefix (/30)**
   * Input: VNet `10.20.0.0/16`, subnet `10.20.1.0/30`
   * Expected: **Reject** | Actual: **Rejected** (`Subnet 'snet-1' prefix /30 is unsupported by Azure. Azure subnets must be between /8 and /29`) | Status: **PASS**

---

## 3. UI Output-to-ARM Parameter Mapping Matrix

### 3.1. Primary Target: Resource Group Scope (`dist/uiFormDefinition.json` to `dist/main-rg.json`)

| UI Form View Output Key | Form View Expression | Target ARM Parameter | Parameter Type | Mandatory / Default |
|---|---|---|---|---|
| `location` | `[steps('basics').resourceScope.location.name]` | `location` | `string` | Mandatory |
| `tags` | `[steps('basics').tags]` | `tags` | `object` | Default: `{}` |
| `vnetName` | `[steps('networking').vnetName]` | `vnetName` | `string` | Default: `vnet-elrehan-pilot` |
| `addressPrefix` | `[steps('networking').addressPrefix]` | `addressPrefix` | `string` | Default: `10.0.0.0/16` |
| `subnets` | `[steps('networking').subnetsGrid]` | `subnets` | `array` (`subnetType[]`) | Default configured |
| `deployVm` | `[steps('compute').deployVmToggle]` | `deployVm` | `bool` | Default: `false` |
| `osType` | `[steps('compute').osTypeOptions]` | `osType` | `string` | Default: `Linux` |
| `vmName` | `[steps('compute').vmName]` | `vmName` | `string` | Default: `vm-elrehan-pilot-01` |
| `vmSize` | `[if(equals(...), steps('compute').vmSizeLinux, steps('compute').vmSizeWindows)]` | `vmSize` | `string` | Default: `Standard_D2s_v5` |
| `selectedSubnetName` | `[steps('compute').selectedSubnetName]` | `selectedSubnetName` | `string` | Default: `snet-workload` |
| `adminUsername` | `[steps('compute').adminUsername]` | `adminUsername` | `string` | Default: `azureuser` |
| `adminPassword` | `[if(...), steps('compute').adminPassword, '')]` | `adminPassword` | `securestring` | Default: `''` |
| `adminSshPublicKey` | `[if(...), steps('compute').adminSshPublicKey, '')]` | `adminSshPublicKey` | `securestring` | Default: `''` |

*Unmatched UI Keys:* **0** | *Missing Mandatory ARM Parameters:* **0**

---

## 4. Distribution Artifacts Verified

1. `dist/main.json` (24.3 KB) — ARM Subscription Scope Template
2. `dist/main-rg.json` (23.3 KB) — ARM Resource Group Scope Template
3. `dist/uiFormDefinition.json` (12.1 KB) — Primary Template Spec Form View (RG Scope)
4. `dist/uiFormDefinition.rg.json` (11.0 KB) — Resource Group Form View Variant
5. `dist/uiFormDefinition.subscription.json` (12.2 KB) — Subscription Scope Form View
6. `dist/createUiDefinition.json` (9.2 KB) — Azure Portal Sandbox UI Definition
