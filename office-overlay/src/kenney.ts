import { Assets, Rectangle, Texture } from "pixi.js";
import sheetUrl from "./assets/chars.png";

const TILE_SIZE = 16;
const TILE_GAP = 1;

let sheet: Texture | null = null;

export async function loadKenney(): Promise<void> {
  sheet = await Assets.load<Texture>(sheetUrl);
  sheet.source.scaleMode = "nearest";
}

export function tile(col: number, row: number): Texture {
  if (!sheet) throw new Error("kenney sheet not loaded");
  const x = col * (TILE_SIZE + TILE_GAP);
  const y = row * (TILE_SIZE + TILE_GAP);
  return new Texture({
    source: sheet.source,
    frame: new Rectangle(x, y, TILE_SIZE, TILE_SIZE),
  });
}

export const CHAR_TILES: Record<string, [number, number]> = {
  alessio:    [0, 8],
  stefano:    [1, 8],
  walter:     [2, 8],
  veronica:   [3, 8],
  alessandra: [4, 8],
  marwen:     [5, 8],
};

export const PROP_TILES = {
  chair:  [9, 5],
  table:  [4, 5],
  barrel: [3, 5],
  chest:  [10, 5],
} as const;
