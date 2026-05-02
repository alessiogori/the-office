import { Application, Container } from "pixi.js";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { AGENTS, StatusMap, AgentState } from "./agents";
import { buildRoom, ROOM_W, ROOM_H, TILE } from "./room";
import { AgentSprite } from "./agent";
import { SteamSystem, pulseGlow, pulseMonitor } from "./atmosphere";

const tooltipEl = document.getElementById("tooltip") as HTMLDivElement;

async function main() {
  const stage = document.getElementById("stage")!;
  const app = new Application();
  await app.init({
    background: 0x1a1530,
    backgroundAlpha: 0.92,
    antialias: false,
    roundPixels: true,
    resizeTo: stage,
  });
  stage.appendChild(app.canvas);

  const world = new Container();
  app.stage.addChild(world);

  const { layer, desks, monitors, steamAnchor, windowGlow } = buildRoom();
  world.addChild(layer);

  const steam = new SteamSystem(steamAnchor.x, steamAnchor.y);
  layer.addChild(steam);

  const sprites = new Map<string, AgentSprite>();
  AGENTS.forEach((def, i) => {
    const slot = desks[i];
    const sprite = new AgentSprite(def, slot.x, slot.y);
    sprite.on("pointerover", (e) => showTooltip(sprite, e.global.x, e.global.y));
    sprite.on("pointermove", (e) => moveTooltip(e.global.x, e.global.y));
    sprite.on("pointerout", hideTooltip);
    layer.addChild(sprite);
    sprites.set(def.id, sprite);
  });

  const fit = () => {
    const sx = app.screen.width / (ROOM_W * TILE);
    const sy = app.screen.height / (ROOM_H * TILE);
    const s = Math.min(sx, sy);
    world.scale.set(s);
    world.x = (app.screen.width - ROOM_W * TILE * s) / 2;
    world.y = (app.screen.height - ROOM_H * TILE * s) / 2;
  };
  fit();
  window.addEventListener("resize", fit);

  let t = 0;
  app.ticker.add((ticker) => {
    t += ticker.deltaMS;
    sprites.forEach((s) => s.tick(ticker.deltaTime, t));
    steam.tick(ticker.deltaMS);
    pulseGlow(windowGlow, t);
    pulseMonitor(monitors, t);
  });

  const apply = (data: StatusMap) => {
    console.log("[overlay] apply", data);
    for (const [id, state] of Object.entries(data)) {
      const sprite = sprites.get(id);
      if (sprite) {
        sprite.setState(state as AgentState);
      } else {
        console.warn("[overlay] no sprite for id", id);
      }
    }
  };

  try {
    const initial = await invoke<StatusMap | null>("get_status");
    console.log("[overlay] initial status", initial);
    if (initial) apply(initial);
  } catch (e) {
    console.warn("get_status failed", e);
  }

  const unlisten = await listen<StatusMap>("agent-status", (ev) => {
    console.log("[overlay] event received", ev);
    apply(ev.payload);
  });
  console.log("[overlay] listener ready", typeof unlisten);
}

function showTooltip(sprite: AgentSprite, x: number, y: number) {
  const s = sprite.state;
  tooltipEl.innerHTML = `
    <div class="name">${sprite.def.name} <span class="status">${sprite.def.role}</span></div>
    <div class="status">${s.status || "STANDBY"}</div>
    ${s.task ? `<div class="task">${escapeHtml(s.task)}</div>` : ""}
  `;
  tooltipEl.classList.remove("hidden");
  moveTooltip(x, y);
}

function moveTooltip(x: number, y: number) {
  tooltipEl.style.left = `${Math.min(x + 12, window.innerWidth - tooltipEl.offsetWidth - 8)}px`;
  tooltipEl.style.top = `${Math.min(y + 12, window.innerHeight - tooltipEl.offsetHeight - 8)}px`;
}

function hideTooltip() {
  tooltipEl.classList.add("hidden");
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[c]!));
}

main().catch(console.error);
