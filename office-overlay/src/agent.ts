import { Container, Graphics, Text } from "pixi.js";
import { AgentDef, AgentState, AgentStatus, STATUS_COLORS } from "./agents";
import { TILE } from "./room";

export class AgentSprite extends Container {
  private body: Graphics;
  private head: Graphics;
  private letter: Text;
  private statusDot: Graphics;
  private bubble: Text;
  private bobBase: number;
  private bobPhase: number;
  public state: AgentState = { status: "STANDBY", task: "", ts: "" };

  constructor(public def: AgentDef, deskX: number, deskY: number) {
    super();
    this.x = deskX * TILE;
    this.y = deskY * TILE;
    this.bobBase = this.y;
    this.bobPhase = Math.random() * Math.PI * 2;

    this.body = new Graphics();
    this.body
      .roundRect(-4, -4, 12, 10, 2)
      .fill(def.color)
      .stroke({ color: 0x1a1530, width: 1 });
    this.addChild(this.body);

    this.head = new Graphics();
    this.head
      .circle(2, -8, 4)
      .fill(0xfde0c7)
      .stroke({ color: 0x1a1530, width: 1 });
    this.addChild(this.head);

    this.letter = new Text({
      text: def.name[0],
      style: {
        fontFamily: "monospace",
        fontSize: 6,
        fill: 0x1a1530,
        fontWeight: "bold",
      },
    });
    this.letter.anchor.set(0.5);
    this.letter.x = 2;
    this.letter.y = -8;
    this.addChild(this.letter);

    this.statusDot = new Graphics();
    this.statusDot
      .circle(8, -12, 2)
      .fill(STATUS_COLORS.STANDBY)
      .stroke({ color: 0x1a1530, width: 0.5 });
    this.addChild(this.statusDot);

    this.bubble = new Text({
      text: "",
      style: {
        fontFamily: "monospace",
        fontSize: 8,
        fill: 0xffffff,
      },
    });
    this.bubble.anchor.set(0.5, 1);
    this.bubble.x = 2;
    this.bubble.y = -16;
    this.bubble.visible = false;
    this.addChild(this.bubble);

    this.eventMode = "static";
    this.cursor = "pointer";
    this.hitArea = { contains: (x: number, y: number) => x > -6 && x < 10 && y > -14 && y < 8 };
  }

  setState(state: AgentState) {
    this.state = state;
    this.statusDot.clear();
    this.statusDot
      .circle(8, -12, 2)
      .fill(STATUS_COLORS[state.status as AgentStatus] ?? STATUS_COLORS.STANDBY)
      .stroke({ color: 0x1a1530, width: 0.5 });
    this.bubble.text = this.bubbleFor(state.status as AgentStatus);
    this.bubble.visible = state.status !== "STANDBY";
  }

  private bubbleFor(s: AgentStatus): string {
    switch (s) {
      case "WORKING": return "*";
      case "IDLE": return "?";
      default: return "";
    }
  }

  tick(dt: number, t: number) {
    if (this.state.status === "WORKING") {
      this.y = this.bobBase + Math.sin(t * 0.008 + this.bobPhase) * 0.6;
    } else if (this.state.status === "IDLE") {
      this.y = this.bobBase + Math.sin(t * 0.003 + this.bobPhase) * 1.2;
    } else {
      this.y = this.bobBase;
    }
    void dt;
  }
}
