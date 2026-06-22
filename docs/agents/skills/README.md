# Agent Skills

This repository currently defines one custom skill:

- [`stack-change`](stack-change/SKILL.md) - use when changing Compose services, ports, credentials, model names, metrics, logs, RAG behavior, or the Rust Codex RAG demo service.

When a repeatable workflow is ready to become a skill, create:

```text
docs/agents/skills/<skill-name>/SKILL.md
```

Use this minimum structure:

```markdown
# Skill Name

## Trigger

When an agent should use this skill.

## Inputs

Required files, settings, or user-provided details.

## Steps

The procedure to follow.

## Verification

Commands or observable outcomes that prove the work is done.

## Handoff

What to report back to the user.
```

Skills must defer to the root `AGENTS.md` for repository-wide rules.
