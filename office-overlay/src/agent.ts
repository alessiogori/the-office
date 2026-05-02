import { Container, Graphics, Text } from "pixi.js";
import { AgentDef, AgentState, AgentStatus, STATUS_COLORS } from "./agents";
import { TILE } from "./room";

const HAIR_COLORS: Record<string, number> = {
  alessio: 0x3a2a18,
  stefano: 0x6b4423,
  walter: 0x222233,
  veronica: 0xc1392b,
  alessandra: 0x8b5a2b,
  marwen: 0x2c1a0e,
};

export class AgentSprite extends Container {
  private body: Graphics;
  private head: Graphics;
  private letter: Text;
  private statusDot: Graphics;
  private bubble: Container;
  private bubbleTxt: Text;
  private armL: Graphics;
  private armR: Graphics;
  private bobBase: number;
  private bobPhase: number;
  public state: AgentState = { status: "STANDBY", task: "", ts: "" };

  constructor(public def: AgentDef, deskX: number, deskY: number) {
    super();
    this.x = deskX * TILE + TILE / 2;
    this.y = deskY * TILE + TILE + 4;
    this.bobBase = this.y;
    this.bobPhase = Math.random() * Math.PI * 2;

    const hair = HAIR_COLORS[def.id] ?? 0x333333;

    this.body = new Graphics();
    this.body
      .rect(-5, -2, 10, 8)
      .fill(def.color)
      .stroke({ color: 0x111122, width: 1 });
    this.body
      .rect(-5, -2, 10, 2)
      .fill(this.darken(def.color, 0.3));
    this.addChild(this.body);

    this.armL = new Graphics();
    this.armL
      .rect(-7, -1, 3, 4)
      .fill(def.color)
      .stroke({ color: 0x111122, width: 0.5 });
    this.addChild(this.armL);

    this.armR = new Graphics();
    this.armR
      .rect(4, -1, 3, 4)
      .fill(def.color)
      .stroke({ color: 0x111122, width: 0.5 });
    this.addChild(this.armR);

    this.head = new Graphics();
    this.head
      .rect(-3, -10, 6, 7)
      .fill(0xfde0c7)
      .stroke({ color: 0x111122, width: 1 });
    this.head
      .rect(-3, -10, 6, 3)
      .fill(hair);
    this.head
      .rect(-3, -10, 1, 4)
      .fill(hair);
    this.head
      .rect(2, -10, 1, 4)
      .fill(hair);
    this.head.rect(-2, -7, 1, 1).fill(0x111122);
    this.head.rect(1, -7, 1, 1).fill(0x111122);
    this.head.rect(-1, -5, 2, 1).fill(0xc97a6b);
    this.addChild(this.head);

    this.letter = new Text({
      text: def.name[0],
      style: {
        fontFamily: "monospace",
        fontSize: 5,
        fill: 0xffffff,
        fontWeight: "bold",
      },
    });
    this.letter.anchor.set(0.5);
    this.letter.x = 0;
    this.letter.y = 1;
    this.addChild(this.letter);

    this.statusDot = new Graphics();
    this.addChild(this.statusDot);
    this.drawStatusDot(STATUS_COLORS.STANDBY);

    this.bubble = new Container();
    const bubbleBg = new Graphics();
    bubbleBg
      .roundRect(-6, -18, 12, 9, 2)
      .fill({ color: 0xffffff, alpha: 0.95 })
      .stroke({ color: 0x111122, width: 1 });
    bubbleBg.poly([-2, -10, 0, -7, 2, -10]).fill({ color: 0xffffff, alpha: 0.95 }).stroke({ color: 0x111122, width: 1 });
    this.bubble.addChild(bubbleBg);
    this.bubbleTxt = new Text({
      text: "",
      style: { fontFamily: "monospace", fontSize: 7, fill: 0x111122, fontWeight: "bold" },
    });
    this.bubbleTxt.anchor.set(0.5);
    this.bubbleTxt.x = 0;
    this.bubbleTxt.y = -14;
    this.bubble.addChild(this.bubbleTxt);
    this.bubble.visible = false;
    this.addChild(this.bubble);

    this.eventMode = "static";
    this.cursor = "pointer";
    this.hitArea = { contains: (x: number, y: number) => x > -8 && x < 8 && y > -12 && y < 8 };
  }

  private darken(c: number, amt: number): number {
    const r = ((c >> 16) & 0xff) * (1 - amt);
    const g = ((c >> 8) & 0xff) * (1 - amt);
    const b = (c & 0xff) * (1 - amt);
    return ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);
  }

  private drawStatusDot(color: number) {
    this.statusDot.clear();
    this.statusDot
      .circle(6, -10, 2)
      .fill(color)
      .stroke({ color: 0x111122, width: 0.5 });
  }

  setState(state: AgentState) {
    this.state = state;
    const status = state.status as AgentStatus;
    this.drawStatusDot(STATUS_COLORS[status] ?? STATUS_COLORS.STANDBY);
    this.bubbleTxt.text = this.bubbleFor(status);
    this.bubble.visible = status !== "STANDBY";
  }

  private bubbleFor(s: AgentStatus): string {
    switch (s) {
      case "WORKING": return "✦";
      case "IDLE": return "?";
      default: return "";
    }
  }

  tick(_dt: number, t: number) {
    if (this.state.status === "WORKING") {
      this.y = this.bobBase + Math.sin(t * 0.012 + this.bobPhase) * 1.5;
      const typingPhase = Math.sin(t * 0.025 + this.bobPhase);
      this.armL.y = typingPhase * 0.8;
      this.armR.y = -typingPhase * 0.8;
    } else if (this.state.status === "IDLE") {
      this.y = this.bobBase + Math.sin(t * 0.004 + this.bobPhase) * 1.2;
      this.rotation = Math.sin(t * 0.004 + this.bobPhase) * 0.06;
      this.armL.y = 0;
      this.armR.y = 0;
    } else {
      this.y = this.bobBase;
      this.rotation = 0;
      this.armL.y = 0;
      this.armR.y = 0;
    }
    if (this.bubble.visible) {
      this.bubble.y = Math.sin(t * 0.005 + this.bobPhase) * 0.6;
    }
  }
}
