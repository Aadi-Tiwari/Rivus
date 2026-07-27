"use client";

import { useEffect, useRef } from "react";

// Interactive particle field, ported from the Echoes background. Same motion,
// repulsion and connection lines; the warm-gold palette is replaced with the
// water blues so it sits under this system instead of fighting it.
const COLORS = ["#2E6FA8", "#3D8FC4", "#1E4E78", "#6FA8D8", "#BFE9FF", "#255C86"];
const CONN_RGB = [61, 124, 148]; // the same slate-blue the pipes are drawn in

const PARTICLE_COUNT = 120;
const BASE_SPEED = 1.4;
const BASE_SIZE = 2;
const CONN_DIST = 130;
// Trail fade. Matches the page ground so the buildup settles to the app's own black.
const BG_ALPHA = "rgba(0, 7, 15, 0.18)";

export function ParticleBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animId: number;

    function resize() {
      if (!canvas) return;
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    }
    resize();

    // Mouse is tracked on the window so the canvas can stay pointer-events:none
    // and never intercept a click on the console above it.
    let mouseX = canvas.width / 2;
    let mouseY = canvas.height / 2;
    function onMouseMove(e: MouseEvent) {
      mouseX = e.clientX;
      mouseY = e.clientY;
    }
    window.addEventListener("mousemove", onMouseMove);

    class Particle {
      x: number;
      y: number;
      size: number;
      speedX: number;
      speedY: number;
      baseSpeedX: number;
      baseSpeedY: number;
      color: string;

      constructor() {
        this.x = Math.random() * canvas!.width;
        this.y = Math.random() * canvas!.height;
        this.size = Math.random() * BASE_SIZE * 1.5 + 0.5;
        this.baseSpeedX = (Math.random() * 2 - 1) * BASE_SPEED;
        this.baseSpeedY = (Math.random() * 2 - 1) * BASE_SPEED;
        this.speedX = this.baseSpeedX;
        this.speedY = this.baseSpeedY;
        this.color = COLORS[Math.floor(Math.random() * COLORS.length)];
      }

      update() {
        const dx = this.x - mouseX;
        const dy = this.y - mouseY;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 120 && dist > 0) {
          const angle = Math.atan2(dy, dx);
          const force = (120 - dist) / 12;
          this.speedX += Math.cos(angle) * force * 0.18;
          this.speedY += Math.sin(angle) * force * 0.18;
        }

        const maxSpeed = BASE_SPEED * 2.5;
        this.speedX = Math.max(-maxSpeed, Math.min(maxSpeed, this.speedX));
        this.speedY = Math.max(-maxSpeed, Math.min(maxSpeed, this.speedY));

        // Drift back toward the natural velocity after a push
        this.speedX = this.speedX * 0.97 + this.baseSpeedX * 0.03;
        this.speedY = this.speedY * 0.97 + this.baseSpeedY * 0.03;

        this.x += this.speedX;
        this.y += this.speedY;

        const W = canvas!.width;
        const H = canvas!.height;
        if (this.x < 0) this.x = W;
        if (this.x > W) this.x = 0;
        if (this.y < 0) this.y = H;
        if (this.y > H) this.y = 0;
      }

      draw() {
        ctx!.beginPath();
        ctx!.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx!.fillStyle = this.color;
        ctx!.fill();
      }
    }

    const particles: Particle[] = [];
    for (let i = 0; i < PARTICLE_COUNT; i++) particles.push(new Particle());

    function animate() {
      if (!canvas || !ctx) return;
      animId = requestAnimationFrame(animate);

      ctx.fillStyle = BG_ALPHA;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      for (const p of particles) {
        p.update();
        p.draw();
      }

      const [r, g, b] = CONN_RGB;
      ctx.lineWidth = 0.5;
      for (let i = 0; i < particles.length; i++) {
        // Inner loop is capped so this stays linear rather than O(n^2)
        const limit = Math.min(particles.length, i + 14);
        for (let j = i + 1; j < limit; j++) {
          const dx = particles[i].x - particles[j].x;
          const dy = particles[i].y - particles[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < CONN_DIST) {
            const opacity = (1 - dist / CONN_DIST) * 0.17;
            ctx.strokeStyle = `rgba(${r},${g},${b},${opacity})`;
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.stroke();
          }
        }
      }
    }

    animId = requestAnimationFrame(animate);
    window.addEventListener("resize", resize);

    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener("resize", resize);
      window.removeEventListener("mousemove", onMouseMove);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      style={{
        position: "fixed",
        inset: 0,
        width: "100%",
        height: "100%",
        pointerEvents: "none",
        zIndex: 0,
      }}
    />
  );
}
