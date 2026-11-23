# Azure Portal Test Checklist: Project Owner Acceptance

**Project:** Elrehan Azure Deployment Wizard — Sprint 1.2 Release Candidate  
**Purpose:** Comprehensive acceptance verification checklist for the project owner to validate the wizard experience in the Azure Portal.  

---

## 1. Test Environment Details

* **Portal URL:** [https://portal.azure.com](https://portal.azure.com)
* **Template Spec:** `elrehan-infrastructure-wizard` (Version: `1.2.0`)
* **Sandbox Alternative URL:** [https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade](https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade)

---

## 2. Portal Acceptance Tests (Requires Real Azure Portal)

The following tests cannot be verified in a local terminal and require manual Azure Portal testing:

### 2.1. Wizard Layout & Navigation
- [ ] **Tab Bar:** Displays sequential tabs: `Basics` -> `Networking` -> `Virtual Machines` -> `Review + create`.
- [ ] **Wizard Heading:** Displays "Elrehan Azure Infrastructure Deployment Wizard".
- [ ] **Navigation Buttons:** "Next: Networking >", "Next: Virtual Machines >", and "Previous" navigate smoothly without losing state.

### 2.2. Tab 1 — Basics
- [ ] **Subscription Selector:** Displays the active Azure subscription dropdown dynamically querying user RBAC permissions.
- [ ] **Resource Group Native Control:**
  - [ ] Renders the native radio selector: "Create new" / "Use existing".
  - [ ] If "Create new" is selected: user can enter a new RG name (e.g. `rg-elrehan-test-portal`).
  - [ ] If "Use existing" is selected: a dropdown displays existing resource groups in the chosen subscription.
  - [ ] **Zero Redundancy:** Confirm there is **no secondary or contradictory** RG provisioning toggle on the page.
- [ ] **Region Selector:** Displays Azure regions filtered to those supporting `Microsoft.Network` and `Microsoft.Compute`.
- [ ] **No Duplicate Region Field:** Only a single region input exists in the ResourceScope control.
- [ ] **Tags Element:** Key-value tagging interface allows adding optional tags. Tags are normalized and assigned cleanly to resources without runtime failure.

### 2.3. Tab 2 — Networking
- [ ] **VNet Name Input:**
  - [ ] Pre-populated with default `vnet-elrehan-pilot`.
  - [ ] Entering invalid characters (e.g., spaces or `@#$`) displays regex validation error.
- [ ] **VNet CIDR Input:**
  - [ ] Pre-populated with `10.0.0.0/16`.
  - [ ] Entering invalid notation (e.g. `10.0.0.0` without slash or `999.0.0.1/24`) displays regex validation error.
- [ ] **EditableGrid (Dynamic Subnets):**
  - [ ] Table renders with columns: **Subnet Name** and **Subnet CIDR Prefix**.
  - [ ] **Add Row:** Clicking "+ Add" or "+ Add row" inserts a new row.
  - [ ] **Delete Row:** Deleting a row functions properly and updates row count.
  - [ ] **Row Constraints:** Grid prevents deleting all rows (minimum 1 row required).
  - [ ] **Column Regex Validation:**
    - Subnet name validates alphanumeric characters, hyphens, and underscores.
    - Subnet CIDR validates correct IPv4 notation (e.g., `10.0.1.0/24`).

### 2.4. Tab 3 — Virtual Machines
- [ ] **Pilot Safety Toggle ("Enable Virtual Machine Resource Deployment"):**
  - [ ] Checkbox is **unchecked by default**.
  - [ ] Tooltip clarifies that leaving it unchecked validates inputs without deploying compute resources.
- [ ] **Operating System Selection:** OptionsGroup displays "Linux (Ubuntu Server 22.04 LTS)" and "Windows Server (2022 Datacenter)".
- [ ] **Dual SizeSelector & OS Licensing Behavior:**
  - [ ] When **Linux** is selected: Displays `vmSizeLinux` with Linux recommended sizes and Linux software costs.
  - [ ] When **Windows** is selected: Automatically displays `vmSizeWindows` with Windows recommended sizes and Windows software costs.
  - [ ] Clicking **"Change size"** opens the native Azure VM SKU selector modal blade showing real-time vCPU, RAM, IOPS, and hourly cost estimates for the selected region.
- [ ] **Target Subnet Name:** Input field allows targeting a configured subnet (defaults to `snet-workload`).
  - [ ] When `deployVm` is enabled and an invalid/unmatched subnet is entered, deployment explicitly fails with a descriptive error (no silent fallback).
- [ ] **Conditional Credential Fields:**
  - [ ] When `deployVmToggle` is **unchecked**: No password or SSH key input fields are required or shown.
  - [ ] When `deployVmToggle` is **checked** and **Linux** is selected: Displays `SSH Public Key (Linux)` input box with OpenSSH regex validation (strictly allows `ssh-rsa` and `ssh-ed25519`; rejects `ecdsa`).
  - [ ] When `deployVmToggle` is **checked** and **Windows** is selected: Displays masked `Administrator Password (Windows)` and `Confirm Password` boxes with 12-123 character complexity validation.

### 2.5. Tab 4 — Review + Create
- [ ] **Client-Side Validation Check:** The wizard executes full validation across all preceding steps. Green checkmark "Validation passed" is displayed.
- [ ] **Summary Review:** All selected inputs (Subscription, Resource Group, Region, VNet, Subnets array, VM SKU, OS Type) are summarized.
- [ ] **Pricing Estimation:** Estimated compute cost breakdown is displayed.
- [ ] **Deployment Execution:** The **"Create"** button is enabled and triggers deployment.
  - If "Create new" RG was selected: Azure Portal creates the Resource Group first, then deploys `main-rg.json`.
  - If `deployVm` remained unchecked: Only the Virtual Network and Subnets are created. No VM or NIC is created.

---

## 3. Locally Verified Tests (Already Passed in QA Suite)

For reference, the following items were already validated deterministically by `./scripts/validate.sh`, `./scripts/network_validator.py`, and the ARM evaluation simulation suite (**29/29 checks passed**):

* [x] Zero Bicep linter warnings/errors across all 5 Bicep source files.
* [x] Schema validity of `main.json` (subscription scope) and `main-rg.json` (resource group scope).
* [x] Strict compliance of UI definitions against Microsoft schema `2021-09-09`.
* [x] 100% parameter alignment between UI Form View outputs and ARM template parameters.
* [x] Zero hardcoded passwords, mock keys, or credentials across the entire codebase.
* [x] Separate `@secure()` parameters for Windows password and Linux SSH keys.
* [x] Elimination of silent VM deployment suppression; explicit `fail()` validation on missing/invalid credentials.
* [x] Elimination of silent VM subnet fallback; explicit `fail()` validation when requested subnet is not in configured subnets.
* [x] Duplicate subnet name validation guard in `modules/network.bicep`.
* [x] Tag normalization for `Microsoft.Common.TagsByResource` and flat dictionaries.
* [x] All 8 mandatory network CIDR math test cases (containment, overlaps, /8 to /29 limits, reserved subnets).
* [x] All 9 deterministic ARM evaluation simulation cases.
* [x] Default `deployVm = false` in Bicep sources, parameter files, and UI definitions.
* [x] All 6 distribution artifacts present in `dist/`.

---

## 4. Acceptance Sign-Off

| Milestone | Verified By | Date | Signature / Status |
|---|---|---|---|
| Local Build, Linting & QA Suite | Engineering Team | Nov 2026 | **PASSED (29/29)** |
| Azure Portal Multi-Step UX Pilot | Project Owner | ____________ | __________________ |
