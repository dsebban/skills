---
name: writing-for-agents
description: Write and review agent-facing skills, playbooks, agent definitions, and task briefs as compact executable contracts. Use whenever authoring or modifying a SKILL.md file.
disable-model-invocation: true
---

# Writing for agents

Read `skill://technical-writing` and `skill://unslop` before drafting agent-facing prose.

## Write an executable contract

1. State the trigger and required action first.
2. Name the actor, inputs, writable scope, forbidden work, stop condition, and returned evidence when the workflow needs them.
3. Write one decision-changing instruction per sentence. Use imperative verbs.
4. Name exact files, commands, data shapes, ownership boundaries, and observable checks.
5. State precedence when instructions can conflict. Use RFC 2119 terms only for requirements.
6. Keep a reason only when an agent could otherwise choose the wrong branch.
7. Delete introductions, praise, repeated summaries, and rationale that changes no decision.

Do not ask a child to rediscover the parent plan. Give the child every fact it needs and no authority it does not have.

## Follow OMP's discovery contract

- Treat the frontmatter `name` as the exact, case-sensitive identifier. The directory name and display label do not replace it.
- Write the frontmatter `description` as a routing rule. State when the skill applies and what work it governs.
- Reference another skill by its exact root URI, such as `skill://writing-for-agents`.
- Reference a nested file through its owning skill, such as `skill://poteto-mode/playbooks/opening-a-pr.md`.
- Never use path-only roots, case-folded names, display labels, or placeholder URI segments.
- Use bold lowercase slugs only for named skill dependencies. Follow a principle shorthand with `principle skill` so the audit can resolve its `principle-` name.

Delegate shared behavior by URI. Do not copy another skill's procedure into the new skill.

## Verify the result

1. Confirm that frontmatter contains `name` and `description`.
2. Confirm that every referenced local file exists.
3. In a `dsebban/skills` checkout, run `python3 scripts/audit_skill_references.py`.
4. Outside this repository, run the owning repository's reference audit when it provides one.
5. Run the owning project's narrow structural test when the skill adds a parser or another executable rule.
6. Read the changed prose once for conflicting instructions, unreachable stop conditions, and duplicated rules.

Return the changed contract, the exact checks run, and any unresolved dependency. Do not claim that a skill resolves until a fresh process loads it.
