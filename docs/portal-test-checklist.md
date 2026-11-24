# Azure Portal Test Checklist: Project Owner Acceptance

**Project:** Elrehan Azure Infrastructure Deployment Studio — Sprint 1.3  
**Purpose:** Comprehensive acceptance verification checklist for the project owner to validate the 6-step enterprise wizard in the Azure Portal.  

---

## 1. Test Environment Details

* **Portal URL:** [https://portal.azure.com](https://portal.azure.com)
* **Architecture Scope:** 6-Step Enterprise Deployment Wizard (Basics, Networking, Security, Routing, Virtual Machines, Review)
* **Sandbox Alternative URL:** [https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade](https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade)

---

## 2. Portal Acceptance Tests (Requires Real Azure Portal)

The following tests require manual Azure Portal verification:

### 2.1. Wizard Layout & Step Progression
- [ ] **Tab Bar:** Displays sequential steps: `1. Basics` -> `2. Networking` -> `3. Security` -> `4. Routing` -> `5. Virtual Machines` -> `6. Review` -> `Review + create`.
- [ ] **Wizard Heading:** Displays "Elrehan Azure Infrastructure Deployment Studio".
- [ ] **Navigation Buttons:** Sequential "Next" and "Previous" navigation operates cleanly without clearing form state.

### 2.2. Step 1 — Basics
- [ ] **Subscription Selector:** Displays active Azure subscriptions where user holds contributor permissions.
- [ ] **Resource Group Native Control (`ResourceScope`):**
  - [ ] Supports both "Create new" and "Use existing".
  - [ ] If "Create new" selected: validates resource group naming constraints.
  - [ ] If "Use existing" selected: queries and displays existing resource groups in the chosen subscription.
- [ ] **Region Selector:** Displays Azure regions filtered to those supporting `Microsoft.Network` and `Microsoft.Compute`.
- [ ] **Tags Element:** Key-value tagging interface adds resource tags safely.
- [ ] **Cost Notice:** Displays clear InfoBox regarding standard cloud charges and default pilot safety mode.

### 2.3. Step 2 — Networking
- [ ] **VNet Deployment Mode OptionsGroup:**
  - [ ] Option 1: "Create new virtual network" (default).
  - [ ] Option 2: "Use existing virtual network (same or cross-resource group)".
- [ ] **Mode 1: Create New VNet:**
  - [ ] VNet Name input field pre-populated with `vnet-elrehan-pilot`.
  - [ ] Address Space input field pre-populated with `10.0.0.0/16`.
  - [ ] Dynamic Subnets Grid (`Microsoft.Common.EditableGrid`):
    - [ ] Allows adding and deleting subnet rows.
    - [ ] Enforces at least 1 subnet.
    - [ ] Column validation rejects non-CIDR strings or illegal characters.
- [ ] **Mode 2: Use Existing VNet:**
  - [ ] Displays existing VNet guidance InfoBox.
  - [ ] Input fields for Existing VNet Name, optional Existing VNet Resource Group (for cross-RG), and Existing Subnet Name.
  - [ ] "Deploy an additional subnet into this existing Virtual Network" toggle:
    - [ ] When checked, reveals fields for New Subnet Name and New Subnet Prefix.

### 2.4. Step 3 — Security
- [ ] **NSG Mode OptionsGroup:**
  - [ ] Option 1: "Create new NSG with enterprise secure defaults (Internal management only)" (default).
  - [ ] Option 2: "Associate existing NSG (same or cross-resource group)".
  - [ ] Option 3: "No NSG association (Unmanaged subnet security)".
- [ ] **New NSG Configuration:**
  - [ ] Displays New NSG Name (default `nsg-elrehan-pilot`).
  - [ ] Notice indicates SSH and RDP management traffic is restricted to `VirtualNetwork` internal ranges and never exposed directly to the public internet.
- [ ] **Existing NSG Configuration:**
  - [ ] When "Associate existing NSG" is selected, reveals Existing NSG Name and optional Existing NSG Resource Group.

### 2.5. Step 4 — Routing
- [ ] **Route Table Mode OptionsGroup:**
  - [ ] Option 1: "Create new Route Table" (default).
  - [ ] Option 2: "Associate existing Route Table (same or cross-resource group)".
  - [ ] Option 3: "No Route Table association (Default system routing)".
- [ ] **New Route Table Configuration:**
  - [ ] Displays Route Table Name (default `rt-elrehan-pilot`).
  - [ ] Displays "Disable BGP route propagation" checkbox.
- [ ] **Existing Route Table Configuration:**
  - [ ] When "Associate existing Route Table" is selected, reveals Existing Route Table Name and optional Existing Route Table Resource Group.

### 2.6. Step 5 — Virtual Machines
- [ ] **Pilot Safety Toggle ("Enable Virtual Machine Resource Deployment"):**
  - [ ] Unchecked by default.
  - [ ] Leaving unchecked provisions network and security controls without provisioning compute or NIC resources.
- [ ] **Operating System Selection:** DropDown displays Linux and Windows.
- [ ] **Dynamic Subnet Binding:** Target Subnet Name input allows targeting subnets defined in Step 2.
- [ ] **Credential Security:**
  - [ ] When unchecked, no credential fields are required or shown.
  - [ ] When Linux selected: displays SSH Public Key field (accepts `ssh-rsa` and `ssh-ed25519`).
  - [ ] When Windows selected: displays masked Administrator Password with 12-123 character complexity requirements.

### 2.7. Step 6 — Review & Submission
- [ ] **Deployment Summary:** Form View TextBlock displays architecture and scope summary.
- [ ] **Zero Credential Exposure:** Warning InfoBox confirms passwords and SSH keys remain masked and are never displayed in clear text.
- [ ] **Review + Create Native Validation:**
  - [ ] Displays green checkmark "Validation passed".
  - [ ] All 29 parameters are synthesized and passed cleanly to Azure Resource Manager.

---

## 3. Locally Verified Tests (Already Passed in QA Suite)

The automated validation suite (`scripts/validate.sh`) has already confirmed **38/38 checks passed**:

* [x] Zero Bicep linter warnings/errors across all 7 Bicep source files (`main.bicep`, `main-rg.bicep`, `modules/network.bicep`, `modules/compute.bicep`, `modules/nsg.bicep`, `modules/routeTable.bicep`, `modules/subnet.bicep`).
* [x] Schema validity of `main.json` (subscription scope) and `main-rg.json` (resource group scope).
* [x] Strict compliance of all UI definitions (`uiFormDefinition.json`, `uiFormDefinition.rg.json`, `uiFormDefinition.subscription.json`) against official schema `2021-09-09`.
* [x] 100% parameter alignment between UI Form View outputs and ARM template parameters (29 RG parameters, 31 Subscription parameters).
* [x] Zero hardcoded passwords, mock keys, or credentials across the codebase.
* [x] Separate `@secure()` parameters for Windows password and Linux SSH keys.
* [x] Elimination of silent VM deployment suppression and silent subnet fallback; explicit `fail()` guards present.
* [x] Duplicate subnet name validation guard in `modules/network.bicep`.
* [x] Tag normalization for `Microsoft.Common.TagsByResource` and flat dictionaries.
* [x] All 8 mandatory network CIDR math test cases passed (`scripts/network_validator.py`).
* [x] All 15 mandatory ARM evaluation simulation scenarios passed.
* [x] Baseline parameter security (`main.bicepparam`) verified.
* [x] All 6 distribution artifacts present in `dist/`.
* [x] Deploy to Azure portal artifacts in `portal/` verified.
