import { Application, Container, Graphics } from "pixi.js";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { AGENTS, StatusMap, AgentState } from "./agents";
import { buildRoom, ROOM_W, ROOM_H, TILE } from "./room";
import { AgentSprite } from "./agent";
import { SteamSystem, pulseGlow, pulseMonitor } from "./atmosphere";
import { currentDayNight } from "./daynight";
import { loadKenney } from "./kenney";

const tooltipEl = document.getElementById("tooltip") as HTMLDivElement;
const ctxMenuEl = document.getElementById("ctxmenu") as HTMLDivElement;
const aotStateEl = document.getElementById("aot-state") as HTMLSpanElement;
const clockEl = document.getElementById("clock") as HTMLSpanElement;
const dragHandle = document.getElementById("drag-handle") as HTMLDivElement;

async function main() {
  const stage = document.getElementById("stage")!;
  const app = new Application();
  await app.init({
    background: 0x1a1530,
    backgroundAlpha: 0,
    antialias: false,
    roundPixels: true,
    resizeTo: stage,
  });
  stage.appendChild(app.canvas);

  await loadKenney();

  const world = new Container();
  app.stage.addChild(world);

  const sky = new Graphics();
  sky.rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(0x1a1530);
  world.addChild(sky);

  const { layer, desks, monitors, steamAnchor, windowGlow } = buildRoom();
  world.addChild(layer);

  const ambient = new Graphics();
  ambient.rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(0xffffff);
  ambient.alpha = 0;
  world.addChild(ambient);

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

  let lastDnUpdate = 0;
  let t = 0;
  app.ticker.add((ticker) => {
    t += ticker.deltaMS;
    sprites.forEach((s) => s.tick(ticker.deltaTime, t));
    steam.tick(ticker.deltaMS);
    pulseGlow(windowGlow, t);
    pulseMonitor(monitors, t);

    if (t - lastDnUpdate > 30000 || lastDnUpdate === 0) {
      lastDnUpdate = t;
      const dn = currentDayNight();
      sky.clear().rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(dn.skyColor);
      ambient.clear().rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(dn.ambientColor);
      ambient.alpha = dn.ambientAlpha;
      windowGlow.tint = dn.windowGlow;
      monitors.forEach(m => m.tint = mixTint(0xffffff, dn.skyColor, dn.monitorBoost * 0.3));
      updateClock(dn.label);
    }
  });

  const apply = (data: StatusMap) => {
    for (const [id, state] of Object.entries(data)) {
      const sprite = sprites.get(id);
      if (sprite) sprite.setState(state as AgentState);
    }
  };

  try {
    const initial = await invoke<StatusMap | null>("get_status");
    if (initial) apply(initial);
  } catch (e) {
    console.warn("get_status failed", e);
  }

  await listen<StatusMap>("agent-status", (ev) => apply(ev.payload));

  setupContextMenu();
  setInterval(() => updateClock(), 30000);
  updateClock();
}

function mixTint(base: number, target: number, k: number): number {
  k = Math.max(0, Math.min(1, k));
  const ar = (base >> 16) & 0xff, ag = (base >> 8) & 0xff, ab = base & 0xff;
  const br = (target >> 16) & 0xff, bg = (target >> 8) & 0xff, bb = target & 0xff;
  const r = Math.round(ar + (br - ar) * k);
  const g = Math.round(ag + (bg - ag) * k);
  const bl = Math.round(ab + (bb - ab) * k);
  return (r << 16) | (g << 8) | bl;
}

function updateClock(label?: string) {
  const d = new Date();
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  clockEl.textContent = label ? `${hh}:${mm} · ${label}` : `${hh}:${mm}`;
}

let opacity = 1;
function setupContextMenu() {
  dragHandle.addEventListener("contextmenu", openMenu);
  document.body.addEventListener("contextmenu", openMenu);
  document.body.addEventListener("click", () => ctxMenuEl.classList.add("hidden"));
  ctxMenuEl.addEventListener("click", async (e) => {
    const action = (e.target as HTMLElement).closest("[data-action]")?.getAttribute("data-action");
    if (!action) return;
    const win = getCurrentWindow();
    switch (action) {
      case "toggle-aot": {
        const cur = await win.isAlwaysOnTop();
        await win.setAlwaysOnTop(!cur);
        aotStateEl.textContent = !cur ? "on" : "off";
        break;
      }
      case "opacity-up":
        opacity = Math.min(1, opacity + 0.1);
        document.body.style.opacity = String(opacity);
        break;
      case "opacity-down":
        opacity = Math.max(0.3, opacity - 0.1);
        document.body.style.opacity = String(opacity);
        break;
      case "reset-pos":
        await win.center();
        break;
      case "hide":
        await win.hide();
        break;
    }
    ctxMenuEl.classList.add("hidden");
  });
}

function openMenu(e: MouseEvent) {
  e.preventDefault();
  ctxMenuEl.style.left = `${e.clientX}px`;
  ctxMenuEl.style.top = `${e.clientY}px`;
  ctxMenuEl.classList.remove("hidden");
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
