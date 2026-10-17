# Anti-Slop Coding Guidelines

To ensure high-quality contributions and prevent triggering the project's strict `anti-slop` GitHub action, all AI agents must adhere to the following principles when writing code, making commits, and creating pull requests:

## 1. Zero-Slop Communication
- **No AI Filler/Yapping**: Do not generate long-winded, repetitive, or generic summaries for PR descriptions, commit messages, or comments.
- **Concise & Direct**: Explain the "what" and "why" exactly to the point without filler words. Keep descriptions well under the 2500 character limit.

## 2. Minimal & Targeted Diffs
- **No Unnecessary File Changes**: Never modify files outside the direct scope of the task (e.g., do not randomly touch `README.md`, `LICENSE`, or reformat unrelated files).
- **No Ghost Code**: Do not write unused functions, unnecessary abstractions, or "future-proofing" imports. Keep abstractions minimal.
- **Vertical Slices**: Keep pull request sizes small and manageable.

## 3. Strict Conventional Commits
- **Format**: All commits must follow Conventional Commits (e.g., `feat:`, `fix:`, `refactor:`, `chore:`).
- **Length limit**: Keep commit message headers concise (under 72 characters) and total message length under 500 characters.
- **Accuracy**: Ensure the commit author name matches the expected format, and the message accurately reflects the changes.

## 4. Code Quality
- **Explicit over Clever**: Prefer explicit, readable code over overly clever or complex one-liners.
- **Final Newlines**: Ensure all files end with a final newline character.
- **No Over-commenting**: Write meaningful code that explains itself. Limit inline comments to explaining complex business logic; avoid narrating what each line does.

Adherence to these rules prevents PRs from being automatically closed and respects maintainers' time.
