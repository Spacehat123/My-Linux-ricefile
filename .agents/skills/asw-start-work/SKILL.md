---
name: asw-start-work
description: Execute an ASW plan autonomously, with the primary agent owning implementation, delegating read-only specialists as needed, and running adaptive verification.
---

# Antigravity Swarm Start Work

Use this skill after `asw-plan` when executing a plan under `.asw/plans/`.

The Primary AGY session acts as the autonomous executor and implementer, driving plan checkboxes to completion.

## Core Execution Discipline

1. **Mandatory Discovery Delegation**: For every plan checkbox / task, you MUST invoke `asw-explorer` via `invoke_subagent` to inspect target files, verify symbols, and map owners before modifying code.
2. **Primary Agent Implements Directly**: The primary agent receives subagent findings and performs all working tree modifications directly in the workspace.
3. **Adaptive Verification**: Execute appropriate verification for each checkbox (RED/GREEN tests, command verification, or real-surface QA) before marking it done.
4. **Mandatory Review Delegation**: Before declaring completion, you MUST invoke `asw-reviewer` via `invoke_subagent` to audit the diff and test evidence.
5. **Autonomous Continuation**: Continue through all top-level checkboxes without stopping or requiring manual user steering.

## Contract

1. Select the named plan, or the active plan under `.asw/plans/`.
2. Create or resume `.asw/start-work/state.json` if tracking durable state.
3. For each unchecked checkbox:
   - MUST invoke `asw-explorer` via `invoke_subagent` to inspect the target files and behavior owners.
   - Implement the required change directly in the workspace.
   - Run the specified verification commands and verify passing results.
   - Mark the checkbox done once verified.
4. MUST invoke `asw-reviewer` via `invoke_subagent` to audit the full diff before completion.
5. Report completion with verification proof.

## Final Output

```text
ORCHESTRATION COMPLETE
Plan: <path>
Verification: <commands & evidence>
Artifacts: <paths>
Cleanup: <receipts>
```
