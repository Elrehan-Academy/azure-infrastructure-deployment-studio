#!/usr/bin/env bash
# ==============================================================================
# Elrehan Azure Deployment Wizard - Manual Template Spec Publishing Helper
# Previews and provides manual instructions to publish to Azure Template Specs
# Execution Rule: Does NOT perform automated deployments or subscription changes
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"

DEFAULT_RG="rg-elrehan-templates"
DEFAULT_NAME="elrehan-infrastructure-wizard"
DEFAULT_VERSION="1.1.0"
DEFAULT_LOCATION="westeurope"

TARGET_RG="${DEFAULT_RG}"
TS_NAME="${DEFAULT_NAME}"
TS_VERSION="${DEFAULT_VERSION}"
TS_LOCATION="${DEFAULT_LOCATION}"
EXECUTE=false

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -g, --resource-group <name>   Target Resource Group for Template Spec storage (default: ${DEFAULT_RG})
  -n, --name <name>             Template Spec name (default: ${DEFAULT_NAME})
  -v, --version <version>       Template Spec version (default: ${DEFAULT_VERSION})
  -l, --location <region>       Azure Region for Template Spec storage (default: ${DEFAULT_LOCATION})
  --execute                     Explicitly execute the publishing command (requires active Azure login)
  -h, --help                    Show this help message

By default, this script operates in DRY-RUN mode, displaying the exact commands without executing them.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) TARGET_RG="$2"; shift 2 ;;
    -n|--name) TS_NAME="$2"; shift 2 ;;
    -v|--version) TS_VERSION="$2"; shift 2 ;;
    -l|--location) TS_LOCATION="$2"; shift 2 ;;
    --execute) EXECUTE=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

echo "======================================================================"
echo " Elrehan Azure Deployment Wizard - Template Spec Publishing Plan"
echo "======================================================================"
echo "Target Resource Group : ${TARGET_RG}"
echo "Template Spec Name    : ${TS_NAME}"
echo "Template Spec Version : ${TS_VERSION}"
echo "Region (Storage)      : ${TS_LOCATION}"
echo "Execution Mode        : $( [ "${EXECUTE}" = true ] && echo "EXECUTE (Live Azure publishing)" || echo "DRY-RUN (Preview commands only)" )"
echo "----------------------------------------------------------------------"

# Ensure prerequisites exist
if ! command -v az >/dev/null 2>&1; then
  echo "[-] Azure CLI (az) is not installed."
  exit 1
fi

if [ ! -f "${DIST_DIR}/main-rg.json" ] || [ ! -f "${DIST_DIR}/uiFormDefinition.json" ]; then
  echo "[-] Compiled artifacts missing. Building first..."
  bash "${SCRIPT_DIR}/build.sh"
fi

echo "[+] Verified deployment artifacts:"
echo "    - ARM Template File   : ${DIST_DIR}/main-rg.json"
echo "    - UI Form Definition  : ${DIST_DIR}/uiFormDefinition.json"
echo ""

if [ "${EXECUTE}" = false ]; then
  echo "----------------------------------------------------------------------"
  echo " MANUAL AZURE PUBLISHING COMMANDS (Dry-Run Preview):"
  echo "----------------------------------------------------------------------"
  echo ""
  echo "# 1. Log in to Azure and verify active subscription:"
  echo "az login"
  echo "az account show --output table"
  echo ""
  echo "# 2. Create the Template Spec storage Resource Group (if not already existing):"
  echo "az group create --name \"${TARGET_RG}\" --location \"${TS_LOCATION}\""
  echo ""
  echo "# 3. Publish the Template Spec with custom Portal UI Form Definition:"
  echo "az ts create \\"
  echo "  --resource-group \"${TARGET_RG}\" \\"
  echo "  --name \"${TS_NAME}\" \\"
  echo "  --version \"${TS_VERSION}\" \\"
  echo "  --location \"${TS_LOCATION}\" \\"
  echo "  --display-name \"Elrehan Infrastructure Deployment Wizard\" \\"
  echo "  --description \"Multi-step guided Azure infrastructure deployment wizard for virtual networks, subnets, and compute.\" \\"
  echo "  --template-file \"${DIST_DIR}/main-rg.json\" \\"
  echo "  --ui-form-definition \"${DIST_DIR}/uiFormDefinition.json\" \\"
  echo "  --yes"
  echo ""
  echo "To execute these commands directly, re-run with: $0 --execute"
  echo "======================================================================"
  exit 0
fi

# Live execution path (only when --execute is passed)
echo "[!] LIVE EXECUTION REQUESTED."
echo "    This will create Azure resources in your active subscription."
read -rp "Are you sure you want to publish Template Spec '${TS_NAME}' to '${TARGET_RG}'? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Publishing aborted by user."
  exit 0
fi

# Verify active login
if ! az account show >/dev/null 2>&1; then
  echo "[-] Not logged in to Azure. Please run 'az login' first."
  exit 1
fi

ACTIVE_SUB=$(az account show --query name -o tsv)
echo "[+] Active subscription: ${ACTIVE_SUB}"

echo "[1/2] Ensuring storage resource group '${TARGET_RG}' exists..."
az group create --name "${TARGET_RG}" --location "${TS_LOCATION}" --tags Project="Elrehan Wizard" Environment="TemplateSpecStorage"

echo "[2/2] Publishing Template Spec '${TS_NAME}:${TS_VERSION}'..."
az ts create \
  --resource-group "${TARGET_RG}" \
  --name "${TS_NAME}" \
  --version "${TS_VERSION}" \
  --location "${TS_LOCATION}" \
  --display-name "Elrehan Infrastructure Deployment Wizard" \
  --description "Multi-step guided Azure infrastructure deployment wizard for virtual networks, subnets, and compute." \
  --template-file "${DIST_DIR}/main-rg.json" \
  --ui-form-definition "${DIST_DIR}/uiFormDefinition.json" \
  --yes

echo "[+] Template Spec published successfully."
echo "Deploy in Portal at: https://portal.azure.com/#view/HubsExtension/TemplateSpecsBlade"
