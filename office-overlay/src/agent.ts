import { Container, Graphics, Sprite, Text } from "pixi.js";
import { AgentDef, AgentState, AgentStatus, STATUS_COLORS } from "./agents";
import { TILE } from "./room";
import { CHAR_TILES, tile } from "./kenney";

export class AgentSprite extends Container {
  private body: Sprite;
  private statusDot: Graphics;
  private bubble: Container;
  private bubbleTxt: Text;
  private bobBase: number;
  private bobPhase: number;
  public state: AgentState = { status: "STANDBY", task: "", ts: "" };

  constructor(public def: AgentDef, deskX: number, deskY: number) {
    super();
    this.x = deskX * TILE + TILE / 2;
    this.y = deskY * TILE + TILE - 4;
    this.bobBase = this.y;
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
      this.body.rotation = Math.sin(t * 0.025 + this.bobPhase) * 0.04;
    } else if (this.state.status === "IDLE") {
      this.y = this.bobBase + Math.sin(t * 0.004 + this.bobPhase) * 1.2;
      this.body.rotation = Math.sin(t * 0.004 + this.bobPhase) * 0.06;
    } else {
      this.y = this.bobBase;
      this.body.rotation = 0;
    }
    if (this.bubble.visible) {
      this.bubble.y = Math.sin(t * 0.005 + this.bobPhase) * 0.6;
    }
  }
}
