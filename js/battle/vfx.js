// ═══════════════════════════════════════════
//  battle/vfx.js — VFX, particles, animations
// ═══════════════════════════════════════════
Object.assign(G, {
    vfxParts: [], vfxRaf: null,
    vfxInit() {
        const cv = document.getElementById('vfx-canvas');
        const w = document.getElementById('iso-world');
        cv.width = parseInt(w.style.width) || 2000; cv.height = parseInt(w.style.height) || 2000;
    },
    vfxSpawn(x, y, opts) {
        const cnt = opts.count || 8;
        for (let i = 0; i < cnt; i++) {
            this.vfxParts.push({
                x: x + (Math.random() - .5) * (opts.spread || 10),
                y: y + (Math.random() - .5) * (opts.spread || 10),
                vx: (Math.random() - .5) * (opts.speed || 2),
                vy: opts.vy !== undefined ? (opts.vy + (Math.random() - .5)) : (-Math.random() * (opts.speed || 2)),
                life: 1, decay: opts.decay || (0.015 + Math.random() * 0.02),
                size: opts.size || (2 + Math.random() * 3),
                color: opts.colors[Math.floor(Math.random() * opts.colors.length)],
                shape: opts.shape || 'circle',
                gravity: opts.gravity || 0,
                trail: opts.trail || false,
                rotation: Math.random() * Math.PI * 2,
                rotSpd: (Math.random() - .5) * 0.2
            });
        }
        if (!this.vfxRaf) this.vfxLoop();
    },
    vfxLoop() {
        const cv = document.getElementById('vfx-canvas'); if (!cv) return;
        const ctx = cv.getContext('2d'); ctx.clearRect(0, 0, cv.width, cv.height);
        for (let i = this.vfxParts.length - 1; i >= 0; i--) {
            const p = this.vfxParts[i];
            p.x += p.vx; p.y += p.vy; p.vy += p.gravity; p.life -= p.decay; p.rotation += p.rotSpd;
            if (p.life <= 0) { this.vfxParts.splice(i, 1); continue }
            ctx.save(); ctx.globalAlpha = p.life; ctx.fillStyle = p.color;
            ctx.shadowColor = p.color; ctx.shadowBlur = p.size * p.life * 2.5;
            ctx.translate(p.x, p.y); ctx.rotate(p.rotation);
            if (p.shape === 'circle') { ctx.beginPath(); ctx.arc(0, 0, p.size * p.life, 0, Math.PI * 2); ctx.fill() }
            else if (p.shape === 'star') { this.drawStar(ctx, 0, 0, p.size * p.life) }
            else if (p.shape === 'slash') {
                ctx.strokeStyle = p.color; ctx.lineWidth = p.size * p.life * 0.8; ctx.lineCap = 'round';
                ctx.beginPath(); ctx.moveTo(-p.size * 2.5, p.size * 2.5); ctx.lineTo(p.size * 2.5, -p.size * 2.5); ctx.stroke()
            }
            else if (p.shape === 'spark') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 1.5; ctx.beginPath();
                ctx.moveTo(0, 0); ctx.lineTo(-p.vx * 4, -p.vy * 4); ctx.stroke();
                ctx.beginPath(); ctx.arc(0, 0, p.size * p.life * 0.6, 0, Math.PI * 2); ctx.fill()
            }
            else if (p.shape === 'ring') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 2 * p.life;
                ctx.beginPath(); ctx.arc(0, 0, p.size * (1 - p.life) * 3.5 + 2, 0, Math.PI * 2); ctx.stroke()
            }
            else if (p.shape === 'arrow') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 2 * p.life; ctx.lineCap = 'round';
                ctx.beginPath(); ctx.moveTo(0, p.size * 3); ctx.lineTo(0, -p.size * 3);
                ctx.moveTo(-p.size, -p.size); ctx.lineTo(0, -p.size * 3); ctx.lineTo(p.size, -p.size); ctx.stroke()
            }
            else if (p.shape === 'diamond') {
                ctx.beginPath(); const s = p.size * p.life;
                ctx.moveTo(0, -s); ctx.lineTo(s, 0); ctx.lineTo(0, s); ctx.lineTo(-s, 0); ctx.closePath(); ctx.fill()
            }
            else if (p.shape === 'cross') {
                ctx.strokeStyle = p.color; ctx.lineWidth = p.size * p.life * 0.5; ctx.lineCap = 'round';
                const s = p.size * 2; ctx.beginPath();
                ctx.moveTo(-s, 0); ctx.lineTo(s, 0); ctx.moveTo(0, -s); ctx.lineTo(0, s); ctx.stroke()
            }
            ctx.restore();
        }
        if (this.vfxParts.length) this.vfxRaf = requestAnimationFrame(() => this.vfxLoop());
        else { this.vfxRaf = null; ctx.clearRect(0, 0, cv.width, cv.height) }
    },
    drawStar(ctx, x, y, r) {
        ctx.beginPath(); for (let i = 0; i < 5; i++) {
            ctx.lineTo(x + r * Math.cos(i * 1.256 - .785), y + r * Math.sin(i * 1.256 - .785));
            ctx.lineTo(x + r * .4 * Math.cos(i * 1.256 + .628 - .785), y + r * .4 * Math.sin(i * 1.256 + .628 - .785))
        } ctx.closePath(); ctx.fill()
    },

    vfxAtk(attacker, target) {
        this.faceDir(attacker.id, target.x - attacker.x, target.y - attacker.y);
        this.atkAnimU(attacker.id);
        const ax = this.uSX(attacker.x, attacker.y) + UCX, ay = this.uSY(attacker.x, attacker.y) + UCY;
        const tx = this.uSX(target.x, target.y) + UCX, ty = this.uSY(target.x, target.y) + UCY;
        const cls = attacker.cls;
        if (cls === 'warrior') {
            this.vfxSpawn(tx, ty, { count: 16, colors: ['#fff', '#aaddff', '#88bbff'], shape: 'slash', speed: 4, spread: 14, decay: 0.035, size: 5 });
            this.vfxSpawn(tx, ty, { count: 10, colors: ['#ffffff', '#aaddff'], shape: 'spark', speed: 5, spread: 10, decay: 0.025, size: 3 });
            this.vfxSpawn(tx, ty, { count: 2, colors: ['#ffffff33'], shape: 'ring', speed: 0, spread: 2, decay: 0.025, size: 10 });
        } else if (cls === 'knight') {
            this.vfxSpawn(tx, ty, { count: 20, colors: ['#ffcc44', '#ff8800', '#ffffff'], shape: 'circle', speed: 3, spread: 10, decay: 0.018, size: 5, gravity: 0.08 });
            this.vfxSpawn(tx, ty, { count: 4, colors: ['#ffcc4455'], shape: 'ring', speed: 0, spread: 3, decay: 0.018, size: 14 });
            this.vfxSpawn(tx, ty, { count: 6, colors: ['#fff', '#ffcc44'], shape: 'spark', speed: 4, spread: 6, decay: 0.03, size: 2 });
        } else if (cls === 'assassin') {
            for (let i = 0; i < 4; i++) setTimeout(() => {
                this.vfxSpawn(tx + (Math.random() - .5) * 14, ty + (Math.random() - .5) * 14, { count: 8, colors: ['#cc44ff', '#ff44cc', '#ffffff'], shape: 'slash', speed: 5, spread: 10, decay: 0.04, size: 4 })
            }, i * 50);
            this.vfxSpawn(ax, ay, { count: 12, colors: ['#cc44ff66', '#8844ff66'], shape: 'diamond', speed: 2, spread: 18, decay: 0.025, size: 5 });
            this.vfxSpawn(tx, ty, { count: 3, colors: ['#cc44ff33'], shape: 'ring', speed: 0, spread: 3, decay: 0.02, size: 12 });
        } else if (cls === 'mage') {
            this.vfxSpawn(tx, ty, { count: 5, colors: ['#4488ff44'], shape: 'ring', speed: 0, spread: 5, decay: 0.01, size: 18 });
            this.vfxSpawn(tx, ty, { count: 25, colors: ['#4488ff', '#88aaff', '#aaccff', '#ffffff'], shape: 'star', speed: 4, spread: 12, decay: 0.02, size: 4 });
            this.vfxSpawn(tx, ty, { count: 12, colors: ['#4488ff', '#ffffff'], shape: 'spark', speed: 6, spread: 6, decay: 0.018, size: 3 });
            setTimeout(() => this.vfxSpawn(tx, ty, { count: 8, colors: ['#88aaff', '#ffffff'], shape: 'circle', speed: 2, spread: 14, decay: 0.025, size: 2, vy: -1.5 }), 80);
        } else if (cls === 'archer') {
            const dx = tx - ax, dy = ty - ay, dist = Math.sqrt(dx * dx + dy * dy);
            const steps = Math.max(5, Math.floor(dist / 10));
            for (let i = 0; i < steps; i++) {
                const tt = i / steps;
                setTimeout(() => this.vfxSpawn(ax + dx * tt, ay + dy * tt, { count: 3, colors: ['#ffdd88', '#ffffff'], shape: 'spark', speed: 1.5, spread: 4, decay: 0.05, size: 2 }), i * 18)
            }
            setTimeout(() => {
                this.vfxSpawn(tx, ty, { count: 12, colors: ['#ffdd44', '#ff8844', '#ffffff'], shape: 'spark', speed: 4, spread: 8, decay: 0.025, size: 3 });
                this.vfxSpawn(tx, ty, { count: 2, colors: ['#ffdd4444'], shape: 'ring', speed: 0, spread: 2, decay: 0.025, size: 10 });
            }, steps * 18);
        } else if (cls === 'priest') {
            this.vfxSpawn(tx, ty, { count: 14, colors: ['#ffffff', '#ffffaa', '#ffe066'], shape: 'star', speed: 2.5, spread: 12, decay: 0.02, size: 4 });
            this.vfxSpawn(tx, ty, { count: 3, colors: ['#ffffaa33'], shape: 'ring', speed: 0, spread: 3, decay: 0.018, size: 12 });
        } else if (cls === 'novice') {
            this.vfxSpawn(tx, ty, { count: 8, colors: ['#cccccc', '#ffffff', '#aaaaaa'], shape: 'spark', speed: 3, spread: 10, decay: 0.035, size: 3 });
            this.vfxSpawn(tx, ty, { count: 4, colors: ['#cccccc'], shape: 'circle', speed: 1.5, spread: 6, decay: 0.03, size: 2, gravity: 0.1 });
        } else if (cls === 'brawler') {
            for (let i = 0; i < 4; i++) setTimeout(() => {
                this.vfxSpawn(tx + (Math.random() - .5) * 12, ty + (Math.random() - .5) * 12, { count: 7, colors: ['#f97316', '#fbbf24', '#ffffff'], shape: 'slash', speed: 5, spread: 8, decay: 0.04, size: 4 })
            }, i * 40);
            this.vfxSpawn(tx, ty, { count: 5, colors: ['#ffffff44'], shape: 'ring', speed: 0, spread: 3, decay: 0.025, size: 12 });
            this.vfxSpawn(tx, ty, { count: 6, colors: ['#f97316', '#ff4400'], shape: 'spark', speed: 5, spread: 8, decay: 0.03, size: 3 });
        } else if (cls === 'lancer') {
            const dx = tx - ax, dy = ty - ay, dist = Math.sqrt(dx * dx + dy * dy) || 1;
            const nx = dx / dist, ny = dy / dist;
            for (let i = 0; i < 6; i++) {
                const px = tx - nx * i * 6, py = ty - ny * i * 6;
                setTimeout(() => this.vfxSpawn(px, py, { count: 4, colors: ['#60a5fa', '#3b82f6', '#ffffff'], shape: 'spark', speed: 6, spread: 5, decay: 0.04, size: 3 }), i * 25);
            }
            this.vfxSpawn(tx, ty, { count: 12, colors: ['#60a5fa', '#93c5fd', '#ffffff'], shape: 'spark', speed: 5, spread: 10, decay: 0.025, size: 4 });
            this.vfxSpawn(tx, ty, { count: 3, colors: ['#60a5fa44'], shape: 'ring', speed: 0, spread: 3, decay: 0.02, size: 12 });
        } else if (cls === 'sapper') {
            this.vfxSpawn(tx, ty, { count: 14, colors: ['#f97316', '#ff6600', '#ffcc00'], shape: 'spark', speed: 4, spread: 12, decay: 0.03, size: 4 });
            this.vfxSpawn(tx, ty, { count: 6, colors: ['#aaaaaa', '#888888'], shape: 'circle', speed: 2, spread: 8, decay: 0.02, size: 3, gravity: 0.08 });
            this.vfxSpawn(tx, ty, { count: 2, colors: ['#ff660044'], shape: 'ring', speed: 0, spread: 2, decay: 0.025, size: 10 });
        } else if (cls === 'summoner') {
            this.vfxSpawn(tx, ty, { count: 18, colors: ['#8b5cf6', '#c084fc', '#e9d5ff', '#ffffff'], shape: 'star', speed: 3, spread: 14, decay: 0.018, size: 4 });
            this.vfxSpawn(tx, ty, { count: 5, colors: ['#8b5cf644'], shape: 'ring', speed: 0, spread: 4, decay: 0.012, size: 16 });
            setTimeout(() => this.vfxSpawn(tx, ty, { count: 8, colors: ['#c084fc', '#fff'], shape: 'diamond', speed: 2, spread: 10, decay: 0.025, size: 3, vy: -1 }), 60);
        } else if (cls === 'shaman') {
            this.vfxSpawn(tx, ty, { count: 14, colors: ['#22c55e', '#4ade80', '#9333ea'], shape: 'diamond', speed: 3, spread: 14, decay: 0.02, size: 4 });
            this.vfxSpawn(tx, ty, { count: 6, colors: ['#9333ea44', '#22c55e44'], shape: 'ring', speed: 0, spread: 5, decay: 0.015, size: 14 });
            this.vfxSpawn(tx, ty, { count: 8, colors: ['#22c55e', '#9333ea', '#fff'], shape: 'spark', speed: 4, spread: 10, decay: 0.025, size: 3 });
        }
    },

    vfxHeal(target) {
        const tx = this.uSX(target.x, target.y) + UCX, ty = this.uSY(target.x, target.y) + UCY;
        this.vfxSpawn(tx, ty, {
            count: 18, colors: ['#44ff88', '#88ffaa', '#aaffcc', '#ffffff'], shape: 'circle',
            speed: 1.5, spread: 14, decay: 0.018, size: 3, vy: -1.5, gravity: -0.02
        });
        this.vfxSpawn(tx, ty, { count: 5, colors: ['#44ff8844'], shape: 'ring', speed: 0, spread: 3, decay: 0.015, size: 14 });
        this.vfxSpawn(tx, ty, { count: 8, colors: ['#aaffcc', '#ffffff'], shape: 'star', speed: 1, spread: 10, decay: 0.02, size: 2.5, vy: -2, gravity: -0.01 });
    },

    vfxDeath(unit) {
        const tx = this.uSX(unit.x, unit.y) + UCX, ty = this.uSY(unit.x, unit.y) + UCY;
        const baseColor = unit.team === 'ally' ? ['#3b82f6', '#60a5fa', '#93c5fd', '#bfdbfe'] : ['#ef4444', '#f87171', '#fca5a5', '#fecaca'];
        this.vfxSpawn(tx, ty, { count: 25, colors: [...baseColor, '#ffffff88'], shape: 'diamond', speed: 1.5, spread: 16, decay: 0.012, size: 3, gravity: 0.03, vy: -.5 });
        this.vfxSpawn(tx, ty, { count: 10, colors: ['#ffffff44'], shape: 'circle', speed: .8, spread: 12, decay: 0.01, size: 2, vy: -1, gravity: -0.01 });
    },

    vfxBuff(unit) {
        const el = document.getElementById('u-' + unit.id);
        if (el) { el.classList.add('buff-glow'); setTimeout(() => el.classList.remove('buff-glow'), 500) }
        const tx = this.uSX(unit.x, unit.y) + UCX, ty = this.uSY(unit.x, unit.y) + UCY;
        this.vfxSpawn(tx, ty, { count: 8, colors: ['#22c55e', '#4ade80', '#ffffff'], shape: 'star', speed: 1.5, spread: 12, decay: 0.025, size: 2.5, vy: -1 });
    },

    vfxFlash(color) {
        const el = document.getElementById('turn-flash');
        el.style.background = `radial-gradient(ellipse, ${color}, transparent 70%)`;
        el.classList.remove('skill-flash'); void el.offsetWidth;
        el.classList.add('skill-flash');
        setTimeout(() => { el.classList.remove('skill-flash'); el.style.background = '' }, 400);
    },

    screenShake(heavy) {
        const w = document.getElementById('iso-world');
        const cls = heavy ? 'screen-shake-heavy' : 'screen-shake';
        const dur = heavy ? 450 : 300;
        w.classList.remove('screen-shake', 'screen-shake-heavy'); void w.offsetWidth; w.classList.add(cls);
        setTimeout(() => w.classList.remove(cls), dur);
    },

    turnFlash(type) {
        const el = document.getElementById('turn-flash');
        el.classList.remove('player-flash', 'enemy-flash'); void el.offsetWidth;
        el.classList.add(type + '-flash'); setTimeout(() => el.classList.remove(type + '-flash'), 600);
    },

    _g2sx(gdx, gdy) { const d=gdx||0,r=gdy||0; switch(this.camDir){case 0:return d-r;case 1:return -r-d;case 2:return r-d;default:return r+d} },
    faceDir(id, gdx, gdy) {
        if (!gdx && !gdy) return;
        const u = this.units.find(v => v.id === id);
        if (u) { u._gdx = gdx; u._gdy = gdy }
        this._applyFace(id);
    },
    _applyFace(id) {
        const el = document.getElementById('u-' + id); if (!el) return;
        const u = this.units.find(v => v.id === id); if (!u) return;
        const sdx = this._g2sx(u._gdx, u._gdy);
        if (!sdx) return;
        const img = el.querySelector('.u-icon img');
        if (img) img.style.transform = sdx < 0 ? 'scaleX(-1)' : '';
    },
    _mvU(u, nx, ny) { u._gdx = nx - u.x; u._gdy = ny - u.y; u.x = nx; u.y = ny; this.animU(u.id, nx, ny) },
    animU(id, x, y) {
        const el = document.getElementById('u-' + id); if (el) {
            el.classList.add('moving'); setTimeout(() => el.classList.remove('moving'), 340);
            const u = this.units.find(v => v.id === id);
            if (u && (u._gdx || u._gdy)) this._applyFace(id);
            el.style.left = this.uSX(x, y) + 'px'; el.style.top = this.uSY(x, y) + 'px';
            const v = this.g2v(x, y); el.style.zIndex = 100 + v.vc + v.vr
        }
    },
    shakeU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('shaking'); setTimeout(() => el.classList.remove('shaking'), 300) } },
    atkAnimU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('attacking'); setTimeout(() => el.classList.remove('attacking'), 380) } },
    deathA(id) { const el = document.getElementById('u-' + id); if (el) el.classList.add('dying') },
});
