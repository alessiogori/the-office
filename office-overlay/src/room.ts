import { Container, Graphics } from "pixi.js";

export interface DeskSlot {
  x: number;
  y: number;
}

export const TILE = 16;
export const ROOM_W = 30;
export const ROOM_H = 18;

const COLORS = {
  floorA: 0x3d2f5a,
  floorB: 0x342850,
  wall: 0x1a1530,
  wallHi: 0x2a2348,
  window: 0x4a90e2,
  windowGlow: 0x88c0ff,
  desk: 0x6b4423,
  deskTop: 0x8b6f47,
  deskShadow: 0x3a2614,
  monitor: 0x111122,
  monitorOn: 0x4a90e2,
  monitorFrame: 0x222233,
  chair: 0x2a2238,
  plant: 0x2d8a4e,
  plantDark: 0x1f5e36,
  plantPot: 0x7a4a2a,
  rug: 0x6b3a3a,
  rugDark: 0x4a2828,
  coffeeBody: 0x222233,
  coffeeAccent: 0xe74c3c,
  meetingTop: 0x9b7d52,
  meetingLeg: 0x4a3014,
};

export interface RoomBuild {
  layer: Container;
  desks: DeskSlot[];
  monitors: Graphics[];
  steamAnchor: { x: number; y: number };
  windowGlow: Graphics;
}

function parquetFloor(g: Graphics) {
  for (let y = 1; y < ROOM_H - 1; y++) {
    for (let x = 1; x < ROOM_W - 1; x++) {
      const c = (x + y) % 2 === 0 ? COLORS.floorA : COLORS.floorB;
      g.rect(x * TILE, y * TILE, TILE, TILE).fill(c);
    }
  }
  for (let y = 1; y < ROOM_H - 1; y++) {
    g.moveTo(TILE, y * TILE).lineTo((ROOM_W - 1) * TILE, y * TILE);
  }
  g.stroke({ color: 0x000000, alpha: 0.15, width: 1 });
}

function walls(g: Graphics) {
  g.rect(0, 0, ROOM_W * TILE, TILE).fill(COLORS.wall);
  g.rect(0, 0, TILE, ROOM_H * TILE).fill(COLORS.wall);
  g.rect((ROOM_W - 1) * TILE, 0, TILE, ROOM_H * TILE).fill(COLORS.wall);
  g.rect(0, (ROOM_H - 1) * TILE, ROOM_W * TILE, TILE).fill(COLORS.wall);

  g.rect(0, TILE - 2, ROOM_W * TILE, 2).fill(COLORS.wallHi);
  g.rect(TILE - 2, TILE, 2, (ROOM_H - 2) * TILE).fill(COLORS.wallHi);
  g.rect((ROOM_W - 1) * TILE, TILE, 2, (ROOM_H - 2) * TILE).fill(COLORS.wallHi);
}

function windowsLayer(g: Graphics, glow: Graphics) {
  const positions = [6, 14, 22];
  for (const wx of positions) {
    const x = wx * TILE;
    const y = 2;
    glow.rect(x - 2, y - 2, TILE * 3 + 4, 8).fill({ color: COLORS.windowGlow, alpha: 0.25 });
    g.rect(x, y, TILE * 3, 10).fill(COLORS.window).stroke({ color: 0x0e1a2b, width: 1 });
    g.rect(x + TILE * 1.5 - 1, y, 2, 10).fill(0x0e1a2b);
    g.rect(x, y + 5 - 1, TILE * 3, 2).fill(0x0e1a2b);
    for (let i = 0; i < 6; i++) {
      g.rect(x + 2 + i * 7, y + 1, 1, 8).fill({ color: COLORS.windowGlow, alpha: 0.35 });
    }
  }
}

function rug(g: Graphics) {
  const cx = (ROOM_W / 2) * TILE - TILE * 3;
  const cy = (ROOM_H / 2) * TILE - TILE * 1.5;
  const w = TILE * 6;
  const h = TILE * 3;
  g.roundRect(cx, cy, w, h, 3).fill(COLORS.rug).stroke({ color: COLORS.rugDark, width: 1 });
  for (let i = 0; i < 4; i++) {
    g.rect(cx + 4, cy + 4 + i * (h - 8) / 4, w - 8, 1).fill({ color: COLORS.rugDark, alpha: 0.5 });
  }
}

function meetingTable(g: Graphics) {
  const mx = (ROOM_W / 2) * TILE - TILE * 2;
  const my = (ROOM_H / 2) * TILE - TILE;
  g.roundRect(mx, my + 2, TILE * 4, TILE * 2, 3).fill(COLORS.deskShadow);
  g.roundRect(mx, my, TILE * 4, TILE * 2, 3).fill(COLORS.meetingTop).stroke({ color: COLORS.meetingLeg, width: 1 });
  g.rect(mx + TILE * 2 - 1, my + 4, 2, TILE * 2 - 8).fill({ color: COLORS.meetingLeg, alpha: 0.4 });
  for (let i = 0; i < 6; i++) {
    const cx = mx + 4 + i * (TILE * 4 - 8) / 5;
    g.circle(cx, my + 4, 1.5).fill(0xffffff).stroke({ color: 0x222, width: 0.5 });
  }
}

function plant(g: Graphics, px: number, py: number) {
  g.rect(px - 4, py + 4, 8, 6).fill(COLORS.plantPot).stroke({ color: 0x4a2810, width: 1 });
  g.circle(px - 3, py - 1, 4).fill(COLORS.plantDark);
  g.circle(px + 3, py - 1, 4).fill(COLORS.plantDark);
  g.circle(px, py - 4, 4).fill(COLORS.plant);
  g.circle(px - 4, py + 1, 3).fill(COLORS.plant);
  g.circle(px + 4, py + 1, 3).fill(COLORS.plant);
  g.circle(px, py - 1, 3).fill(COLORS.plant);
}

function coffeeCorner(g: Graphics): { x: number; y: number } {
  const cx = (ROOM_W - 4) * TILE;
  const cy = (ROOM_H - 5) * TILE;
  g.rect(cx - 2, cy + TILE * 2 - 4, TILE + 4, 4).fill(COLORS.deskShadow);
  g.rect(cx, cy, TILE, TILE * 2).fill(COLORS.coffeeBody).stroke({ color: 0x000, width: 1 });
  g.rect(cx + 3, cy + 3, TILE - 6, 4).fill(COLORS.coffeeAccent);
  g.rect(cx + 3, cy + 9, TILE - 6, 2).fill(0x88c0ff);
  g.circle(cx + TILE - 3, cy + 4, 1).fill(0xff5555);
  return { x: cx + TILE / 2, y: cy };
}

function deskAt(g: Graphics, dx: number, dy: number, monitorOn: boolean): Graphics {
  const x = dx * TILE;
  const y = dy * TILE;
  g.roundRect(x - 10, y - 4, TILE * 2 + 20, TILE + 12, 3).fill(COLORS.deskShadow);
  g.roundRect(x - 10, y - 6, TILE * 2 + 20, TILE + 10, 3).fill(COLORS.desk).stroke({ color: COLORS.deskShadow, width: 1 });
  g.rect(x - 8, y - 6, TILE * 2 + 16, 2).fill(COLORS.deskTop);

  g.rect(x - 4, y + TILE + 2, TILE * 2 + 8, 4).fill(COLORS.chair);

  const monitor = new Graphics();
  monitor.rect(x + TILE / 2 - 6, y - 2, 12, 8).fill(COLORS.monitorFrame).stroke({ color: 0x000, width: 1 });
  monitor.rect(x + TILE / 2 - 5, y - 1, 10, 6).fill(monitorOn ? COLORS.monitorOn : COLORS.monitor);
  if (monitorOn) {
    monitor.rect(x + TILE / 2 - 4, y, 4, 1).fill(0xffffff);
    monitor.rect(x + TILE / 2 - 4, y + 2, 6, 1).fill(0xddddff);
    monitor.rect(x + TILE / 2 - 4, y + 4, 3, 1).fill(0xaaaaff);
  }
  monitor.rect(x + TILE / 2 - 2, y + 6, 4, 1).fill(COLORS.monitorFrame);
  monitor.rect(x + TILE / 2 - 4, y + 7, 8, 1).fill(COLORS.monitorFrame);

  g.circle(x + TILE * 1.4, y + 3, 1.5).fill(0xfde0c7);
  g.circle(x - 2, y + 3, 1.2).fill(0x88c0ff);

  return monitor;
}

export function buildRoom(): RoomBuild {
  const layer = new Container();

  const floor = new Graphics();
  floor.rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(COLORS.floorB);
  parquetFloor(floor);
  layer.addChild(floor);

  const wallsG = new Graphics();
  walls(wallsG);
  layer.addChild(wallsG);

  const windowGlow = new Graphics();
  layer.addChild(windowGlow);
  const windowsG = new Graphics();
  windowsLayer(windowsG, windowGlow);
  layer.addChild(windowsG);

  const rugG = new Graphics();
  rug(rugG);
  layer.addChild(rugG);

  const meetingG = new Graphics();
  meetingTable(meetingG);
  layer.addChild(meetingG);

  const desks: DeskSlot[] = [
    { x: 4,  y: 5 },
    { x: 14, y: 5 },
    { x: 24, y: 5 },
    { x: 4,  y: 14 },
    { x: 14, y: 14 },
    { x: 24, y: 14 },
  ];

  const deskG = new Graphics();
  layer.addChild(deskG);
  const monitors: Graphics[] = [];
  for (const d of desks) {
    const m = deskAt(deskG, d.x, d.y, true);
    layer.addChild(m);
    monitors.push(m);
  }

  const plantG = new Graphics();
  plant(plantG, TILE + 6, TILE + 8);
  plant(plantG, (ROOM_W - 2) * TILE - 6, TILE + 8);
  plant(plantG, TILE + 6, (ROOM_H - 2) * TILE - 4);
  layer.addChild(plantG);

  const coffeeG = new Graphics();
  const steamAnchor = coffeeCorner(coffeeG);
  layer.addChild(coffeeG);

  return { layer, desks, monitors, steamAnchor, windowGlow };
}
