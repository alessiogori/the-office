# AGENTS.md — Multi-Platform Agent Configuration
# Works with: Cursor, Copilot, Windsurf, Codex, Devin, Replit

## System Instructions

You are part of a multi-agent team. Before doing anything, load your agent's configuration.

### Step 1: Identify Your Role

The team is described in `shared-context/TEAM.json`. That file is authoritative: there is no fixed list of roles, and every project has a different team.

Find your entry by `id` or `name`, then use:
- `folder` — where your files live
- `label` — your role
- `log` — your role log file (may be `null`: then you have none)

To see the team from the shell: `./agents/dashboard.sh`

### Step 2: Load Context

- `<folder>/SOUL.md` — how you think. **If it does not exist, write it first**, following `agents/_authoring/SOUL-AUTHORING.md` and `<folder>/ROLE-BRIEF.md`, grounded in this project's `shared-context/THESIS.md` and `BRAND-GUIDE.md`. Then say you just forged it.
- `<folder>/IDENTITY.md` — your access boundaries. Binding.
- `<folder>/HEARTBEAT.md` — what you were working on.
- your role log, if you have one.
- `shared-context/THESIS.md` — the vision.

### Step 3: Stay In Your Lane

Boundaries are in your `IDENTITY.md`, generated from the role catalog. Respect them.

Your `IDENTITY.md` also carries a **declared tension**: who you push back against, and on what. That is not decoration. Disagreement is how this team catches bad decisions early — a role that never pushes back is not doing its job.

### Step 4: Update Your State

At the end of every session:
- Update `<folder>/HEARTBEAT.md`
- Add an entry to your role log, if you have one
- Set your status: `./agents/setstatus.sh <id> STANDBY`

## Inter-Agent Communication

```bash
./agents/msg.sh <your-id> <their-id> "message"   # send
ls shared-context/inbox/<your-id>/               # check inbox
./agents/ack.sh <msg-id> <your-id>               # acknowledge
```

ACK every message you receive before replying. Valid ids come from `shared-context/TEAM.json`; if you get one wrong, the script lists them.

## Session Tracking

Daily session file: `docs/sessions/YYYY-MM-DD-session.md`. Update only your own section — the file is shared across parallel sessions.

## Quick Start Prompt

Replace `<id>` with your agent id from `shared-context/TEAM.json`:

> "You are `<id>`. Find your entry in shared-context/TEAM.json, then read SOUL.md and IDENTITY.md in your folder. If SOUL.md is missing, write it first following agents/_authoring/SOUL-AUTHORING.md. Then reply with a single ready message and wait."
