# Known Limitations and Recommended Next Steps

**Project:** Elrehan Azure Deployment Wizard — Sprint 1.2 Release Candidate  
**Author:** Azure Infrastructure Architecture Team  
**Date:** November 2026  

---

## 1. Known Platform & Architectural Limitations in Sprint 1.2

### 1.1. Custom Template Upload vs. Template Spec Portal Form
* **Limitation:** Uploading `main.json` or `main-rg.json` through the Azure Portal's generic *"Deploy a custom template"* screen (`Microsoft.Template`) **does not** execute `uiFormDefinition.json`. The generic custom template blade only renders a basic, flat list of parameters.
* **Workaround / Intended Usage:** The custom multi-step wizard is only displayed when:
  1. The template is published as an Azure Template Spec version via `az ts create --ui-form-definition` and deployed via the Template Specs service.
  2. The UI definition is loaded in the [Azure Portal Sandbox](https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade) using `createUiDefinition.json`.

### 1.2. Interactive CIDR Math in Portal Form Views
* **Limitation:** Azure Portal JSON expression functions (`steps()`, `basics()`, `concat()`, `if()`) do not possess an embedded IP subnet calculation engine. When a user enters `10.50.0.0/16`, the form cannot calculate child subnet boundaries dynamically or detect overlapping subnets interactively within the UI before form submission.
* **Mitigation:**
  * Syntax is validated interactively via regular expressions in the `EditableGrid`.
  * Pre-flight local checks enforce deterministic CIDR math across containment and overlap scenarios (`scripts/network_validator.py`).
  * In Bicep, duplicate subnet names are rejected pre-flight via `fail('Duplicate subnet names detected...')`.
  * Azure Resource Manager natively validates subnet containment within the VNet (`NetcfgInvalidSubnet`), non-overlapping CIDRs (`NetcfgInvalidSubnet`), non-canonical prefixes (`InvalidAddressPrefix`), and minimum subnet size /29 (`NetcfgInvalidSubnet`).

### 1.3. VM Sizing vs. Subscription Quota & Real-Time Capacity
* **Availability vs. Quota:** `Microsoft.Compute.SizeSelector` queries whether a VM SKU is offered in the selected region. It **cannot** evaluate:
  * Azure subscription vCPU quota limits (e.g. newly created subscriptions with a 0 vCPU limit on the Dv5 family).
  * Real-time regional hardware exhaustion or spot capacity spikes.
* **Mitigation in Pilot:**
  * `deployVm` defaults to `false`. Zero billable compute resources are created in default pilot mode.
  * Explicit validation guards (`fail()`) prevent VM provisioning if valid credentials or valid subnet selections are missing.

### 1.4. Cross-Step Dropdown Binding from EditableGrid
* **Limitation:** In the current Form View schema (`2021-09-09`), dynamically populating a `Microsoft.Common.DropDown` in Tab 3 (Compute) based on rows typed into the `EditableGrid` in Tab 2 (Networking) is unsupported due to the lack of array projection/mapping functions.
* **Mitigation:** Subnet selection uses a TextBox defaulting to `snet-workload`. In Sprint 1.2, silent fallback behavior has been eliminated: if `deployVm` is true and `selectedSubnetName` does not match any configured subnet in the subnets grid, Bicep / ARM executes an explicit `fail()` validation error with a descriptive message. Network placement is never silently redirected.

### 1.5. Azure Linux SSH Key Type Restrictions
* **Limitation:** Azure Linux VM provisioning officially supports only RSA (minimum 2048-bit, `ssh-rsa`) and ED25519 (`ssh-ed25519`) keys. ECDSA keys (`ecdsa-sha2-nistp256`) are rejected by the Azure Linux VM agent during provisioning.
* **Mitigation:** Sprint 1.2 updated the UI validation regex and Bicep authentication guards to strictly permit `ssh-rsa` and `ssh-ed25519`, preventing user submission of incompatible ECDSA keys.

---

## 2. Recommended Next Steps for Sprint 2

1. **Secrets & Identity Integration:**
   * Integrate Azure Key Vault secret references (`Microsoft.KeyVault.KeyVaultCertificateSelector` or existing Key Vault secret parameter) to avoid manual password entry in the UI.
   * Add Managed Identity assignment options (System-Assigned / User-Assigned) for virtual machines.

2. **Network Security & Routing Expansion:**
   * Expand `modules/nsg.bicep` to support user-configured security rules defined via an NSG `EditableGrid`.
   * Add an optional Azure Bastion Host or NAT Gateway provisioning toggle.

3. **Enterprise CI/CD Automation:**
   * Implement a GitHub Actions / Azure DevOps workflow running `./scripts/build.sh` and `./scripts/validate.sh` on pull requests, with an automated release stage executing `az ts create` on release tags.
