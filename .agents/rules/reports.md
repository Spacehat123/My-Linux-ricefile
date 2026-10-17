---
trigger: always_on
description: Mandatory rule to save all investigation, architecture, audit, and review reports to .asw/reports/
---

# Reports Storage Policy

Every report produced during investigation, architectural review, audit, exploration, or post-work verification MUST be saved as a markdown document in `.asw/reports/`:

- **Location**: `.asw/reports/`
- **Naming Convention**: `YYYY-MM-DD-<topic>.md` (e.g. `.asw/reports/2026-09-29-cool-shell-architectural-review.md`)
- **Format**: Complete, unabridged markdown with full sections, exact code references, and verification matrices.
- **Rule**: Whenever any agent produces a formal report for the user, it must write the full document to `.asw/reports/` in addition to presenting it in conversation.
