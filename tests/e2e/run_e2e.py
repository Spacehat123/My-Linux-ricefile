#!/usr/bin/env python3
"""
Master E2E Test Suite Runner for cool-shell Optimization & Capability Enhancement.
CLI Flags:
  --tier {1,2,3,4,all}   Execute tests in specified tier (default: all)
  --filter PATTERN        Filter tests by ID, feature, or description regex
  --json-report PATH      Save execution report to JSON file
  --verbose, -v           Enable verbose diagnostics output
  --summary               Display test suite overview and exit (or summary table)
  --list                  List all registered test cases without running
"""

import sys
import os
import re
import argparse
import json
import time
from pathlib import Path

# Add project root to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent.parent
sys.path.insert(0, str(PROJECT_DIR))
sys.path.insert(0, str(SCRIPT_DIR))

from framework import registry, TestResult

# Import test suites to populate registry
try:
    import test_tier1_features
except ImportError as e:
    pass

try:
    import test_tier2_boundaries
except ImportError as e:
    pass

try:
    import test_tier3_interactions
except ImportError as e:
    pass

try:
    import test_tier4_scenarios
except ImportError as e:
    pass

# Terminal colors
COLOR_RESET = "\033[0m"
COLOR_BOLD = "\033[1m"
COLOR_RED = "\033[31m"
COLOR_GREEN = "\033[32m"
COLOR_YELLOW = "\033[33m"
COLOR_CYAN = "\033[36m"
COLOR_GRAY = "\033[90m"


def format_status(status: str) -> str:
    if status == "PASS":
        return f"{COLOR_GREEN}{COLOR_BOLD}PASS{COLOR_RESET}"
    elif status == "FAIL":
        return f"{COLOR_RED}{COLOR_BOLD}FAIL{COLOR_RESET}"
    elif status == "SKIP":
        return f"{COLOR_YELLOW}{COLOR_BOLD}SKIP{COLOR_RESET}"
    else:
        return f"{COLOR_RED}{COLOR_BOLD}ERR {COLOR_RESET}"


def parse_args():
    parser = argparse.ArgumentParser(
        description="E2E Acceptance Test Runner for cool-shell Optimization & Capability Enhancement",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--tier",
        choices=["1", "2", "3", "4", "all"],
        default="all",
        help="Select which test tier to execute (default: all)",
    )
    parser.add_argument(
        "--filter",
        metavar="PATTERN",
        help="Regex pattern to filter tests by ID, feature, or description",
    )
    parser.add_argument(
        "--json-report",
        metavar="PATH",
        help="Write test results in JSON format to specified file",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Display verbose diagnostics and stack traces",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Show summary overview of registered tests and exit without running",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all registered test cases and exit",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    selected_tier = None
    if args.tier != "all":
        selected_tier = int(args.tier)

    try:
        tests = registry.get_tests(tier=selected_tier, filter_pattern=args.filter)
    except (re.error, ValueError) as e:
        print(f"{COLOR_RED}run_e2e.py: error: invalid regular expression for --filter '{args.filter}': {e}{COLOR_RESET}", file=sys.stderr)
        sys.exit(2)

    if args.summary:
        print(f"\n{COLOR_CYAN}{COLOR_BOLD}=== COOL-SHELL E2E TEST SUITE SUMMARY ==={COLOR_RESET}")
        total = registry.count
        t1 = len(registry.get_tests(tier=1))
        t2 = len(registry.get_tests(tier=2))
        t3 = len(registry.get_tests(tier=3))
        t4 = len(registry.get_tests(tier=4))
        print(f"Total Registered Tests: {total}")
        print(f"  - Tier 1 (Feature Coverage):            {t1} / 60")
        print(f"  - Tier 2 (Boundaries & Corner Cases):   {t2} / 60")
        print(f"  - Tier 3 (Cross-Feature Combinations):  {t3} / 15")
        print(f"  - Tier 4 (Real-World Scenarios):         {t4} / 6")
        if args.filter or selected_tier is not None:
            print(f"Matched by Filter/Tier:                 {len(tests)}")
        print(f"{COLOR_CYAN}==========================================={COLOR_RESET}\n")
        sys.exit(0)

    if args.list:
        print(f"\n{COLOR_CYAN}{COLOR_BOLD}=== REGISTERED TEST CASES ({len(tests)}) ==={COLOR_RESET}")
        for t in tests:
            print(f"  [{t.test_id}] (Tier {t.tier}, {t.feature}) {t.description}")
        sys.exit(0)

    if not tests:
        if args.filter:
            print(f"{COLOR_YELLOW}No tests matched the specified filter: {args.filter!r}{COLOR_RESET}", file=sys.stderr)
            sys.exit(1)
        print(f"{COLOR_YELLOW}No tests matched the specified criteria.{COLOR_RESET}")
        sys.exit(0)

    print(f"\n{COLOR_CYAN}{COLOR_BOLD}========================================================================{COLOR_RESET}")
    print(f"{COLOR_CYAN}{COLOR_BOLD}   COOL-SHELL E2E ACCEPTANCE TEST SUITE (TIERS 1 - 4)                    {COLOR_RESET}")
    print(f"{COLOR_CYAN}{COLOR_BOLD}========================================================================{COLOR_RESET}")
    print(f"Running {len(tests)} test(s) [Tier: {args.tier}, Filter: {args.filter or 'none'}]...\n")

    results = []
    passed = 0
    failed = 0
    errors = 0
    skipped = 0
    start_suite_time = time.perf_counter()

    current_tier = None
    for idx, test in enumerate(tests, 1):
        if test.tier != current_tier:
            current_tier = test.tier
            tier_names = {
                1: "Tier 1: Feature Coverage (Isolated Functional Validation)",
                2: "Tier 2: Boundary & Corner Cases (Error Handling & Edge Values)",
                3: "Tier 3: Cross-Feature Combinations (Pairwise Interaction)",
                4: "Tier 4: Real-World Application Workloads & Scenarios",
            }
            print(f"\n{COLOR_BOLD}{COLOR_CYAN}--- {tier_names.get(current_tier, f'Tier {current_tier}')} ---{COLOR_RESET}")

        result = test.run()
        results.append(result)

        if result.status == "PASS":
            passed += 1
        elif result.status == "FAIL":
            failed += 1
        elif result.status == "SKIP":
            skipped += 1
        else:
            errors += 1

        status_str = format_status(result.status)
        dur_str = f"{COLOR_GRAY}({result.duration:.3f}s){COLOR_RESET}"
        print(f"  [{status_str}] {COLOR_BOLD}{result.test_id}{COLOR_RESET}: {result.description} {dur_str}")

        if result.status in ("FAIL", "ERROR"):
            msg_indent = " " * 9
            print(f"{msg_indent}{COLOR_RED}Reason: {result.message}{COLOR_RESET}")
            if args.verbose and result.details:
                print(f"{msg_indent}{COLOR_GRAY}Details: {result.details}{COLOR_RESET}")

    suite_duration = time.perf_counter() - start_suite_time

    # Output JSON Report if requested
    if args.json_report:
        report_data = {
            "summary": {
                "total": len(tests),
                "passed": passed,
                "failed": failed,
                "errors": errors,
                "skipped": skipped,
                "duration_seconds": round(suite_duration, 4),
                "all_passed": (failed == 0 and errors == 0),
            },
            "tests": [r.to_dict() for r in results],
        }
        report_path = Path(args.json_report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w") as f:
            json.dump(report_data, f, indent=2)
        print(f"\nReport written to: {report_path.resolve()}")

    # Final Summary Banner
    print(f"\n{COLOR_CYAN}{COLOR_BOLD}========================================================================{COLOR_RESET}")
    print(f"{COLOR_CYAN}{COLOR_BOLD}   E2E EXECUTION SUMMARY                                                {COLOR_RESET}")
    print(f"{COLOR_CYAN}{COLOR_BOLD}========================================================================{COLOR_RESET}")
    print(f"  Total Executed : {len(tests)}")
    print(f"  Passed         : {COLOR_GREEN}{passed}{COLOR_RESET}")
    print(f"  Failed         : {COLOR_RED}{failed}{COLOR_RESET}")
    print(f"  Errors         : {COLOR_RED}{errors}{COLOR_RESET}")
    print(f"  Skipped        : {COLOR_YELLOW}{skipped}{COLOR_RESET}")
    print(f"  Duration       : {suite_duration:.2f}s")
    print(f"{COLOR_CYAN}========================================================================{COLOR_RESET}\n")

    if failed > 0 or errors > 0:
        print(f"{COLOR_RED}{COLOR_BOLD}❌ RESULT: TEST SUITE FAILED ({failed + errors} failure(s)){COLOR_RESET}\n")
        sys.exit(1)
    else:
        print(f"{COLOR_GREEN}{COLOR_BOLD}✅ RESULT: ALL TESTS PASSED SUCCESSFULLY{COLOR_RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
