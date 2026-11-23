#!/usr/bin/env bash
# ==============================================================================
# Elrehan Azure Deployment Wizard - Build Script
# Compiles Bicep source files to ARM JSON and packages UI definitions into dist/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"

BICEP_CMD="${PROJECT_ROOT}/.azure/bin/bicep"
if [ ! -f "${BICEP_CMD}" ]; then
  if command -v bicep >/dev/null 2>&1; then
    BICEP_CMD="bicep"
  elif [ -f "${HOME}/.azure/bin/bicep" ]; then
    BICEP_CMD="${HOME}/.azure/bin/bicep"
  else
    BICEP_CMD="az bicep"
  fi
fi

echo "======================================================================"
echo " Elrehan Azure Deployment Wizard - Artifact Build"
echo "======================================================================"
echo "Project Root: ${PROJECT_ROOT}"
echo "Output Directory: ${DIST_DIR}"
echo "Bicep Compiler: ${BICEP_CMD}"
echo "----------------------------------------------------------------------"

# Clean and recreate dist directory
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR:?}"/*

echo "[1/4] Compiling main.bicep (Subscription Scope) -> dist/main.json..."
${BICEP_CMD} build "${PROJECT_ROOT}/main.bicep" --outfile "${DIST_DIR}/main.json"
echo "      SUCCESS: Generated dist/main.json ($(stat -c%s "${DIST_DIR}/main.json") bytes)"

echo "[2/4] Compiling main-rg.bicep (Resource Group Scope) -> dist/main-rg.json..."
${BICEP_CMD} build "${PROJECT_ROOT}/main-rg.bicep" --outfile "${DIST_DIR}/main-rg.json"
echo "      SUCCESS: Generated dist/main-rg.json ($(stat -c%s "${DIST_DIR}/main-rg.json") bytes)"

echo "[3/4] Copying and formatting UI Form Definitions and Portal Artifacts..."
cp "${PROJECT_ROOT}/ui/uiFormDefinition.json" "${DIST_DIR}/uiFormDefinition.json"
cp "${PROJECT_ROOT}/ui/uiFormDefinition.rg.json" "${DIST_DIR}/uiFormDefinition.rg.json"
cp "${PROJECT_ROOT}/ui/uiFormDefinition.subscription.json" "${DIST_DIR}/uiFormDefinition.subscription.json"
cp "${PROJECT_ROOT}/ui/createUiDefinition.json" "${DIST_DIR}/createUiDefinition.json"
mkdir -p "${PROJECT_ROOT}/portal"
cp "${DIST_DIR}/main-rg.json" "${PROJECT_ROOT}/portal/mainTemplate.json"
cp "${DIST_DIR}/uiFormDefinition.json" "${PROJECT_ROOT}/portal/uiFormDefinition.json"
echo "      SUCCESS: Packaged UI definitions to dist/ and portal/"

echo "[4/4] Validating build artifacts integrity & secret scanning..."
python3 -c "
import json
import re

dist_dir = '${DIST_DIR}'
artifacts = [
    'main.json',
    'main-rg.json',
    'uiFormDefinition.json',
    'uiFormDefinition.rg.json',
    'uiFormDefinition.subscription.json',
    'createUiDefinition.json'
]

# Patterns that indicate accidentally embedded secrets
secret_patterns = [
    re.compile(r'Elrehan#Pilot', re.IGNORECASE),
    re.compile(r'pilot-mock-key', re.IGNORECASE),
    re.compile(r'password\s*[:=]\s*[\'\"][^\"\']+[\'\"]', re.IGNORECASE),
    re.compile(r'ssh-rsa\s+AAAA[A-Za-z0-9+/=]{100,}')
]

for fname in artifacts:
    path = f'{dist_dir}/{fname}'
    with open(path) as f:
        content = f.read()
        json.loads(content)  # Syntax check
    
    for pat in secret_patterns:
        if pat.search(content):
            raise SystemExit(f'SECURITY ALERT: Secret pattern {pat.pattern} detected in {fname}!')
            
    print(f'      OK: {fname} is valid JSON and clean of embedded secrets')
"

echo "----------------------------------------------------------------------"
echo " BUILD COMPLETE: All artifacts successfully generated in dist/"
echo "======================================================================"
ls -lh "${DIST_DIR}"
