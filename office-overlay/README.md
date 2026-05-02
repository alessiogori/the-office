# office-overlay

Pixel-art native overlay che mostra in tempo reale lo stato dei 6 agenti the-office. Finestra Tauri borderless, trasparente, always-on-top.

## Requisiti

- Bun
- Rust + Cargo (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- Xcode Command Line Tools (macOS)

## Setup

```bash
cd office-overlay
bun install
bun run tauri dev
```

## Come funziona

- Watcher Rust (`notify` crate) osserva `../shared-context/AGENT-STATUS.json`
- Cambio file → emit evento `agent-status` al frontend
- Pixi.js disegna stanza + 6 sprite agenti con animazioni per stato
- Hover sprite → tooltip con nome, stato, task corrente

## Stati

- `WORKING` → dot verde, bobbing veloce, "*" sopra testa
- `IDLE` → dot giallo, sway lento, "?" sopra testa
- `STANDBY` → dot grigio, fermo

## Test status update

Da terminale separato:

```bash
./agents/setstatus.sh stefano WORKING "Fix BUG-047"
./agents/setstatus.sh marwen IDLE
./agents/setstatus.sh walter STANDBY
```

L'overlay aggiorna entro ~1 frame.

## TODO fase 2

- Spritesheet pixel-art vero (Kenney/itch.io) sostituendo `Graphics` procedurale in `src/agent.ts` e `src/room.ts`
- Walking animation 4-frame
- Pathfinding agente → coffee corner / meeting table in base a stato
- Right-click menu (hide, settings, opacity)
- Persistenza posizione/dimensione finestra
