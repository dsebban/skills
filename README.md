# OMP skills

OMP-native orchestration and pstack adapters for the [`omp`](https://omp.sh/) coding agent.

## Included skills

| Skill | Purpose |
|---|---|
| `poteto-mode` | Routes substantial work to the matching pstack playbook. Nested links name their owning skill explicitly. |
| `pstack-omp` | Maps pstack roles and lifecycle protocols to OMP task agents, batches, IRC, and result resources. |
| `orchestrate-omp` | Coordinates parallel scouts, scoped workers, specialist reviews, and root-owned verification. |
| `writing-for-agents` | Defines the OMP discovery and prose contract for agent-facing skills. |

The repository also includes optional `poteto-agent` and `comment-sicko` definitions under `agents/`.

## Requirements

- OMP 17.3.5 or newer.
- OMP skill discovery from `~/.agents/skills` enabled.
- The pstack workflow and principle skills referenced by the selected `poteto-mode` playbook. This repository contains the OMP router and adapter, not the complete upstream pstack catalog.

## Install the skills

Install all four skills globally with the [`skills`](https://skills.sh/) CLI:

```bash
npx skills add dsebban/skills \
  --skill poteto-mode pstack-omp orchestrate-omp writing-for-agents \
  --global --yes
```

Merge only these `skills` keys into `~/.omp/agent/config.yml`. Keep model, provider, `modelRoles`, `task.agentModelOverrides`, and unrelated settings unchanged.

```yaml
skills:
  enableAgentsUser: true
  ignoredSkills:
    - Poteto Mode
```

Start a new OMP process after changing the skill settings. Existing sessions retain their previous skill inventory.

## Audit skill references

Run the offline audit from a repository checkout:

```bash
python3 scripts/audit_skill_references.py
```

The audit checks exact skill URIs and bold lowercase named dependencies against the repository and the installed user skill roots. A nested external URI fails as ambiguous when multiple installed skills declare the same name.

## Install the optional agents

Clone this repository, then place the agent definitions in OMP's user agent directory:

```bash
git clone https://github.com/dsebban/skills.git
cd skills
mkdir -p ~/.omp/agent/agents
cp agents/poteto-agent.md ~/.omp/agent/agents/
cp agents/comment-sicko.md ~/.omp/agent/agents/
```

The standard `pstack-omp` role map does not require these agents. They support imported workflows that call the compatibility names directly.

## Use the skills

OMP resolves the skills by these exact names:

```text
skill://poteto-mode
skill://pstack-omp
skill://orchestrate-omp
skill://writing-for-agents
```

Nested pstack files use the owning skill URI:

```text
skill://poteto-mode/playbooks/babysit.md
skill://poteto-mode/references/plan.md
```

Nested references must include the exact owning skill name. Display labels and path-only roots do not resolve.

## OMP task behavior

- Use the exact agent names in the live `task` inventory.
- Omit `agent` to select OMP's default worker.
- Use `tasks[]`, `context`, `effort`, and `isolated` only when the live task schema exposes them.
- Treat child sessions as fresh context. Put the goal, constraints, ownership, acceptance criteria, and leaf-agent boundary in every assignment.
- Read complete results from `agent://<id>` and transcripts from `history://<id>` when needed.
- Keep user interaction, approvals, integration, and final verification with the root coordinator.

## Provenance

- `poteto-mode` is adapted from Lauren Tan's [`pstack`](https://github.com/cursor/plugins/tree/main/pstack), version 0.14.1.
- `orchestrate-omp` is adapted from Eric Provencher's [`orchestrate`](https://github.com/provencher/codex-skills/tree/main/orchestrate) skill.
- `pstack-omp` and the OMP-specific integration are maintained in this repository.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for upstream copyright notices.

## License

MIT. See [`LICENSE`](LICENSE).
