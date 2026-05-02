import { Container, Graphics, Text } from "pixi.js";
import { AgentDef, AgentState, AgentStatus, STATUS_COLORS } from "./agents";
import { TILE, ROOM_W, ROOM_H } from "./room";

const P = 2; // pixel block size
const SKIN = 0xf5c8a0;
const PANT = 0x3a3a5a;
const SHOE = 0x222233;

interface WanderTarget { x: number; y: number; ttl: number; }

/** Disegna personaggio stile Pokémon overworld (vista frontale) */
function drawChar(id: string, clothColor: number): Graphics {
  const g = new Graphics();

  // capelli / colore unico per agente
  const hairColors: Record<string, number> = {
    alessio:    0x2c1a0e, // scuro
    stefano:    0x1a1a2e, // nero bluastro
    walter:     0x5c3317, // castano
    veronica:   0xc0392b, // rosso
    alessandra: 0x6c3483, // viola
    marwen:     0x1e8449, // verde scuro
  };
  const hair = hairColors[id] ?? 0x333333;

  // — testa —
  g.rect(-3 * P, -8 * P, 6 * P, 2 * P).fill(hair);         // capelli top
  g.rect(-3 * P, -6 * P, 6 * P, 4 * P).fill(SKIN);          // faccia
  // occhi
  g.rect(-2 * P, -4 * P, P, P).fill(0x222233);
  g.rect(P,      -4 * P, P, P).fill(0x222233);
  // bocca
  g.rect(-P, -2 * P, 2 * P, P).fill(0xc07060);

  // — corpo —
  g.rect(-3 * P, -2 * P, 6 * P, 4 * P).fill(clothColor);    // torso
  // braccia
  g.rect(-4 * P, -2 * P, P, 3 * P).fill(clothColor);
  g.rect(3 * P,  -2 * P, P, 3 * P).fill(clothColor);
  // mani
  g.rect(-4 * P, P,  P, P).fill(SKIN);
  g.rect(3 * P,  P,  P, P).fill(SKIN);

  // — gambe —
  g.rect(-3 * P, 2 * P, 2 * P, 3 * P).fill(PANT);
  g.rect(P,      2 * P, 2 * P, 3 * P).fill(PANT);
  // scarpe
  g.rect(-3 * P, 5 * P, 2 * P, P).fill(SHOE);
  g.rect(P,      5 * P, 2 * P, P).fill(SHOE);

  // — accessorio unico —
  switch (id) {
    case "alessio":
      // corona dorata (3 punte)
      g.rect(-3 * P, -10 * P, 2 * P, 2 * P).fill(0xf5b400);
      g.rect(-P,     -11 * P, 2 * P, 3 * P).fill(0xf5b400);
      g.rect(P,      -10 * P, 2 * P, 2 * P).fill(0xf5b400);
      break;
    case "stefano":
      // occhiali (barretta nera orizzontale)
      g.rect(-3 * P, -4 * P, 2 * P, P).fill(0x111122);
      g.rect(P,      -4 * P, 2 * P, P).fill(0x111122);
      g.rect(-P,     -4 * P, 2 * P, P).fill(0x777788); // ponte
      break;
    case "walter":
      // clipboard in mano destra (piccolo rettangolo bianco)
      g.rect(3 * P, -3 * P, 3 * P, 4 * P).fill(0xf0f0e0);
      g.rect(3 * P, -3 * P, 3 * P, P).fill(0xaaaaaa);
      break;
    case "veronica":
      // codino a destra
      g.rect(3 * P, -7 * P, P,     4 * P).fill(hair);
      g.rect(4 * P, -5 * P, 2 * P, P).fill(hair);
      break;
    case "alessandra":
      // matita / stylus sopra la testa
      g.rect(-P, -13 * P, P, 5 * P).fill(0xf5b400);
      g.rect(-P, -13 * P, P, P).fill(0xee3333);   // punta
      break;
    case "marwen":
      // cuffie (cerchi ai lati della testa)
      g.rect(-5 * P, -7 * P, P, 2 * P).fill(0x222244);
      g.rect(4 * P,  -7 * P, P, 2 * P).fill(0x222244);
      g.rect(-5 * P, -8 * P, 6 * P, P).fill(0x222244); // fascia top
      break;
  }

  return g;
}

export class AgentSprite extends Container {
  private body: Graphics;
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

    this.body = drawChar(def.id, def.color);
    this.body.scale.set(0.9);
    this.addChild(this.body);

    // etichetta nome (piccola, sopra)
    const nameTag = new Text({
      text: def.name,
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
    nameTag.y = -22;
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
    this.hitArea = { contains: (x: number, y: number) => x > -8 && x < 8 && y > -18 && y < 4 };
  }

  private drawStatusDot(color: number) {
    this.statusDot.clear();
    this.statusDot
      .circle(8, -14, 2.5)
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
      this.badge.x = -9;
      this.badge.y = -14;
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
      this.body.rotation = Math.sin(t * 0.008 + this.bobPhase) * 0.06;
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
      this.scale.set(1 + k * 0.18);
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
