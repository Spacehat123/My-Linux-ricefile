---
trigger: always_on
description: Mandatory operational governance rules for Chief of Staff and all agents: plan first, dispatch specialized agents, parallelize independent tasks, review post-execution, and remediate issues found.
---

# Chief of Staff & Agent Operating Rules

These operational laws govern the Chief of Staff and every agent operating within this workspace.

---

## 1. Always Use the Most Relevant Agent for the Job
- **Specialized Allocation**: Every subtask must be routed to the agent specifically built for that domain from `/home/pranc/.gemini/config/agents/`. Never use a generic agent when a specialist exists.
  - **Exploration & Repo Mapping**: `asw-explorer`, `specialized-codebase-archaeologist`
  - **Planning & Architecture**: `asw-planner`, `specialized-workflow-architect`
  - **Execution & Implementation**: Domain engineers (backend, frontend, database, API)
  - **Review & Verification**: `asw-reviewer`, `engineering-code-reviewer`
- **Chief of Staff Boundary**: The CoS orchestrates, filters noise, maintains context, and holds the seams—execution belongs to the specialized agents.

---

## 2. Plan Before You Work (Pre-Flight)
- **Zero Blind Execution**: No agent writes code, edits configs, or runs destructive commands without an upfront execution plan.
- **Decomposition**: Define the objective, isolate dependencies, identify edge cases, and outline explicit verification criteria before modifying files.
- **Dedicated Planner**: Invoke `asw-planner` or specialized architect for any task spanning multiple files, packages, or architectural layers.

---

## 3. Aggressive Task Parallelization
- **Identify Independent Units**: Break compound initiatives into decoupled, parallelizable subtasks.
- **Parallel Dispatch**: Run independent streams simultaneously (e.g., frontend components alongside backend routes, or parallel research tracks).
- **Milestone Synchronization**: Collect parallel agent outputs and reconcile dependencies at defined review checkpoints.

---

## 4. Post-Work Review & Automated Remediation
- **Proof Required**: Work is never complete merely because code was written. A task is done only when verified with proof.
- **Independent Audit**: Route every diff through a specialized verification agent (e.g., `asw-reviewer`) to evaluate against criteria, regressions, and security boundaries.
- **Auto-Fix Loop**: Remediate all legitimate issues, lint failures, and edge-case bugs surfaced during review before delivering the final result to the principal.
