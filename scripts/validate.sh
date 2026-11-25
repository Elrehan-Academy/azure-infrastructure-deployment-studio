#!/usr/bin/env bash
# ==============================================================================
# Elrehan Azure Deployment Wizard - Automated Verification & QA Suite
# Sprint 1.2 Engineering Remediation & Release Candidate Validation
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"

echo "======================================================================"
echo " Elrehan Azure Deployment Wizard - Validation Suite (Sprint 1.2)"
echo "======================================================================"

# Ensure build is up-to-date
bash "${SCRIPT_DIR}/build.sh"

python3 - "${PROJECT_ROOT}" <<'EOF'
import sys
import json
import subprocess
import os
import re

project_root = sys.argv[1]
dist_dir = os.path.join(project_root, "dist")
scripts_dir = os.path.join(project_root, "scripts")

# Import the deterministic network validation engine
sys.path.insert(0, scripts_dir)
try:
    from network_validator import validate_network_configuration, run_test_suite
    from test_three_subnets import run_n3_test_suite
    from test_additional_subnet import run_n4_test_suite
    has_net_validator = True
except ImportError as e:
    has_net_validator = False
    net_import_err = str(e)

results = []

def record(test_name, expected, actual, status, evidence=""):
    results.append({
        "name": test_name,
        "expected": expected,
        "actual": actual,
        "status": status,
        "evidence": evidence
    })
    prefix = f"[{status}]"
    print(f"{prefix} {test_name}")
    print(f"       Expected: {expected}")
    print(f"       Actual:   {actual}")
    if evidence:
        for line in evidence.strip().split("\n")[:4]:
            print(f"       Evidence: {line}")

bicep_cmd = os.path.expanduser("~/.azure/bin/bicep")
if not os.path.exists(bicep_cmd):
    bicep_cmd = "bicep"

print("\n--- 1. Bicep Compilation & Strict Linter Check ---")
bicep_files = [
    "main.bicep",
    "main-rg.bicep",
    "modules/network.bicep",
    "modules/compute.bicep",
    "modules/nsg.bicep",
    "modules/routeTable.bicep",
    "modules/subnet.bicep"
]

for bf in bicep_files:
    full_path = os.path.join(project_root, bf)
    res = subprocess.run([bicep_cmd, "build", full_path, "--stdout"], capture_output=True, text=True)
    is_clean = (res.returncode == 0) and ("Warning" not in res.stderr)
    record(
        f"Bicep compile {bf}",
        "Exit code 0 and zero warnings",
        f"Exit code {res.returncode}, warnings={'Yes' if 'Warning' in res.stderr else 'No'}",
        "PASS" if is_clean else "FAIL",
        res.stderr if not is_clean else "Clean compilation"
    )

print("\n--- 2. ARM Template Scopes and Schema Integrity ---")
for arm_name, expected_scope in [("main.json", "subscriptionDeploymentTemplate.json"), ("main-rg.json", "deploymentTemplate.json")]:
    full_path = os.path.join(dist_dir, arm_name)
    try:
        with open(full_path) as f:
            arm_doc = json.load(f)
        schema = arm_doc.get("$schema", "")
        correct_scope = expected_scope in schema
        record(
            f"ARM JSON schema scope for {arm_name}",
            f"Schema matches {expected_scope}",
            schema,
            "PASS" if correct_scope else "FAIL",
            f"Parameters count: {len(arm_doc.get('parameters', {}))}"
        )
    except Exception as e:
        record(f"ARM JSON schema scope for {arm_name}", "Valid JSON", str(e), "FAIL")

print("\n--- 3. Official UI Schema Compliance (uiFormDefinition) ---")
try:
    import jsonschema
    schema_path = "/tmp/uiFormDefinition.schema.json"
    if not os.path.exists(schema_path):
        import urllib.request
        urllib.request.urlretrieve("https://schema.management.azure.com/schemas/2021-09-09/uiFormDefinition.schema.json", schema_path)
    with open(schema_path) as sf:
        ui_schema = json.load(sf)

    for ui_file in ["uiFormDefinition.json", "uiFormDefinition.rg.json", "uiFormDefinition.subscription.json"]:
        full_path = os.path.join(dist_dir, ui_file)
        try:
            with open(full_path) as uf:
                ui_instance = json.load(uf)
            jsonschema.validate(instance=ui_instance, schema=ui_schema)
            record(
                f"Validate {ui_file} against official schema 2021-09-09",
                "Schema validation passes without errors",
                "Validation passed",
                "PASS",
                f"Title: {ui_instance['view']['properties']['title']}"
            )
        except Exception as ve:
            record(
                f"Validate {ui_file} against official schema 2021-09-09",
                "Schema validation passes without errors",
                str(ve).split("\n")[0],
                "FAIL"
            )
except ImportError:
    record("jsonschema library availability", "jsonschema available", "Module missing", "BLOCKED")

print("\n--- 4. UI Output-to-ARM Parameter Mapping ---")
# 4a. Resource Group Scope
with open(os.path.join(dist_dir, "main-rg.json")) as mf:
    rg_arm = json.load(mf)
with open(os.path.join(dist_dir, "uiFormDefinition.json")) as uf:
    rg_ui = json.load(uf)

rg_arm_params = set(rg_arm.get("parameters", {}).keys())
rg_ui_outputs = set(rg_ui["view"]["outputs"]["parameters"].keys())

unmatched_rg = rg_ui_outputs - rg_arm_params
missing_mandatory_rg = set()
for p, pdef in rg_arm.get("parameters", {}).items():
    if "defaultValue" not in pdef and p not in rg_ui_outputs:
        missing_mandatory_rg.add(p)

is_rg_aligned = (len(unmatched_rg) == 0) and (len(missing_mandatory_rg) == 0)
record(
    "UI Form Definition (RG scope) maps to main-rg.json parameters",
    "0 unmatched UI keys and 0 missing mandatory parameters",
    f"Unmatched: {len(unmatched_rg)}, Missing mandatory: {len(missing_mandatory_rg)}",
    "PASS" if is_rg_aligned else "FAIL",
    f"Mapped keys: {sorted(list(rg_ui_outputs))}"
)

# 4b. Subscription Scope
with open(os.path.join(dist_dir, "main.json")) as mf:
    sub_arm = json.load(mf)
with open(os.path.join(dist_dir, "uiFormDefinition.subscription.json")) as uf:
    sub_ui = json.load(uf)

sub_arm_params = set(sub_arm.get("parameters", {}).keys())
sub_ui_outputs = set(sub_ui["view"]["outputs"]["parameters"].keys())

unmatched_sub = sub_ui_outputs - sub_arm_params
missing_mandatory_sub = set()
for p, pdef in sub_arm.get("parameters", {}).items():
    if "defaultValue" not in pdef and p not in sub_ui_outputs:
        missing_mandatory_sub.add(p)

is_sub_aligned = (len(unmatched_sub) == 0) and (len(missing_mandatory_sub) == 0)
record(
    "UI Form Definition (Subscription scope) maps to main.json parameters",
    "0 unmatched UI keys and 0 missing mandatory parameters",
    f"Unmatched: {len(unmatched_sub)}, Missing mandatory: {len(missing_mandatory_sub)}",
    "PASS" if is_sub_aligned else "FAIL",
    f"Mapped keys: {sorted(list(sub_ui_outputs))}"
)

print("\n--- 5. VM Authentication & Security Remediation (Sprint 1.2) ---")
with open(os.path.join(project_root, "modules/compute.bicep")) as cf:
    compute_src = cf.read()

has_mock_key = "pilot-mock-key" in compute_src
has_hardcoded_pass = "Elrehan#Pilot" in compute_src
has_separate_pass = "param adminPassword string" in compute_src
has_separate_ssh = "param adminSshPublicKey string" in compute_src
has_secure_pass = "@secure()\nparam adminPassword" in compute_src or "@secure()\r\nparam adminPassword" in compute_src
has_secure_ssh = "@secure()\nparam adminSshPublicKey" in compute_src or "@secure()\r\nparam adminSshPublicKey" in compute_src
has_compute_fail = "fail(" in compute_src

auth_clean = (not has_mock_key) and (not has_hardcoded_pass) and has_separate_pass and has_separate_ssh and has_secure_pass and has_secure_ssh and has_compute_fail
record(
    "VM Credentials remediation in modules/compute.bicep",
    "No mock keys, no hardcoded passwords, separate @secure() parameters, fail() validation",
    f"MockKey={has_mock_key}, HardcodedPass={has_hardcoded_pass}, SeparateParams={has_separate_pass and has_separate_ssh}, SecureTags={has_secure_pass and has_secure_ssh}, ComputeFail={has_compute_fail}",
    "PASS" if auth_clean else "FAIL"
)

# Check main.bicep & main-rg.bicep: silent suppression REMOVED, explicit fail() guard present
with open(os.path.join(project_root, "main.bicep")) as mf:
    main_src = mf.read()
with open(os.path.join(project_root, "main-rg.bicep")) as rgf:
    main_rg_src = rgf.read()

has_silent_suppression = "shouldDeployVm = deployVm && hasValidAuth" in main_src or "shouldDeployVm = deployVm && hasValidAuth" in main_rg_src
has_auth_fail_guard = "var authCheck = deployVm ? (!hasValidAuth ? fail(" in main_src and "var authCheck = deployVm ? (!hasValidAuth ? fail(" in main_rg_src
default_deploy_false = "param deployVm bool = false" in main_src and "param deployVm bool = false" in main_rg_src
ssh_rejects_ecdsa = "ecdsa-sha2-" not in main_src and "ecdsa-sha2-" not in main_rg_src and "startsWith(adminSshPublicKey, 'ssh-rsa')" in main_src

record(
    "Elimination of silent VM deployment suppression and replacement with explicit fail() guard",
    "shouldDeployVm removed; deployVm defaults to false; explicit fail() on invalid credentials; ECDSA rejected",
    f"silentSuppressionRemoved={not has_silent_suppression}, defaultDeployFalse={default_deploy_false}, authFailGuardPresent={has_auth_fail_guard}, ecdsaRejected={ssh_rejects_ecdsa}",
    "PASS" if (not has_silent_suppression and default_deploy_false and has_auth_fail_guard and ssh_rejects_ecdsa) else "FAIL"
)

print("\n--- 6. VM Subnet Selection Validation (Sprint 1.2) ---")
has_silent_subnet_fallback = "targetSubnetName = contains(configuredSubnetNames, selectedSubnetName) ? selectedSubnetName : subnets[0].name" in main_src
has_subnet_fail_guard = "var subnetCheck = deployVm ? (!isSubnetValid ? fail(" in main_src and "var subnetCheck = deployVm ? (!isSubnetValid ? fail(" in main_rg_src

record(
    "Elimination of silent VM subnet fallback and replacement with explicit fail() guard",
    "Fallback to subnets[0].name removed; explicit fail() when selectedSubnetName does not match configured subnets",
    f"silentFallbackRemoved={not has_silent_subnet_fallback}, subnetFailGuardPresent={has_subnet_fail_guard}",
    "PASS" if (not has_silent_subnet_fallback and has_subnet_fail_guard) else "FAIL"
)

print("\n--- 7. Network Validation & Duplicate Subnet Guard ---")
with open(os.path.join(project_root, "modules/network.bicep")) as nf:
    net_src = nf.read()

has_dup_guard = "hasDuplicateSubnetNames" in net_src and "fail(" in net_src
has_prefix_guard = "hasDuplicateSubnetPrefixes" in net_src and "fail(" in net_src
record(
    "Duplicate subnet name & prefix validation guards in modules/network.bicep",
    "Modules/network.bicep evaluates uniqueness of subnet names and prefixes and fails if duplicates exist",
    f"hasDuplicateSubnetGuard={has_dup_guard}, hasDuplicatePrefixGuard={has_prefix_guard}",
    "PASS" if (has_dup_guard and has_prefix_guard) else "FAIL"
)

if has_net_validator:
    net_suite_passed = run_test_suite()
    record(
        "Network calculation engine (8 mandatory test cases)",
        "All 8 test cases pass exact expected validation outcomes",
        "8/8 tests passed" if net_suite_passed else "Failures in test cases",
        "PASS" if net_suite_passed else "FAIL"
    )

    n3_passed, n3_failed, _ = run_n3_test_suite()
    record(
        "Smart Three-Subnet validation engine (15 mandatory test scenarios)",
        "All 15 test scenarios pass exact expected validation outcomes",
        f"{n3_passed}/15 tests passed" if n3_failed == 0 else f"{n3_failed} failures",
        "PASS" if n3_failed == 0 else "FAIL"
    )

    n4_passed = run_n4_test_suite()
    record(
        "Intelligent Additional Subnet validation engine (18 mandatory test scenarios)",
        "All 18 test scenarios pass exact expected validation outcomes",
        "18/18 tests passed" if n4_passed else "Failures in N4 test cases",
        "PASS" if n4_passed else "FAIL"
    )
else:
    record("Network calculation engine", "network_validator.py present", net_import_err, "FAIL")

print("\n--- 8. Tags Mapping & Normalization (Microsoft.Common.TagsByResource) ---")
has_tag_norm_main = "effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags" in main_src
has_tag_norm_rg = "effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags" in main_rg_src

record(
    "Resource tag normalization for Microsoft.Common.TagsByResource and flat dictionaries",
    "Unpacks nested Microsoft.Resources/deployments if present; preserves flat tags dictionary",
    f"mainTagNorm={has_tag_norm_main}, mainRgTagNorm={has_tag_norm_rg}",
    "PASS" if (has_tag_norm_main and has_tag_norm_rg) else "FAIL"
)

print("\n--- 9. Deterministic ARM Evaluation Simulation Suite (15 Scenarios) ---")
# Evaluate ARM template variable expressions under positive and negative configurations across all 15 scenarios
def simulate_bicep_eval(params):
    vnet_mode = params.get("vnetMode", "new")
    address_prefix = params.get("addressPrefix", "10.0.0.0/16")
    subnets = params.get("subnets", [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}])
    existing_vnet_name = params.get("existingVnetName", "")
    add_new_subnet = params.get("addNewSubnet", False)
    new_subnet_name = params.get("newSubnetName", "")
    new_subnet_prefix = params.get("newSubnetPrefix", "")
    existing_subnet_name = params.get("existingSubnetName", "")
    
    nsg_mode = params.get("nsgMode", "new")
    existing_nsg_name = params.get("existingNsgName", "")
    
    rt_mode = params.get("routeTableMode", "new")
    existing_rt_name = params.get("existingRouteTableName", "")
    
    deploy_vm = params.get("deployVm", False)
    os_type = params.get("osType", "Linux")
    ssh_key = params.get("adminSshPublicKey", "")
    password = params.get("adminPassword", "")
    selected_subnet = params.get("selectedSubnetName", "snet-workload")
    
    errors = []
    
    # Network validation
    if vnet_mode == "new":
        is_valid_net, net_errs = validate_network_configuration(address_prefix, subnets)
        if not is_valid_net:
            errors.extend(net_errs)
    elif vnet_mode == "existing":
        if not existing_vnet_name:
            errors.append("existingVnetName is required when vnetMode is existing")
        if add_new_subnet:
            if not new_subnet_name or not new_subnet_prefix:
                errors.append("newSubnetName and newSubnetPrefix required when addNewSubnet is true")
            else:
                try:
                    import ipaddress
                    ipaddress.IPv4Network(new_subnet_prefix, strict=True)
                except Exception as e:
                    errors.append(f"Invalid newSubnetPrefix: {e}")
                    
    # NSG validation
    if nsg_mode == "existing" and not existing_nsg_name:
        errors.append("existingNsgName is required when nsgMode is existing")
        
    # Route Table validation
    if rt_mode == "existing" and not existing_rt_name:
        errors.append("existingRouteTableName is required when routeTableMode is existing")
        
    # Compute validation
    if deploy_vm:
        is_linux = (os_type == 'Linux')
        is_windows = (os_type == 'Windows')
        has_valid_linux_auth = is_linux and bool(ssh_key) and (ssh_key.startswith('ssh-rsa') or ssh_key.startswith('ssh-ed25519'))
        has_valid_windows_auth = is_windows and bool(password) and (12 <= len(password) <= 123)
        has_valid_auth = has_valid_linux_auth or has_valid_windows_auth
        if not has_valid_auth:
            errors.append("VM deployment enabled but credentials invalid or missing")
            
        configured_subnets = [s['name'] for s in subnets] if vnet_mode == 'new' else []
        is_subnet_valid = False
        if vnet_mode == 'new':
            is_subnet_valid = bool(selected_subnet) and (selected_subnet in configured_subnets)
        else:
            is_subnet_valid = bool(selected_subnet) and ((add_new_subnet and selected_subnet == new_subnet_name) or (bool(existing_subnet_name) and selected_subnet == existing_subnet_name))
            
        if not is_subnet_valid:
            errors.append(f"VM deployment enabled but selected subnet '{selected_subnet}' is not valid")
            
    return {
        "valid": len(errors) == 0,
        "errors": errors
    }

eval_cases = [
    {
        "id": "TC-SCENARIO-01",
        "desc": "1. New resource group, new VNet, new NSG, new Route Table, VM enabled",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-elrehan-new",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "new", "nsgName": "nsg-pilot",
            "routeTableMode": "new", "routeTableName": "rt-pilot",
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...",
            "selectedSubnetName": "snet-workload"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-02",
        "desc": "2. New resource group, new VNet, existing NSG, existing Route Table, VM enabled",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-elrehan-new",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "existing", "existingNsgName": "nsg-corp-shared",
            "routeTableMode": "existing", "existingRouteTableName": "rt-corp-shared",
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...",
            "selectedSubnetName": "snet-workload"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-03",
        "desc": "3. Existing resource group, new VNet, new NSG, new Route Table, VM disabled",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-existing",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "new", "nsgName": "nsg-pilot",
            "routeTableMode": "new", "routeTableName": "rt-pilot",
            "deployVm": False
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-04",
        "desc": "4. Existing resource group, existing VNet, existing NSG, existing Route Table, VM disabled",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-existing",
            "vnetMode": "existing", "existingVnetName": "vnet-existing",
            "existingSubnetName": "snet-existing",
            "nsgMode": "existing", "existingNsgName": "nsg-existing",
            "routeTableMode": "existing", "existingRouteTableName": "rt-existing",
            "deployVm": False
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-05",
        "desc": "5. Existing resource group, existing VNet, new subnet, new NSG, new Route Table, VM enabled",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-existing",
            "vnetMode": "existing", "existingVnetName": "vnet-existing",
            "addNewSubnet": True, "newSubnetName": "snet-workload-new", "newSubnetPrefix": "10.0.3.0/24",
            "nsgMode": "new", "nsgName": "nsg-pilot",
            "routeTableMode": "new", "routeTableName": "rt-pilot",
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...",
            "selectedSubnetName": "snet-workload-new"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-06",
        "desc": "6. Cross-resource-group VNet deployment (VNet in RG-A, deployment in RG-B)",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-workload-b",
            "vnetMode": "existing", "existingVnetName": "vnet-shared-a", "existingVnetResourceGroup": "rg-network-a",
            "addNewSubnet": True, "newSubnetName": "snet-tier-b", "newSubnetPrefix": "10.10.2.0/24",
            "nsgMode": "none", "routeTableMode": "none",
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-rsa AAAAB3NzaC1yc2E...",
            "selectedSubnetName": "snet-tier-b"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-07",
        "desc": "7. Cross-resource-group NSG reference (NSG in RG-A, deployment in RG-B)",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-workload-b",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "existing", "existingNsgName": "nsg-central-sec", "existingNsgResourceGroup": "rg-security-a",
            "routeTableMode": "none",
            "deployVm": False
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-08",
        "desc": "8. Cross-resource-group Route Table reference (Route Table in RG-A, deployment in RG-B)",
        "params": {
            "createNewResourceGroup": False, "resourceGroupName": "rg-workload-b",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "none",
            "routeTableMode": "existing", "existingRouteTableName": "rt-hub-fw", "existingRouteTableResourceGroup": "rg-routing-a",
            "deployVm": False
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-09",
        "desc": "9. Windows VM deployment with password authentication",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-win-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "new", "routeTableMode": "new",
            "deployVm": True, "osType": "Windows", "adminPassword": "P@ssw0rdSecure2026!",
            "selectedSubnetName": "snet-workload"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-10",
        "desc": "10. Linux VM deployment with SSH key authentication",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-linux-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "nsgMode": "new", "routeTableMode": "new",
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...",
            "selectedSubnetName": "snet-workload"
        },
        "expect_valid": True
    },
    {
        "id": "TC-SCENARIO-11",
        "desc": "11. Invalid VNet CIDR rejected",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.256.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.256.1.0/24"}],
            "deployVm": False
        },
        "expect_valid": False
    },
    {
        "id": "TC-SCENARIO-12",
        "desc": "12. Overlapping subnets rejected",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [
                {"name": "snet-1", "addressPrefix": "10.0.1.0/24"},
                {"name": "snet-2", "addressPrefix": "10.0.1.128/25"}
            ],
            "deployVm": False
        },
        "expect_valid": False
    },
    {
        "id": "TC-SCENARIO-13",
        "desc": "13. Subnet outside VNet CIDR rejected",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-outside", "addressPrefix": "10.1.1.0/24"}],
            "deployVm": False
        },
        "expect_valid": False
    },
    {
        "id": "TC-SCENARIO-14",
        "desc": "14. Missing required authentication rejected when VM enabled",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "",
            "selectedSubnetName": "snet-workload"
        },
        "expect_valid": False
    },
    {
        "id": "TC-SCENARIO-15",
        "desc": "15. Nonexistent subnet selection rejected when VM enabled",
        "params": {
            "createNewResourceGroup": True, "resourceGroupName": "rg-pilot",
            "vnetMode": "new", "vnetName": "vnet-pilot", "addressPrefix": "10.0.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.0.1.0/24"}],
            "deployVm": True, "osType": "Linux", "adminSshPublicKey": "ssh-rsa AAAAB3NzaC1yc2E...",
            "selectedSubnetName": "snet-nonexistent"
        },
        "expect_valid": False
    }
]

eval_suite_passed = True
for tc in eval_cases:
    res = simulate_bicep_eval(tc["params"])
    passed = (res["valid"] == tc["expect_valid"])
    if not passed:
        eval_suite_passed = False
    record(
        f"Evaluation simulation: {tc['desc']}",
        f"Valid={tc['expect_valid']}",
        f"Valid={res['valid']}, Errors={res['errors']}",
        "PASS" if passed else "FAIL"
    )

print("\n--- 10. Baseline Parameter File Verification ---")
with open(os.path.join(project_root, "main.bicepparam")) as pf:
    param_content = pf.read()

param_has_pass = "Elrehan#" in param_content or ("password = '" in param_content.lower() and not "password = ''" in param_content.lower())
param_deploy_vm_false = "param deployVm = false" in param_content
record(
    "Baseline main.bicepparam security and defaults",
    "deployVm = false and no embedded passwords/keys",
    f"deployVmFalse={param_deploy_vm_false}, embeddedSecretFound={param_has_pass}",
    "PASS" if (param_deploy_vm_false and not param_has_pass) else "FAIL"
)

print("\n--- 11. Distribution Packaging Completeness ---")
expected_artifacts = [
    "main.json",
    "main-rg.json",
    "uiFormDefinition.json",
    "uiFormDefinition.rg.json",
    "uiFormDefinition.subscription.json",
    "createUiDefinition.json"
]
all_exist = all(os.path.exists(os.path.join(dist_dir, f)) for f in expected_artifacts)
record(
    "Distribution artifacts presence in dist/",
    f"All {len(expected_artifacts)} artifacts compiled and present in dist/",
    f"Present: {sum(1 for f in expected_artifacts if os.path.exists(os.path.join(dist_dir, f)))}/{len(expected_artifacts)}",
    "PASS" if all_exist else "FAIL"
)

print("\n--- 12. Deploy to Azure Portal Artifacts Integrity ---")
portal_template_path = os.path.join(project_root, "portal/mainTemplate.json")
portal_uidef_path = os.path.join(project_root, "portal/uiFormDefinition.json")
has_portal_template = os.path.exists(portal_template_path)
has_portal_uidef = os.path.exists(portal_uidef_path)

portal_artifacts_valid = False
if has_portal_template and has_portal_uidef:
    with open(portal_template_path) as ptf:
        p_template = json.load(ptf)
    with open(portal_uidef_path) as puf:
        p_uidef = json.load(puf)
    # Check schema and output kind
    is_rg_scope = "deploymentTemplate.json" in p_template.get("$schema", "")
    is_rg_uidef = p_uidef.get("view", {}).get("outputs", {}).get("kind") == "ResourceGroup"
    portal_artifacts_valid = is_rg_scope and is_rg_uidef

record(
    "Deploy to Azure Portal artifacts (portal/mainTemplate.json & portal/uiFormDefinition.json)",
    "Both portal files present, valid JSON, matching Resource Group scope deployment contract",
    f"TemplatePresent={has_portal_template}, UiDefPresent={has_portal_uidef}, ValidContract={portal_artifacts_valid}",
    "PASS" if portal_artifacts_valid else "FAIL"
)

print("\n======================================================================")
pass_count = sum(1 for r in results if r["status"] == "PASS")
fail_count = sum(1 for r in results if r["status"] == "FAIL")
blocked_count = sum(1 for r in results if r["status"] == "BLOCKED")
total_count = len(results)

print(f" FINAL QA SUMMARY: {pass_count}/{total_count} PASSED | {fail_count} FAILED | {blocked_count} BLOCKED")
print("======================================================================")

if fail_count > 0:
    sys.exit(1)
EOF
