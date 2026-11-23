# Azure Portal Publishing & Manual Deployment Guide

**Project:** Elrehan Azure Deployment Wizard — Sprint 1.1 Release Candidate  
**Compliance Note:** This solution enforces strict workstation isolation. No automated Azure login, credential storage, or remote deployments are triggered from the workstation. All publishing actions are manual and executed at the discretion of the Azure operator.

---

## 1. Prerequisites

1. Azure CLI (`az`) installed on your workstation or available in Azure Cloud Shell (`https://shell.azure.com`).
2. An active Azure subscription with permissions to create Template Specs (`Microsoft.Resources/templateSpecs/write`) and deploy resources (`Contributor` role).
3. The compiled artifacts generated in `dist/` (via `./scripts/build.sh`).

---

## 2. Method 1: Publishing as an Azure Template Spec (Primary Target)

### Step 1: Authenticate and Set Target Subscription

```bash
az login
az account show --output table
```

If multiple subscriptions are present, select your target subscription:

```bash
az account set --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>"
```

### Step 2: Create Template Spec Storage Resource Group

Template Specs reside in a storage Resource Group:

```bash
az group create \
  --name "rg-elrehan-templates" \
  --location "westeurope" \
  --tags Environment="Platform" Project="Elrehan Wizard"
```

### Step 3: Publish the Template Spec with the Form View

Run `az ts create` pairing the Resource Group-scoped ARM template with the primary UI Form Definition:

```bash
az ts create \
  --resource-group "rg-elrehan-templates" \
  --name "elrehan-infrastructure-wizard" \
  --version "1.1.0" \
  --location "westeurope" \
  --display-name "Elrehan Infrastructure Deployment Wizard" \
  --description "Enterprise multi-step guided deployment wizard for VNets, subnets, and compute." \
  --template-file "dist/main-rg.json" \
  --ui-form-definition "dist/uiFormDefinition.json" \
  --yes
```

> [!TIP]
> You can also run the helper script `./scripts/publish-template-spec.sh` to preview these commands in dry-run mode.

### Step 4: Launch the Wizard in Azure Portal

1. Open the Azure Portal: [https://portal.azure.com](https://portal.azure.com).
2. Search for **Template Specs** and select the service.
3. Click on **elrehan-infrastructure-wizard**.
4. In the left menu under **Versions**, select **1.1.0**.
5. Click **Deploy** in the top toolbar to launch the custom multi-step wizard!

---

## 3. Method 2: Zero-Deployment UI Preview via Azure Portal Sandbox

If you wish to test and interact with the UI wizard controls before publishing any Template Spec to Azure:

1. Open the official Azure Portal Sandbox:
   **[https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade](https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade)**
2. In the left editor pane, select and delete any existing placeholder JSON.
3. Open `dist/createUiDefinition.json` (or `ui/createUiDefinition.json`) and copy its entire contents.
4. Paste the JSON into the Sandbox editor pane.
5. Click **Preview** at the top.
6. The Azure Portal will instantly render the multi-step wizard:
   * Test the **Networking** step (add/remove subnets in `Microsoft.Common.EditableGrid`, test CIDR regex validation).
   * Test the **Virtual Machines** step (toggle OS to see Linux/Windows SizeSelectors, test conditional credentials).
   * Test the **Review** tab to inspect generated JSON parameter outputs.

---

## 4. Method 3: Subscription-Scoped Template Spec Variant

For organizations whose deployment policies mandate subscription-scope orchestration:

```bash
az ts create \
  --resource-group "rg-elrehan-templates" \
  --name "elrehan-infrastructure-wizard-sub" \
  --version "1.1.0" \
  --location "westeurope" \
  --display-name "Elrehan Infrastructure Wizard (Subscription Scope)" \
  --description "Subscription-scoped orchestrator variant with conditional Resource Group creation." \
  --template-file "dist/main.json" \
  --ui-form-definition "dist/uiFormDefinition.subscription.json" \
  --yes
```
