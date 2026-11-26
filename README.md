# OMP skills

An OMP port of the [pstack](https://github.com/cursor/plugins/tree/main/pstack) skill catalog, plus the
OMP-native adapters that make it run on [`omp`](https://omp.sh/).

Upstream pstack targets Cursor. This repository tracks it and rewrites every host mechanism for OMP:
`task` batches instead of Cursor `Task` calls, agents instead of per-call model slugs, `skill://` instead of
relative paths, `agent://` and `history://` instead of cloud-agent URLs.

## Catalog

| Group | Skills |
|---|---|
| Router | `poteto-mode` routes substantial work to the matching playbook. Start here. |
| OMP adapters | `pstack-omp` maps canonical pstack roles and lifecycle protocols to OMP task agents. `orchestrate-omp` coordinates subagents on program-scale work. `setup-pstack` configures which model each role and agent runs on. |
| Understanding | `how`, `why`, `interrogate`, `blast-radius`, `recall`, `ketchup`, `in-your-own-words`, `teach` |
| Design and exploration | `architect`, `arena`, `swarm`, `figure-it-out`, `sharpen`, `reflect` |
| Execution | `tdd`, `correct`, `bro`, `show-me-your-work`, `benchmark-checklist`, `automate-me` |
| Writing | `unslop`, `technical-writing`, `no-comments` |
| Verification | `create-verification-skill`, `maintain-verification-skill`, `create-formal-verification-skill`, `maintain-formal-verification-skill` |
| Review | `fable-deslop` shrinks an oversized patch with the RepoPrompt CE context builder and its Oracle lanes |
| Language | `typescript-best-practices` |
| Bots | `make-bot-ui` |
| Help | `poteto-help` |
| Principles | 24 `principle-*` leaves cited by the playbooks |

`agents/` holds two optional subagent definitions, `poteto-agent` and `comment-sicko`, for imported
workflows that call those names directly.


## Standalone skills

- [`hosting-simplepod-models`](hosting-simplepod-models/): rent a SimplePod GPU, serve an open-weight GGUF model with Strata, expose it over Tailscale Funnel HTTPS, and pick it as a model in Amp. Install with `amp skill add --global dsebban/skills/hosting-simplepod-models`.

## Requirements

- OMP 18.10.4 or newer.
- Bun, for the `poteto-mode` scripts.
- `gh`, for the PR playbooks.
- RepoPrompt CE and its `rpce-cli`, for `fable-deslop`.
- `trash`, for the worktree-cleanup playbook.

## Install

Clone the repository and point OMP at its `skills/` directory:

```bash
git clone https://github.com/dsebban/skills.git ~/dev/skills
```

```yaml
# ~/.omp/agent/config.yml
skills:
  customDirectories:
    - ~/dev/skills/skills
```

The clone stays live, so `git pull` updates every skill at once.

Install the optional agents by copying them into OMP's user agent directory:

```bash
mkdir -p ~/.omp/agent/agents
cp ~/dev/skills/agents/*.md ~/.omp/agent/agents/
```

Start a new OMP process after either change. Existing sessions keep their previous inventory.

## Configure models

OMP routes models by role, not per call. Run this once:

```text
/skill:setup-pstack
```

It detects the available catalog, asks for a reasoning budget, and writes `modelRoles` and
`task.agentModelOverrides` into the active profile's `config.yml` after validating every selector. It also
reports when two panel agents resolve to the same model, which is the difference between a second opinion
and self-review.

## Use

Start with `/skill:poteto-mode` and describe the work; it routes to the matching playbook and pulls in the
skills that playbook needs. Every skill is also directly invocable as `/skill:<name>`.

Upstream marks the catalog `disable-model-invocation: true`, and this port keeps that. The model does not
pick these skills up on its own; the user invokes them, or `poteto-mode` routes to them. Three skills are
the exceptions and load when the work calls for them: the OMP adapters `pstack-omp` and `orchestrate-omp`,
and `setup-pstack`, whose trigger phrases are about configuring models.

Reference files resolve through the owning skill:

```text
skill://poteto-mode
skill://poteto-mode/playbooks/babysit.md
skill://why/references/epistemics.md
```

OMP resolves skill names exactly and case-sensitively, and `skill://` paths are readable but not executable.
A step that runs a bundled script resolves its real path first with `realpath skill://<name>`, which prints
the physical directory under any install root.

`/skill:poteto-help` explains the catalog, including which upstream surfaces have no OMP equivalent.

## OMP task behavior

- Use the exact agent names in the live `task` inventory. Omit `agent` to select OMP's default worker.
- Use `tasks[]`, `context`, `effort`, and `isolated` only when the live task schema exposes them.
- Never put a model in a task item. Model choice is `modelRoles` and `task.agentModelOverrides`.
- Treat child sessions as fresh context. Put the goal, constraints, ownership, acceptance criteria, and the
  leaf-agent boundary in every assignment.
- Read complete results from `agent://<id>` and transcripts from `history://<id>`.
- Keep user interaction, approvals, integration, and final verification with the root coordinator.

## Provenance

- The catalog is adapted from Lauren Tan's [`pstack`](https://github.com/cursor/plugins/tree/main/pstack),
  version 0.15.28 (`cursor/plugins` at `d457567`).
- `orchestrate-omp` began as Eric Provencher's
  [`orchestrate`](https://github.com/provencher/codex-skills/tree/main/orchestrate) and is now OMP-native.
- `pstack-omp`, `fable-deslop`, and the OMP integration, including `setup-pstack`'s model helper, are
  maintained here.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for upstream copyright notices.

## License

MIT. See [`LICENSE`](LICENSE).
