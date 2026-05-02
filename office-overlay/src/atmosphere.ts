import { Container, Graphics } from "pixi.js";

interface Particle {
  g: Graphics;
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  ttl: number;
}

export class SteamSystem extends Container {
  private particles: Particle[] = [];
  private spawnTimer = 0;
  constructor(originX: number, originY: number) {
    super();
    this.x = originX;
    this.y = originY;
  }
  tick(dtMs: number) {
    this.spawnTimer += dtMs;
    if (this.spawnTimer > 400) {
      this.spawnTimer = 0;
      this.spawn();
    }
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life += dtMs;
      p.x += p.vx * (dtMs / 16);
      p.y += p.vy * (dtMs / 16);
      const k = p.life / p.ttl;
      p.g.x = p.x;
      p.g.y = p.y;
      p.g.alpha = Math.max(0, 0.6 * (1 - k));
      p.g.scale.set(1 + k * 1.5);
      if (p.life >= p.ttl) {
        this.removeChild(p.g);
        p.g.destroy();
        this.particles.splice(i, 1);
      }
    }
  }
  private spawn() {
    const g = new Graphics();
    g.circle(0, 0, 1.6).fill({ color: 0xffffff, alpha: 0.6 });
    this.addChild(g);
    this.particles.push({
      g,
      x: (Math.random() - 0.5) * 2,
      y: 0,
      vx: (Math.random() - 0.5) * 0.15,
      vy: -0.4,
      life: 0,
      ttl: 1500 + Math.random() * 600,
    });
  }
}

export function pulseGlow(g: Graphics, t: number) {
  g.alpha = 0.7 + Math.sin(t * 0.002) * 0.15;
}

export function pulseMonitor(monitors: Graphics[], t: number) {
  for (let i = 0; i < monitors.length; i++) {
    monitors[i].alpha = 0.92 + Math.sin(t * 0.003 + i * 0.7) * 0.08;
  }
}
