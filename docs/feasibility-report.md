# Feasibility Report: Azure-Native Multi-Step Deployment Wizard

**Project:** Elrehan Azure Deployment Wizard — Sprint 1.1 Remediation & Release Candidate  
**Author:** Principal Azure Infrastructure Architect & ARM/Bicep Engineer  
**Date:** November 2026  
**Status:** Feasibility Verified & Approved for Release Candidate  

---

## 1. Executive Summary & Critical Portal Distinction

The objective of this pilot is to evaluate and implement a working proof-of-concept for an Azure-native, multi-step deployment wizard.

> [!IMPORTANT]
> **Custom Template Screen vs. Template Spec Form View:**  
> Standard ARM template upload through the Azure Portal's *"Deploy a custom template"* blade (`Microsoft.Template`) renders only an auto-generated, flat list of parameters. It **cannot** execute multi-step tabs, custom drop-downs, dynamic grids, or native sizing blades.  
> To experience the custom multi-step wizard, the solution must be deployed either:
> 1. As an **Azure Template Spec** packaged with `uiFormDefinition.json` via `az ts create`.
> 2. Within the **Azure Portal SandboxBlade** (`https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade`) using `createUiDefinition.json`.

Following comprehensive re-investigation in Sprint 1.1, the primary architecture is confirmed as **Azure Template Specs targeting Resource Group Scope** with `Microsoft.Common.ResourceScope` natively governing the subscription, resource group (New vs. Existing), and region.

---

## 2. Feasibility Matrix

| # | Evaluated Requirement | Target Technology | Feasibility Status | Implementation Detail |
|---|------------------------|-------------------|--------------------|-----------------------|
| **1** | Azure Template Specs with `uiFormDefinition.json` | Template Specs | **Fully Supported** | Form View schema `2021-09-09/uiFormDefinition.schema.json#`. Packaged via `az ts create --ui-form-definition`. |
| **2** | Azure Managed Applications with `createUiDefinition.json` | Managed Applications | **Fully Supported** | Legacy schema `0.1.2-preview`. Validated in Azure Portal SandboxBlade. |
| **3** | Multi-step UI support | Template Specs & Managed Apps | **Fully Supported** | Sequential wizard steps in `view.properties.steps`. Final "Review + create" tab is synthesized natively by the Azure Portal runtime. |
| **4** | Existing/New Resource Group selection | Template Specs | **Fully Supported** | `Microsoft.Common.ResourceScope` with `"resourceGroup": { "allowExisting": true }` provides the native radio toggle. Redundant manual toggles were eliminated in Sprint 1.1. |
| **5** | Dynamic Subscription and Region selection | Template Specs | **Fully Supported** | `Microsoft.Common.ResourceScope` renders cascaded subscription and region selectors filtered by `resourceProviders` (`Microsoft.Network`, `Microsoft.Compute`). |
| **6** | `Microsoft.Compute.SizeSelector` availability & compatibility | Template Specs & Managed Apps | **Fully Supported** | Native Azure VM SKU picker. Supported with dual conditional selectors (`vmSizeLinux` and `vmSizeWindows`) toggled by OS choice to resolve licensing pricing differences. |
| **7** | Dynamic Subnet configuration controls | Template Specs | **Partially Supported (Alternative Implemented)** | `Microsoft.Network.VirtualNetworkCombo` requires static keys. Supported alternative **`Microsoft.Common.EditableGrid`** implemented, providing dynamic row addition/deletion and IPv4 CIDR regex validation. |
| **8** | Subscription-scope deployment support | Template Specs | **Fully Supported** | `outputs.kind: "Subscription"` (`subscriptionScopeDeploymentContext`) maps directly to `targetScope = 'subscription'` in Bicep when using `ResourceGroupSelector`. |

---

## 3. Detailed Technical Analysis & Sprint 1.1 Updates

### 3.1. Resource Group Scope vs. Subscription Scope Trade-Off
In Sprint 1, an attempt was made to run a subscription-scoped deployment alongside a `ResourceScope` control and a secondary `rgModeOptions` OptionsGroup. This created an architectural conflict: `ResourceScope` already provides a native "Create new" / "Use existing" radio button in the portal blade, while `rgModeOptions` provided an independent toggle that could contradict user input.

**Sprint 1.1 Resolution:**
* **Primary Form View (`dist/uiFormDefinition.json`):** Configured with `outputs.kind: "ResourceGroup"`. `rgModeOptions` was removed. The Azure Portal handles creating the resource group if "Create new" is selected and deploys `main-rg.json` into that resource group.
* **Subscription Alternative (`dist/uiFormDefinition.subscription.json`):** Retained for organizations requiring subscription-level template spec deployments. It uses `Microsoft.Common.ResourceGroupSelector`, whose `.mode` property directly outputs `"New"` or `"Existing"`, mapping cleanly to `createNewResourceGroup: "[equals(steps('basics').resourceGroup.mode, 'New')]"` without any contradictory secondary toggle.

### 3.2. OS-Dependent SizeSelector Resolution
In official Azure documentation, `Microsoft.Compute.SizeSelector` requires a static `osPlatform` (`"Linux"` or `"Windows"`) to query hardware and licensing costs accurately. Passing a dynamic expression string to `osPlatform` is unsupported in portal execution.
**Sprint 1.1 Resolution:**
Implemented dual SizeSelectors:
* `vmSizeLinux`: Configured with `osPlatform: "Linux"`, visible when `osTypeOptions == 'Linux'`.
* `vmSizeWindows`: Configured with `osPlatform: "Windows"`, visible when `osTypeOptions == 'Windows'`.
* Output mapping: `vmSize = "[if(equals(steps('compute').osTypeOptions, 'Linux'), steps('compute').vmSizeLinux, steps('compute').vmSizeWindows)]"`.

### 3.3. Deterministic Network Validation
Interactive CIDR containment and overlap checks cannot be calculated inside Azure Portal JSON expression syntax.
**Sprint 1.1 Resolution:**
* Client-side Portal UI validates IPv4 CIDR syntax via regular expressions.
* Pre-flight and CI/CD validation executes `scripts/network_validator.py`, evaluating all 8 mandatory containment and overlap scenarios.
* At runtime, Azure Resource Manager's Network Resource Provider evaluates and enforces address space containment before resource allocation.
