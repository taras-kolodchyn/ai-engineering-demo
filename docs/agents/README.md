# Agent Instruction Infrastructure

This directory is reserved for agent-facing operational instructions that are more specific than the root `AGENTS.md`.

## Structure

- `../../AGENTS.md` - repository-wide rules for all AI agents.
- `roles/` - future role-specific playbooks, such as demo maintainer, observability reviewer, or docs editor.
- `skills/` - reusable task procedures with triggers, steps, and verification.

## Change Policy

Use the smallest instruction surface that fits:

- Put global repository rules in `AGENTS.md`.
- Put role-specific behavior in `roles/`.
- Put repeatable task procedures in `skills/`.

Do not create a custom skill until the workflow is repeated enough to justify a maintained procedure. The current `skills/stack-change/` procedure covers stack, RAG, observability, and Rust service changes.

## Quality Bar

Agent instructions should be:

- Concrete enough to execute without guessing.
- Short enough to be read before work starts.
- Tied to real files, commands, and verification checks in this repository.
- Free of real secrets and private environment assumptions. Committed `admin` / `admin` demo credentials are allowed for this lecture stack.
