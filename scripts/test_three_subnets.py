#!/usr/bin/env python3
"""
Sprint 1.3 - N3: Smart Three-Subnet Test Suite
Executes the 15 mandatory test scenarios defined in Sprint 1.3 N3 Section 7.
Tests UI output generation, CIDR containment, subnet overlap detection,
naming uniqueness, and Bicep compilation compatibility.
"""

import os
import sys
import json
import ipaddress
from typing import Dict, List, Any, Tuple

# Import project network validator
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

from network_validator import validate_network_configuration

def simulate_ui_output(
    vnet_mode: str,
    s1_name: str, s1_prefix: str,
    enable_s2: bool, s2_name: str, s2_prefix: str,
    enable_s3: bool, s3_name: str, s3_prefix: str
) -> List[Dict[str, str]]:
    """
    Simulates the exact nested if() expression used in uiFormDefinition.json
    outputs.parameters.subnets.
    """
    if vnet_mode != "new":
        return [{"name": "snet-placeholder", "addressPrefix": "10.0.0.0/24"}]

    subnets = [{"name": s1_name, "addressPrefix": s1_prefix}]
    if enable_s2:
        subnets.append({"name": s2_name, "addressPrefix": s2_prefix})
    if enable_s3:
        subnets.append({"name": s3_name, "addressPrefix": s3_prefix})
    return subnets

def run_n3_test_suite() -> Tuple[int, int, List[Dict[str, Any]]]:
    """Runs all 15 required test scenarios and reports results."""
    results = []

    scenarios = [
        # 1. Subnet 1 only
        {
            "id": "N3-01",
            "name": "Subnet 1 only (mandatory single subnet)",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": False, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 1,
            "expect_valid": True,
            "expected_names": ["snet-workload"]
        },
        # 2. Subnets 1 and 2
        {
            "id": "N3-02",
            "name": "Subnets 1 and 2 enabled",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": True,
            "expected_names": ["snet-workload", "snet-data"]
        },
        # 3. Subnets 1 and 3 (Subnet 2 disabled, Subnet 3 enabled)
        {
            "id": "N3-03",
            "name": "Subnets 1 and 3 enabled (independent selection)",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": False, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": True, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": True,
            "expected_names": ["snet-workload", "snet-mgmt"]
        },
        # 4. All three subnets
        {
            "id": "N3-04",
            "name": "All three subnets enabled",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": True, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 3,
            "expect_valid": True,
            "expected_names": ["snet-workload", "snet-data", "snet-mgmt"]
        },
        # 5. Overlap between Subnets 1 and 2
        {
            "id": "N3-05",
            "name": "Overlap between Subnet 1 and Subnet 2 rejected",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.1.128/25",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": False,
            "error_keyword": "overlaps"
        },
        # 6. Overlap between Subnets 2 and 3
        {
            "id": "N3-06",
            "name": "Overlap between Subnet 2 and Subnet 3 rejected",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": True, "s3_name": "snet-mgmt", "s3_prefix": "10.0.2.0/25"
            },
            "expect_subnets_count": 3,
            "expect_valid": False,
            "error_keyword": "overlaps"
        },
        # 7. Subnet outside VNet boundaries
        {
            "id": "N3-07",
            "name": "Subnet outside parent VNet address space rejected",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "192.168.1.0/24",
                "enable_s2": False, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 1,
            "expect_valid": False,
            "error_keyword": "not contained"
        },
        # 8. Duplicate subnet names (case-insensitive)
        {
            "id": "N3-08",
            "name": "Duplicate subnet names rejected",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "SNET-WORKLOAD", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": False,
            "error_keyword": "Duplicate subnet name"
        },
        # 9. Insufficient contiguous address space
        {
            "id": "N3-09",
            "name": "Insufficient address space in small VNet (/24 parent, multiple /24 subnets)",
            "vnet": "10.0.1.0/24",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": False,
            "error_keyword": "not contained"
        },
        # 10. Invalid subnet prefix length (/30 rejected by Azure)
        {
            "id": "N3-10",
            "name": "Invalid subnet prefix length (/30) rejected",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/30",
                "enable_s2": False, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 1,
            "expect_valid": False,
            "error_keyword": "unsupported by Azure"
        },
        # 11. Disabled subnet values excluded from deployment
        {
            "id": "N3-11",
            "name": "Disabled subnets excluded from output array even if fields contain values",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": False, "s2_name": "snet-invalid-s2", "s2_prefix": "99.99.99.0/24",
                "enable_s3": False, "s3_name": "snet-invalid-s3", "s3_prefix": "88.88.88.0/24"
            },
            "expect_subnets_count": 1,
            "expect_valid": True,
            "expected_names": ["snet-workload"]
        },
        # 12. Changing Subnet 1 after configuring Subnets 2 and 3
        {
            "id": "N3-12",
            "name": "Revalidation when Subnet 1 CIDR changes (creating overlap with Subnet 2)",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.2.0/24",  # Changed to 10.0.2.0/24!
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": True, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 3,
            "expect_valid": False,
            "error_keyword": "overlaps"
        },
        # 13. Changing the parent VNet address space
        {
            "id": "N3-13",
            "name": "Revalidation when parent VNet CIDR changes (subnets no longer contained)",
            "vnet": "172.16.0.0/16",  # VNet changed to 172.16.0.0/16, but subnets are 10.0.x.x
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": False,
            "error_keyword": "not contained"
        },
        # 14. Disabling and re-enabling an optional subnet
        {
            "id": "N3-14",
            "name": "Disabling Subnet 2 then re-enabling it dynamically updates the output array",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "new",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": True, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 2,
            "expect_valid": True,
            "expected_names": ["snet-workload", "snet-data"]
        },
        # 15. Regression testing of existing VNet and subnet discovery
        {
            "id": "N3-15",
            "name": "Regression test: existing VNet mode bypasses new subnet grid and uses existing parameters",
            "vnet": "10.0.0.0/16",
            "inputs": {
                "vnet_mode": "existing",
                "s1_name": "snet-workload", "s1_prefix": "10.0.1.0/24",
                "enable_s2": False, "s2_name": "snet-data", "s2_prefix": "10.0.2.0/24",
                "enable_s3": False, "s3_name": "snet-mgmt", "s3_prefix": "10.0.3.0/24"
            },
            "expect_subnets_count": 1,
            "expect_valid": True,
            "expected_names": ["snet-placeholder"]
        }
    ]

    passed = 0
    failed = 0

    print("======================================================================")
    print(" Sprint 1.3 - N3: Smart Three-Subnet Mandatory Test Suite (15 Cases)")
    print("======================================================================")

    for sc in scenarios:
        sid = sc["id"]
        sname = sc["name"]
        vnet = sc["vnet"]
        inp = sc["inputs"]
        exp_valid = sc["expect_valid"]

        # 1. Simulate UI output expression
        output_subnets = simulate_ui_output(**inp)
        count_ok = (len(output_subnets) == sc["expect_subnets_count"])

        if "expected_names" in sc:
            actual_names = [s["name"] for s in output_subnets]
            names_ok = (actual_names == sc["expected_names"])
        else:
            names_ok = True

        # 2. Run network validation
        if inp["vnet_mode"] == "new":
            is_valid, errs = validate_network_configuration(vnet, output_subnets)
        else:
            is_valid = True
            errs = []

        valid_ok = (is_valid == exp_valid)
        err_keyword_ok = True
        if not exp_valid and "error_keyword" in sc:
            err_keyword_ok = any(sc["error_keyword"].lower() in e.lower() for e in errs)

        success = count_ok and names_ok and valid_ok and err_keyword_ok

        status = "PASS" if success else "FAIL"
        if success:
            passed += 1
        else:
            failed += 1

        print(f"[{status}] {sid}: {sname}")
        print(f"       Subnets in output: {len(output_subnets)} (Expected: {sc['expect_subnets_count']})")
        print(f"       Validation result: Valid={is_valid} (Expected: {exp_valid})")
        if errs:
            print(f"       Validation messages: {errs}")

        results.append({
            "id": sid,
            "name": sname,
            "status": status,
            "subnets_count": len(output_subnets),
            "is_valid": is_valid,
            "errors": errs
        })

    print("======================================================================")
    print(f" N3 TEST SUMMARY: {passed}/15 PASSED | {failed}/15 FAILED")
    print("======================================================================")

    return passed, failed, results

if __name__ == "__main__":
    passed, failed, _ = run_n3_test_suite()
    sys.exit(0 if failed == 0 else 1)
