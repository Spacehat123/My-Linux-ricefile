---
name: anti-slop
description: Review code, write commits, and clean up codebases using strict anti-slop principles.
---

# Anti-Slop Code Skill

## Purpose
Activate this skill when the user asks you to audit code, prepare a Pull Request, write commit messages, or sanitize a branch. It enforces the rules of the `anti-slop` GitHub action directly during the coding phase.

## Instructions
When executing an anti-slop review or generation, follow these steps strictly:

### 1. Code Review & Cleanup
- **Remove Ghost Code**: Delete unused functions, redundant abstractions, and "future-proofing" logic that isn't immediately required.
- **Enforce Explicitness**: Refactor overly clever or convoluted code into simple, explicit, and readable statements.
- **Strip Yapping**: Remove excessive inline comments that narrate what the code does. Keep only comments that explain *why* complex business logic exists.
- **Targeted Diffs**: Revert any files modified unnecessarily (like config files, READMEs, or unrelated modules) that aren't strictly part of the current feature scope.

### 2. Commit & PR Generation
- **Conventional Commits**: Always format commits using Conventional Commits (e.g., `feat:`, `fix:`, `refactor:`, `chore:`).
- **Length Limits**: Keep commit headers under 72 characters. Keep the entire commit message body under 500 characters.
- **Zero Filler**: Do not use generic AI summaries ("This PR introduces several enhancements..."). State exactly what was changed and why.

## Verification
Before completing the skill:
- Run a final review of the diff to ensure it is minimal.
- Ensure all files end with a trailing newline.
