# Agent Roles

No custom agent roles are defined yet.

When a role is needed, create a focused Markdown file in this directory. Use this shape:

```markdown
# Role Name

## Mission

What this role is responsible for.

## Scope

Files, services, or workflows this role may change.

## Inputs

Information the role needs before starting.

## Working Rules

Specific behavior beyond the root AGENTS.md rules.

## Verification

Commands or checks required before handoff.
```

Prefer one narrow role over a broad, vague one.
