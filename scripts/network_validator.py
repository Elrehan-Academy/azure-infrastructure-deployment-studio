#!/usr/bin/env python3
"""
Elrehan Azure Deployment Wizard - Network Validation Engine
Performs deterministic network math, CIDR containment, subnet overlap checks,
and Azure-specific sizing/naming validations.
"""

import sys
import ipaddress
from typing import List, Dict, Any, Tuple

RESERVED_SUBNET_MIN_PREFIX = {
    "AzureFirewallSubnet": 26,
    "AzureFirewallManagementSubnet": 26,
    "GatewaySubnet": 29,
    "AzureBastionSubnet": 26,
    "RouteServerSubnet": 27,
}

def validate_network_configuration(
    vnet_cidr: str,
    subnets: List[Dict[str, Any]],
    strict_canonical: bool = True
) -> Tuple[bool, List[str]]:
    """
    Validates a VNet and its subnets against Azure networking rules:
    - Valid IPv4 CIDR syntax
    - Canonical network prefix check (e.g. host bits must be zero)
    - Azure supported prefix sizes (/8 to /29)
    - Full containment of all subnets within the VNet address space
    - Zero overlap between any pair of subnets
    - Unique and valid subnet names
    - Reserved Azure subnet prefix constraints
    """
    errors: List[str] = []

    # 1. Validate VNet CIDR
    if not isinstance(vnet_cidr, str) or not vnet_cidr.strip():
        return False, ["VNet CIDR address prefix is empty or invalid."]

    vnet_cidr = vnet_cidr.strip()
    try:
        # Check octets and syntax
        vnet_net = ipaddress.IPv4Network(vnet_cidr, strict=strict_canonical)
    except ipaddress.NetmaskValueError as e:
        return False, [f"Invalid VNet netmask: {e}"]
    except ValueError as e:
        # Check if due to non-canonical prefix
        if "has host bits set" in str(e):
            return False, [f"VNet prefix '{vnet_cidr}' is non-canonical (host bits are set)."]
        return False, [f"Invalid VNet CIDR '{vnet_cidr}': {e}"]

    # Azure VNet address space constraints: /8 to /29
    if vnet_net.prefixlen < 8 or vnet_net.prefixlen > 29:
        errors.append(
            f"VNet prefix /{vnet_net.prefixlen} is outside Azure supported range (/8 to /29)."
        )

    # 2. Validate Subnets
    if not isinstance(subnets, list) or len(subnets) == 0:
        errors.append("At least one subnet must be defined.")
        return False, errors

    seen_names = set()
    parsed_subnets: List[Tuple[str, ipaddress.IPv4Network]] = []

    for idx, snet in enumerate(subnets):
        if not isinstance(snet, dict):
            errors.append(f"Subnet entry {idx} is not a valid object.")
            continue

        name = str(snet.get("name", "")).strip()
        prefix = str(snet.get("addressPrefix", "")).strip()

        # Name checks
        if not name:
            errors.append(f"Subnet at index {idx} has an empty or invalid name.")
            continue

        name_lower = name.lower()
        if name_lower in seen_names:
            errors.append(f"Duplicate subnet name detected: '{name}'.")
        seen_names.add(name_lower)

        # Prefix parsing
        if not prefix:
            errors.append(f"Subnet '{name}' has an empty addressPrefix.")
            continue

        try:
            snet_net = ipaddress.IPv4Network(prefix, strict=strict_canonical)
        except ipaddress.NetmaskValueError as e:
            errors.append(f"Subnet '{name}' has an invalid netmask: {e}")
            continue
        except ValueError as e:
            if "has host bits set" in str(e):
                errors.append(f"Subnet '{name}' prefix '{prefix}' is non-canonical (host bits are set).")
            else:
                errors.append(f"Subnet '{name}' has an invalid IPv4 CIDR '{prefix}': {e}")
            continue

        # Azure subnet prefix length constraints: /8 to /29
        # /30, /31, /32 are unsupported because Azure reserves 5 IP addresses per subnet
        if snet_net.prefixlen < 8 or snet_net.prefixlen > 29:
            errors.append(
                f"Subnet '{name}' prefix /{snet_net.prefixlen} is unsupported by Azure. "
                f"Azure subnets must be between /8 and /29 (smallest allowed is /29)."
            )

        # Reserved Azure Subnet sizing check
        if name in RESERVED_SUBNET_MIN_PREFIX:
            min_p = RESERVED_SUBNET_MIN_PREFIX[name]
            if snet_net.prefixlen > min_p:
                errors.append(
                    f"Reserved subnet '{name}' requires a minimum prefix length of /{min_p} "
                    f"(got /{snet_net.prefixlen})."
                )

        # Containment check: subnet must be fully within VNet address space
        if not snet_net.subnet_of(vnet_net):
            errors.append(
                f"Subnet '{name}' ({snet_net}) is not contained within VNet address space {vnet_net}."
            )

        # Overlap check: compare against all previously parsed subnets
        for prev_name, prev_net in parsed_subnets:
            if snet_net.overlaps(prev_net):
                errors.append(
                    f"Subnet '{name}' ({snet_net}) overlaps with subnet '{prev_name}' ({prev_net})."
                )

        parsed_subnets.append((name, snet_net))

    is_valid = len(errors) == 0
    return is_valid, errors

def calculate_vnet_capacity(
    vnet_address_spaces: List[str],
    subnets: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Calculates detailed address space capacity metrics for a VNet and its subnets:
    - total_addresses: Total IP address capacity across all VNet address spaces
    - allocated_addresses: Total IP addresses allocated across subnets
    - unallocated_addresses: Remaining free IP addresses
    - allocation_percentage: Percentage of address space allocated (0.0 to 100.0)
    - is_fully_allocated: True if 0 unallocated addresses remain
    - can_fit_min_azure_subnet: True if unallocated >= 8 (minimum /29 subnet)
    - capacity_status: 'Fully Allocated', 'Partially Allocated', 'Empty', or 'Exhausted'
    """
    total_ips = 0
    vnet_nets = []
    for vp in vnet_address_spaces:
        if not vp or not isinstance(vp, str):
            continue
        try:
            v_net = ipaddress.IPv4Network(vp.strip(), strict=False)
            total_ips += v_net.num_addresses
            vnet_nets.append(v_net)
        except ValueError:
            pass

    allocated_ips = 0
    for s in subnets:
        props = s.get("properties", {})
        prefixes = []
        if props.get("addressPrefix"):
            prefixes.append(props["addressPrefix"])
        if props.get("addressPrefixes"):
            for p in props["addressPrefixes"]:
                if p not in prefixes:
                    prefixes.append(p)
        if not prefixes and s.get("addressPrefix"):
            prefixes.append(s["addressPrefix"])

        for p in prefixes:
            if not p or not isinstance(p, str):
                continue
            try:
                s_net = ipaddress.IPv4Network(p.strip(), strict=False)
                allocated_ips += s_net.num_addresses
            except ValueError:
                pass

    unallocated_ips = max(0, total_ips - allocated_ips)
    alloc_pct = (allocated_ips / total_ips * 100.0) if total_ips > 0 else 0.0

    is_fully = (unallocated_ips == 0) and (total_ips > 0)
    can_fit_min = unallocated_ips >= 8  # /29 is smallest Azure subnet

    if total_ips == 0:
        status = "Unknown / Invalid VNet CIDR"
    elif allocated_ips == 0:
        status = "Empty (100% Available)"
    elif is_fully:
        status = "Fully Allocated (0 Addresses Available)"
    elif not can_fit_min:
        status = f"Exhausted ({unallocated_ips} IPs remaining, < Azure minimum /29)"
    else:
        status = f"Partially Allocated ({unallocated_ips} IPs unallocated, {100.0 - alloc_pct:.1f}% free)"

    return {
        "total_addresses": total_ips,
        "allocated_addresses": allocated_ips,
        "unallocated_addresses": unallocated_ips,
        "allocation_percentage": round(alloc_pct, 1),
        "is_fully_allocated": is_fully,
        "can_fit_min_azure_subnet": can_fit_min,
        "capacity_status": status
    }

def run_test_suite() -> bool:
    """Executes the mandatory 8 test cases from Sprint 1.1 Section 5."""
    print("======================================================================")
    print(" Deterministic Network Math & CIDR Containment Test Suite")
    print("======================================================================")

    test_cases = [
        {
            "id": "TC-NET-01",
            "name": "Standard valid subnet containment",
            "vnet": "10.20.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.20.1.0/24"}],
            "expected_valid": True,
            "description": "VNet 10.20.0.0/16, subnet 10.20.1.0/24 -> Accept"
        },
        {
            "id": "TC-NET-02",
            "name": "Subnet outside VNet address space",
            "vnet": "10.20.0.0/16",
            "subnets": [{"name": "snet-workload", "addressPrefix": "10.21.1.0/24"}],
            "expected_valid": False,
            "description": "VNet 10.20.0.0/16, subnet 10.21.1.0/24 -> Reject"
        },
        {
            "id": "TC-NET-03",
            "name": "Two identical subnet CIDRs",
            "vnet": "10.20.0.0/16",
            "subnets": [
                {"name": "snet-1", "addressPrefix": "10.20.1.0/24"},
                {"name": "snet-2", "addressPrefix": "10.20.1.0/24"}
            ],
            "expected_valid": False,
            "description": "Two identical subnet CIDRs -> Reject"
        },
        {
            "id": "TC-NET-04",
            "name": "Two partially overlapping subnets",
            "vnet": "10.20.0.0/16",
            "subnets": [
                {"name": "snet-parent", "addressPrefix": "10.20.0.0/24"},
                {"name": "snet-child", "addressPrefix": "10.20.0.128/25"}
            ],
            "expected_valid": False,
            "description": "Two partially overlapping subnets -> Reject"
        },
        {
            "id": "TC-NET-05",
            "name": "Duplicate subnet names",
            "vnet": "10.20.0.0/16",
            "subnets": [
                {"name": "snet-dup", "addressPrefix": "10.20.1.0/24"},
                {"name": "snet-dup", "addressPrefix": "10.20.2.0/24"}
            ],
            "expected_valid": False,
            "description": "Duplicate subnet names -> Reject"
        },
        {
            "id": "TC-NET-06",
            "name": "Invalid IPv4 octet (> 255)",
            "vnet": "10.256.0.0/16",
            "subnets": [{"name": "snet-1", "addressPrefix": "10.256.1.0/24"}],
            "expected_valid": False,
            "description": "Invalid IPv4 octet -> Reject"
        },
        {
            "id": "TC-NET-07",
            "name": "Noncanonical network prefix (host bits set)",
            "vnet": "10.20.0.0/16",
            "subnets": [{"name": "snet-1", "addressPrefix": "10.20.1.5/24"}],
            "expected_valid": False,
            "description": "Noncanonical network prefix -> Handle explicitly and consistently (Reject)"
        },
        {
            "id": "TC-NET-08",
            "name": "Azure-unsupported subnet prefix (/30)",
            "vnet": "10.20.0.0/16",
            "subnets": [{"name": "snet-1", "addressPrefix": "10.20.1.0/30"}],
            "expected_valid": False,
            "description": "Azure-unsupported subnet prefix (/30) -> Reject"
        }
    ]

    all_passed = True
    for tc in test_cases:
        is_valid, errors = validate_network_configuration(tc["vnet"], tc["subnets"])
        test_passed = (is_valid == tc["expected_valid"])
        status = "[PASS]" if test_passed else "[FAIL]"
        print(f"{status} {tc['id']}: {tc['description']}")
        if not test_passed:
            all_passed = False
            print(f"       Expected valid={tc['expected_valid']}, got {is_valid}")
            print(f"       Reported errors: {errors}")
        else:
            if errors:
                print(f"       Expected rejection reason: {errors[0]}")
            else:
                print("       Successfully accepted valid configuration.")

    print("----------------------------------------------------------------------")
    print(f" NETWORK VALIDATION SUITE: {'ALL 8 TESTS PASSED' if all_passed else 'FAILURES DETECTED'}")
    print("======================================================================")
    return all_passed

if __name__ == "__main__":
    success = run_test_suite()
    sys.exit(0 if success else 1)
