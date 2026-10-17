---
name: asw-loop
description: Antigravity Swarm autonomous execution loop with specialist delegation, adaptive verification, and diff review.
---

# Antigravity Swarm Execution Loop

Use this skill when executing a coding task, bug fix, feature implementation, refactoring, or script update through Antigravity CLI.

The Primary AGY session acts as the autonomous owner and implementer, driving the task from initial scoping to final verified completion.

## Zero-Handoff Rule

- **Never Halt After Planning**: In this autonomous mode, planning is strictly an internal step. Do not halt after creating a plan or strategy; immediately begin implementation in the working tree.
- **Never Hand Off to Other Skills**: Never output `Next: /asw-start-work`, `Next: start-work`, `Next: /asw-review`, or tell the user to manually trigger another skill.
- **Single Continuous Turn**: Execute all steps continuously in this session until the task is complete and verified.

## Autonomous Loop Steps

1. **Scope & Plan**: Identify the observable objective, key files, and success criteria. Formulate the execution plan internally.
2. **Specialist Investigation (Read-Only)**:
   - When repository structure is unfamiliar: delegate to `asw-explorer` via `invoke_subagent`.
   - When external APIs or documentation are required: delegate to `asw-librarian` via `invoke_subagent`.
   - When targeted 1-2 file lookups suffice: inspect directly in the primary session.
3. **Primary Implementation**:
   - Implement all changes directly in the workspace using `write_to_file` and `replace_file_content`.
   - Keep dependent edits in the primary thread to maintain file ownership.
4. **Adaptive Verification**:
   - For bug fixes: Capture failing test or reproduction (RED) -> implement fix -> capture passing output (GREEN).
   - For new features: Write tests covering normal and edge cases -> implement -> capture passing output.
   - For refactors: Run existing tests before and after to prove behavior preservation.
   - For configs/packaging/scripts: Run commands, validate syntax, dry-run, and check real output.
   - Run adjacent regression tests.
5. **Review Gate**:
   - For non-trivial or multi-file changes: delegate diff and evidence review to `asw-reviewer` via `invoke_subagent`.
   - Address any reviewer findings directly in the primary session and re-verify.
6. **Completion**:
   - Ensure all spawned resources/sessions are cleaned up.
   - Deliver the final report with concrete verification evidence.

## Evidence & Verification Principles

- Never claim completion without proof.
- Tests and verification commands must be executed and their outputs observed.
- Keep the primary context lean by relying on subagents for large exploratory searches and receiving only their distilled findings.

## Final Output

```text
ASW COMPLETE
Outcome: <summary>
Files Changed:
- [path](file:///path): <change summary>
Verification:
- <command>: <output proof>
Reviewer: <Approved / Remediated>
Residual Risk: <notes>
```
