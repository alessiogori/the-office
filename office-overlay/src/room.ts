import { Container, Graphics } from "pixi.js";

export interface DeskSlot {
  x: number;
  y: number;
}

export const TILE = 16;
export const ROOM_W = 36;
export const ROOM_H = 22;

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
  divider: 0x5a4080,
  dividerTop: 0x6e54a0,
  printer: 0xc8c8d0,
  printerDark: 0x6a6a78,
  printerScreen: 0x4a90e2,
  paper: 0xfafafa,
  shelf: 0x4a3014,
  shelfDark: 0x2a1a08,
  book1: 0xc0392b,
  book2: 0x27ae60,
  book3: 0x2980b9,
  book4: 0xf39c12,
  book5: 0x8e44ad,
  cabinet: 0x444a55,
  cabinetHi: 0x5e6470,
  whiteboard: 0xf0f0f0,
  whiteboardFrame: 0x6a6a78,
  cooler: 0x4a90e2,
  coolerBody: 0xe0e0e8,
  clock: 0x222233,
  artFrame: 0x3a2614,
  art: 0x2980b9,
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
  const positions = [5, 14, 23, 32];
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
  const w = TILE * 4, h = TILE * 2;

  drawChair(g, mx + w * 0.25, my - 5, "down");
  drawChair(g, mx + w * 0.5, my - 5, "down");
  drawChair(g, mx + w * 0.75, my - 5, "down");
  drawChair(g, mx + w * 0.25, my + h + 5, "up");
  drawChair(g, mx + w * 0.5, my + h + 5, "up");
  drawChair(g, mx + w * 0.75, my + h + 5, "up");

  g.roundRect(mx, my + 2, w, h, 3).fill(COLORS.deskShadow);
  g.roundRect(mx, my, w, h, 3).fill(COLORS.meetingTop).stroke({ color: COLORS.meetingLeg, width: 1 });
  g.rect(mx + TILE * 2 - 1, my + 4, 2, h - 8).fill({ color: COLORS.meetingLeg, alpha: 0.4 });
  for (let i = 0; i < 6; i++) {
    const cx = mx + 4 + i * (w - 8) / 5;
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

function bookshelf(g: Graphics, x: number, y: number, h: number) {
  g.rect(x - 1, y + h, 14, 3).fill(COLORS.shelfDark);
  g.rect(x, y, 12, h).fill(COLORS.shelf).stroke({ color: COLORS.shelfDark, width: 1 });
  const shelves = Math.floor(h / 8);
  for (let s = 0; s < shelves; s++) {
    const sy = y + 2 + s * 8;
    g.rect(x + 1, sy + 6, 10, 1).fill(COLORS.shelfDark);
    const books = [COLORS.book1, COLORS.book2, COLORS.book3, COLORS.book4, COLORS.book5];
    let bx = x + 1;
    while (bx < x + 11) {
      const w = 1 + Math.floor((s * 7 + bx) % 3);
      const bh = 5 + ((s + bx) % 2);
      const c = books[(s + bx) % books.length];
      g.rect(bx, sy + 6 - bh, w, bh).fill(c).stroke({ color: 0x000, width: 0.5 });
      bx += w + 1;
    }
  }
  g.rect(x, y - 1, 12, 1).fill(COLORS.shelfDark);
}

function printer(g: Graphics, x: number, y: number) {
  g.rect(x - 1, y + 14, 16, 3).fill(COLORS.deskShadow);
  g.rect(x, y + 4, 14, 10).fill(COLORS.printer).stroke({ color: 0x000, width: 1 });
  g.rect(x, y, 14, 5).fill(COLORS.printerDark).stroke({ color: 0x000, width: 1 });
  g.rect(x + 2, y + 1, 5, 3).fill(COLORS.printerScreen);
  g.circle(x + 11, y + 2, 1).fill(0x2ecc71);
  g.rect(x + 1, y + 7, 12, 1).fill(COLORS.printerDark);
  g.rect(x + 2, y + 9, 10, 3).fill(COLORS.paper).stroke({ color: 0x888, width: 0.5 });
  g.rect(x + 3, y + 10, 8, 1).fill(0xcccccc);
}

function cabinet(g: Graphics, x: number, y: number) {
  g.rect(x - 1, y + 18, 16, 3).fill(COLORS.deskShadow);
  g.rect(x, y, 14, 18).fill(COLORS.cabinet).stroke({ color: 0x000, width: 1 });
  g.rect(x + 1, y + 1, 12, 1).fill(COLORS.cabinetHi);
  for (let i = 0; i < 3; i++) {
    const dy = y + 2 + i * 5;
    g.rect(x + 1, dy, 12, 4).fill(COLORS.cabinet).stroke({ color: COLORS.cabinetHi, width: 0.5 });
    g.circle(x + 7, dy + 2, 0.6).fill(0xc0c0c0);
  }
}

function whiteboard(g: Graphics, x: number, y: number) {
  g.rect(x - 1, y - 1, TILE * 4 + 2, TILE * 2 + 2).fill(COLORS.whiteboardFrame);
  g.rect(x, y, TILE * 4, TILE * 2).fill(COLORS.whiteboard);
  g.rect(x + 4, y + 4, 12, 1).fill(0x222);
  g.rect(x + 4, y + 7, 8, 1).fill(0x222);
  g.rect(x + 18, y + 4, 14, 1).fill(0xc0392b);
  g.rect(x + 18, y + 7, 10, 1).fill(0xc0392b);
  g.rect(x + 4, y + 12, 20, 1).fill(0x2980b9);
  g.rect(x + 4, y + 15, 16, 1).fill(0x2980b9);
  g.rect(x + 4, y + 18, 12, 1).fill(0x27ae60);
  g.rect(x, y + TILE * 2, TILE * 4, 2).fill(COLORS.whiteboardFrame);
  g.rect(x + 6, y + TILE * 2, 4, 1).fill(0xc0392b);
  g.rect(x + 14, y + TILE * 2, 4, 1).fill(0x222);
}

function waterCooler(g: Graphics, x: number, y: number) {
  g.rect(x - 1, y + 18, 12, 3).fill(COLORS.deskShadow);
  g.rect(x + 1, y, 8, 8).fill(COLORS.cooler).stroke({ color: 0x222, width: 1 });
  g.rect(x + 2, y + 1, 6, 6).fill(0x88c0ff);
  for (let i = 0; i < 3; i++) {
    g.circle(x + 3 + i * 2, y + 3 + (i % 2), 0.6).fill({ color: 0xffffff, alpha: 0.6 });
  }
  g.rect(x, y + 8, 10, 10).fill(COLORS.coolerBody).stroke({ color: 0x222, width: 1 });
  g.rect(x + 3, y + 10, 4, 2).fill(0xc0392b);
  g.rect(x + 3, y + 13, 4, 2).fill(0x2980b9);
  g.rect(x + 4, y + 16, 2, 1).fill(0x222);
}

function divider(g: Graphics, x: number, y: number, w: number, h: number) {
  g.rect(x, y + h - 2, w, 2).fill(COLORS.dividerTop);
  g.rect(x, y, w, h - 2).fill(COLORS.divider).stroke({ color: COLORS.wall, width: 1 });
  g.rect(x + 1, y + 1, w - 2, 1).fill({ color: 0xffffff, alpha: 0.15 });
}

function wallClock(g: Graphics, x: number, y: number) {
  g.circle(x, y, 5).fill(COLORS.clock).stroke({ color: COLORS.wallHi, width: 1 });
  g.circle(x, y, 4).fill(0xfafafa);
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    g.rect(x + Math.cos(a) * 3 - 0.3, y + Math.sin(a) * 3 - 0.3, 0.7, 0.7).fill(0x222);
  }
  g.rect(x, y - 2, 0.6, 2).fill(0x222);
  g.rect(x, y, 2, 0.6).fill(0xc0392b);
  g.circle(x, y, 0.5).fill(0x222);
}

function wallArt(g: Graphics, x: number, y: number, color: number) {
  g.rect(x - 1, y - 1, 12, 9).fill(COLORS.artFrame);
  g.rect(x, y, 10, 7).fill(color);
  g.rect(x + 1, y + 1, 8, 2).fill({ color: 0xffffff, alpha: 0.3 });
  g.rect(x + 2, y + 4, 3, 2).fill({ color: 0x000, alpha: 0.4 });
  g.rect(x + 6, y + 4, 2, 2).fill({ color: 0x000, alpha: 0.3 });
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

function drawChair(g: Graphics, cx: number, cy: number, facing: "up" | "down" | "left" | "right" = "up") {
  const seatW = 8, seatH = 7;
  const x = cx - seatW / 2;
  const y = cy - seatH / 2;
  g.rect(x - 1, y + 1, seatW + 2, seatH + 1).fill(COLORS.deskShadow);
  g.rect(x, y, seatW, seatH).fill(COLORS.chair).stroke({ color: 0x000, width: 1 });
  g.rect(x + 1, y + 1, seatW - 2, 1).fill(0x4a3a5e);
  if (facing === "up") {
    g.rect(x, y - 4, seatW, 4).fill(COLORS.chair).stroke({ color: 0x000, width: 1 });
    g.rect(x + 1, y - 3, seatW - 2, 1).fill(0x4a3a5e);
  } else if (facing === "down") {
    g.rect(x, y + seatH, seatW, 4).fill(COLORS.chair).stroke({ color: 0x000, width: 1 });
  } else if (facing === "left") {
    g.rect(x - 3, y, 3, seatH).fill(COLORS.chair).stroke({ color: 0x000, width: 1 });
  } else {
    g.rect(x + seatW, y, 3, seatH).fill(COLORS.chair).stroke({ color: 0x000, width: 1 });
  }
}

function deskAt(g: Graphics, dx: number, dy: number, monitorOn: boolean): Graphics {
  const x = dx * TILE;
  const y = dy * TILE;
  drawChair(g, x + TILE / 2, y + TILE + 9, "up");
  g.roundRect(x - 10, y - 4, TILE * 2 + 20, TILE + 12, 3).fill(COLORS.deskShadow);
  g.roundRect(x - 10, y - 6, TILE * 2 + 20, TILE + 10, 3).fill(COLORS.desk).stroke({ color: COLORS.deskShadow, width: 1 });
  g.rect(x - 8, y - 6, TILE * 2 + 16, 2).fill(COLORS.deskTop);

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
    { x: 16, y: 5 },
    { x: 28, y: 5 },
    { x: 4,  y: 17 },
    { x: 16, y: 17 },
    { x: 28, y: 17 },
  ];

  const deskG = new Graphics();
  layer.addChild(deskG);
  const monitors: Graphics[] = [];
  for (const d of desks) {
    const m = deskAt(deskG, d.x, d.y, true);
    layer.addChild(m);
    monitors.push(m);
  }

  const decorBack = new Graphics();
  bookshelf(decorBack, TILE * 9, TILE + 1, 28);
  bookshelf(decorBack, TILE * 11, TILE + 1, 28);
  bookshelf(decorBack, TILE * 24, TILE + 1, 28);

  printer(decorBack, TILE * 21 + 4, TILE + 2);
  cabinet(decorBack, TILE * 13, TILE + 1);
  cabinet(decorBack, TILE * 22, TILE + 1);

  whiteboard(decorBack, TILE * 16, TILE + 2);

  waterCooler(decorBack, TILE + 4, TILE * 10);
  waterCooler(decorBack, TILE + 4, TILE * 13);

  wallClock(decorBack, (ROOM_W / 2) * TILE, TILE - 5);
  wallArt(decorBack, TILE * 3, TILE + 4, 0x2980b9);
  wallArt(decorBack, TILE * 27, TILE + 4, 0xc0392b);

  divider(decorBack, TILE * 10, TILE * 9 + 4, 2, TILE * 4);
  divider(decorBack, TILE * 24, TILE * 9 + 4, 2, TILE * 4);

  layer.addChild(decorBack);

  const plantG = new Graphics();
  plant(plantG, TILE + 6, TILE + 8);
  plant(plantG, (ROOM_W - 2) * TILE - 6, TILE + 8);
  plant(plantG, TILE + 6, (ROOM_H - 2) * TILE - 4);
  plant(plantG, (ROOM_W - 2) * TILE - 6, (ROOM_H - 2) * TILE - 4);
  plant(plantG, TILE * 8, (ROOM_H - 3) * TILE);
  plant(plantG, TILE * 26, (ROOM_H - 3) * TILE);
  layer.addChild(plantG);

  const coffeeG = new Graphics();
  const steamAnchor = coffeeCorner(coffeeG);
  layer.addChild(coffeeG);

  return { layer, desks, monitors, steamAnchor, windowGlow };
}
