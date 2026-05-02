import { Container, Graphics, Sprite, Text } from "pixi.js";
import { AgentDef, AgentState, AgentStatus, STATUS_COLORS } from "./agents";
import { TILE, ROOM_W, ROOM_H } from "./room";
import { CHAR_TILES, tile } from "./kenney";

interface WanderTarget { x: number; y: number; ttl: number; }

export class AgentSprite extends Container {
  private body: Sprite;
  private statusDot: Graphics;
  private bubble: Container;
  private bubbleTxt: Text;
  private bobBase: number;
  private bobPhase: number;
  public state: AgentState = { status: "STANDBY", task: "", ts: "" };
  private deskX: number;
  private deskY: number;
  private wanderTarget: WanderTarget | null = null;
  private wanderCooldown = 0;
  private badge: Text | null = null;
  public flashUntil = 0;

  constructor(public def: AgentDef, deskX: number, deskY: number) {
    super();
    this.deskX = deskX * TILE + TILE / 2;
    this.deskY = deskY * TILE + TILE - 4;
    this.x = this.deskX;
    this.y = this.deskY;
    this.bobBase = this.deskY;
    this.bobPhase = Math.random() * Math.PI * 2;

    const coords = CHAR_TILES[def.id] ?? [0, 8];
    this.body = new Sprite(tile(coords[0], coords[1]));
    this.body.anchor.set(0.5, 1);
    this.body.scale.set(0.85);
    this.addChild(this.body);

    const nameTag = new Text({
      text: def.name[0],
      style: {
        fontFamily: "monospace",
        fontSize: 5,
        fill: 0xffffff,
        fontWeight: "bold",
        stroke: { color: 0x000000, width: 2 },
      },
    });
    nameTag.anchor.set(0.5);
    nameTag.x = 0;
    nameTag.y = -16;
    this.addChild(nameTag);

    this.statusDot = new Graphics();
    this.addChild(this.statusDot);
    this.drawStatusDot(STATUS_COLORS.STANDBY);

    this.bubble = new Container();
    const bubbleBg = new Graphics();
    bubbleBg
      .roundRect(-6, -28, 12, 9, 2)
      .fill({ color: 0xffffff, alpha: 0.95 })
      .stroke({ color: 0x111122, width: 1 });
    bubbleBg.poly([-2, -20, 0, -17, 2, -20]).fill({ color: 0xffffff, alpha: 0.95 }).stroke({ color: 0x111122, width: 1 });
    this.bubble.addChild(bubbleBg);
    this.bubbleTxt = new Text({
      text: "",
      style: { fontFamily: "monospace", fontSize: 7, fill: 0x111122, fontWeight: "bold" },
    });
    this.bubbleTxt.anchor.set(0.5);
    this.bubbleTxt.x = 0;
    this.bubbleTxt.y = -24;
    this.bubble.addChild(this.bubbleTxt);
    this.bubble.visible = false;
    this.addChild(this.bubble);

    this.eventMode = "static";
    this.cursor = "pointer";
    this.hitArea = { contains: (x: number, y: number) => x > -8 && x < 8 && y > -16 && y < 2 };
  }

  private drawStatusDot(color: number) {
    this.statusDot.clear();
    this.statusDot
      .circle(7, -13, 2)
      .fill(color)
      .stroke({ color: 0x111122, width: 0.5 });
  }

  setState(state: AgentState) {
    const prevStatus = this.state.status;
    this.state = state;
    const status = state.status as AgentStatus;
    this.drawStatusDot(STATUS_COLORS[status] ?? STATUS_COLORS.STANDBY);
    this.bubbleTxt.text = this.bubbleFor(status);
    this.bubble.visible = status !== "STANDBY";
    this.updateBadge(state.task);
    if (status !== "IDLE" && prevStatus === "IDLE") {
      this.wanderTarget = null;
    }
  }

  private updateBadge(task: string) {
    const emoji = badgeFor(task);
    if (!emoji) {
      if (this.badge) {
        this.removeChild(this.badge);
        this.badge.destroy();
        this.badge = null;
      }
      return;
    }
    if (!this.badge) {
      this.badge = new Text({
        text: emoji,
        style: { fontFamily: "system-ui", fontSize: 8 },
      });
      this.badge.anchor.set(0.5);
      this.badge.x = -7;
      this.badge.y = -13;
      this.addChild(this.badge);
    }
    this.badge.text = emoji;
  }

  flash() { this.flashUntil = performance.now() + 1500; }

  private bubbleFor(s: AgentStatus): string {
    switch (s) {
      case "WORKING": return "✦";
      case "IDLE": return "?";
      default: return "";
    }
  }

  tick(dtMs: number, t: number) {
    if (this.state.status === "WORKING") {
      this.x = this.deskX;
      this.y = this.bobBase + Math.sin(t * 0.012 + this.bobPhase) * 1.5;
      this.body.rotation = Math.sin(t * 0.025 + this.bobPhase) * 0.04;
    } else if (this.state.status === "IDLE") {
      this.tickWander(dtMs);
      this.body.rotation = Math.sin(t * 0.008 + this.bobPhase) * 0.08;
    } else {
      this.x = this.deskX;
      this.y = this.bobBase;
      this.body.rotation = 0;
    }
    if (this.bubble.visible) {
      this.bubble.y = Math.sin(t * 0.005 + this.bobPhase) * 0.6;
    }
    if (this.flashUntil > performance.now()) {
      const k = (this.flashUntil - performance.now()) / 1500;
      this.body.tint = lerpColor(0xffffff, 0xffe066, k);
      this.scale.set(1 + k * 0.2);
    } else if (this.scale.x !== 1) {
      this.body.tint = 0xffffff;
      this.scale.set(1);
    }
  }

  private tickWander(dtMs: number) {
    this.wanderCooldown -= dtMs;
    if (!this.wanderTarget && this.wanderCooldown <= 0) {
      this.pickWanderTarget();
    }
    if (this.wanderTarget) {
      const dx = this.wanderTarget.x - this.x;
      const dy = this.wanderTarget.y - this.y;
      const dist = Math.hypot(dx, dy);
      const speed = 0.025 * dtMs;
      if (dist < speed) {
        this.x = this.wanderTarget.x;
        this.y = this.wanderTarget.y;
        this.bobBase = this.y;
        this.wanderTarget = null;
        this.wanderCooldown = 1500 + Math.random() * 3500;
      } else {
        this.x += (dx / dist) * speed;
        this.y += (dy / dist) * speed;
        this.bobBase = this.y;
      }
    }
  }

  private pickWanderTarget() {
    const spots: WanderTarget[] = [
      { x: this.deskX, y: this.deskY, ttl: 0 },
      { x: (ROOM_W - 4) * TILE + TILE / 2, y: (ROOM_H - 4) * TILE, ttl: 0 },
      { x: (ROOM_W / 2) * TILE, y: (ROOM_H / 2) * TILE + TILE, ttl: 0 },
      { x: this.deskX + (Math.random() - 0.5) * TILE * 4, y: this.deskY + (Math.random() - 0.5) * TILE * 2, ttl: 0 },
    ];
    this.wanderTarget = spots[Math.floor(Math.random() * spots.length)];
  }
}

function lerpColor(a: number, b: number, k: number): number {
  k = Math.max(0, Math.min(1, k));
  const ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
  const br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
  const r = Math.round(ar + (br - ar) * k);
  const g = Math.round(ag + (bg - ag) * k);
  const bl = Math.round(ab + (bb - ab) * k);
  return (r << 16) | (g << 8) | bl;
}

function badgeFor(task: string): string | null {
  const t = task.toLowerCase();
  if (/bug|fix|error|crash/.test(t)) return "🐛";
  if (/test|qa|coverage|e2e|spec/.test(t)) return "🧪";
  if (/feat|nuova|build|implement/.test(t)) return "✨";
  if (/doc|readme|guide|changelog/.test(t)) return "📝";
  if (/deploy|release|prod|ci/.test(t)) return "🚀";
  if (/refactor|cleanup|tech debt/.test(t)) return "🔧";
  if (/design|ui|ux|layout/.test(t)) return "🎨";
  if (/meeting|call|sync/.test(t)) return "💬";
  return null;
}
