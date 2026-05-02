import { Container, Graphics } from "pixi.js";

export interface DeskSlot {
  x: number;
  y: number;
}

export const TILE = 16;
export const ROOM_W = 30;
export const ROOM_H = 18;

export function buildRoom(): { layer: Container; desks: DeskSlot[] } {
  const layer = new Container();

  const floor = new Graphics();
  floor.rect(0, 0, ROOM_W * TILE, ROOM_H * TILE).fill(0x2c2540);
  layer.addChild(floor);

  const grid = new Graphics();
  for (let x = 0; x <= ROOM_W; x++) {
    grid.moveTo(x * TILE, 0).lineTo(x * TILE, ROOM_H * TILE);
  }
  for (let y = 0; y <= ROOM_H; y++) {
    grid.moveTo(0, y * TILE).lineTo(ROOM_W * TILE, y * TILE);
  }
  grid.stroke({ color: 0xffffff, alpha: 0.04, width: 1 });
  layer.addChild(grid);

  const walls = new Graphics();
  walls
    .rect(0, 0, ROOM_W * TILE, TILE)
    .fill(0x1a1530);
  walls
    .rect(0, 0, TILE, ROOM_H * TILE)
    .fill(0x1a1530);
  walls
    .rect((ROOM_W - 1) * TILE, 0, TILE, ROOM_H * TILE)
    .fill(0x1a1530);
  walls
    .rect(0, (ROOM_H - 1) * TILE, ROOM_W * TILE, TILE)
    .fill(0x1a1530);
  layer.addChild(walls);

  const desks: DeskSlot[] = [
    { x: 4,  y: 4 },
    { x: 14, y: 4 },
    { x: 24, y: 4 },
    { x: 4,  y: 13 },
    { x: 14, y: 13 },
    { x: 24, y: 13 },
  ];

  for (const d of desks) {
    const desk = new Graphics();
    desk
      .roundRect(d.x * TILE - 8, d.y * TILE - 4, TILE * 2 + 16, TILE + 8, 3)
      .fill(0x6b4423)
      .stroke({ color: 0x3a2614, width: 1 });
    desk
      .rect(d.x * TILE + TILE / 2, d.y * TILE - 2, TILE, 6)
      .fill(0x4a90e2)
      .stroke({ color: 0x1a1530, width: 1 });
    layer.addChild(desk);
  }

  const meeting = new Graphics();
  const mx = (ROOM_W / 2) * TILE - TILE * 2;
  const my = (ROOM_H / 2) * TILE - TILE;
  meeting
    .roundRect(mx, my, TILE * 4, TILE * 2, 4)
    .fill(0x8b6f47)
    .stroke({ color: 0x3a2614, width: 1 });
  layer.addChild(meeting);

  const coffee = new Graphics();
  coffee
    .rect((ROOM_W - 4) * TILE, (ROOM_H - 4) * TILE, TILE, TILE * 2)
    .fill(0x3d2817)
    .stroke({ color: 0x1a0e08, width: 1 });
  coffee
    .rect((ROOM_W - 4) * TILE + 4, (ROOM_H - 4) * TILE + 4, TILE - 8, 4)
    .fill(0xc0392b);
  layer.addChild(coffee);

  return { layer, desks };
}
