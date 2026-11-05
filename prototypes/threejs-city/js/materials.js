import * as THREE from 'three';

function canvasTexture(canvas) {
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.needsUpdate = true;
  return tex;
}

function std(params) {
  return new THREE.MeshStandardMaterial({ roughness: 0.86, metalness: 0, ...params });
}

function noiseFill(ctx, w, h, color, amount) {
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, w, h);
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (Math.random() - 0.5) * amount;
    d[i] = Math.max(0, Math.min(255, d[i] + n));
    d[i + 1] = Math.max(0, Math.min(255, d[i + 1] + n));
    d[i + 2] = Math.max(0, Math.min(255, d[i + 2] + n));
  }
  ctx.putImageData(img, 0, 0);
}

function stoneTexture(base, joint, blocksX, blocksY) {
  const w = 512;
  const h = 512;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  noiseFill(g, w, h, base, 14);
  g.strokeStyle = joint;
  g.lineWidth = 3;
  const bw = w / blocksX;
  const bh = h / blocksY;
  for (let y = 0; y <= blocksY; y++) {
    g.beginPath();
    g.moveTo(0, y * bh + 0.5);
    g.lineTo(w, y * bh + 0.5);
    g.stroke();
  }
  for (let y = 0; y < blocksY; y++) {
    const shift = y % 2 ? bw / 2 : 0;
    for (let x = -1; x <= blocksX; x++) {
      g.beginPath();
      g.moveTo(x * bw + shift, y * bh);
      g.lineTo(x * bw + shift, (y + 1) * bh);
      g.stroke();
    }
  }
  return canvasTexture(c);
}

function roofTexture() {
  const w = 256;
  const h = 256;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  g.fillStyle = '#a6533c';
  g.fillRect(0, 0, w, h);
  for (let y = 0; y < h; y += 18) {
    for (let x = -20; x < w; x += 22) {
      const ox = (y / 18) % 2 ? 11 : 0;
      g.fillStyle = (x + y) % 44 === 0 ? '#b8644a' : '#9a4a36';
      g.beginPath();
      g.ellipse(x + ox + 11, y + 10, 12, 8, 0, Math.PI, 0);
      g.fill();
      g.strokeStyle = '#7c3a2b';
      g.lineWidth = 1;
      g.stroke();
    }
  }
  const tex = canvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(2, 2);
  return tex;
}

export function makeFacade({ faceW, faceH, floors, cols, wall, base, trim, frame, glassTop, glassBot, curtain, shop }) {
  const canvasH = 640;
  const canvasW = Math.max(180, Math.round(canvasH * (faceW / faceH)));
  const c = document.createElement('canvas');
  c.width = canvasW;
  c.height = canvasH;
  const g = c.getContext('2d');
  noiseFill(g, canvasW, canvasH, wall, 12);
  const groundH = canvasH * (shop ? 0.22 : 0.16);
  g.fillStyle = base;
  g.fillRect(0, canvasH - groundH, canvasW, groundH);
  g.fillStyle = trim;
  g.fillRect(0, canvasH - groundH - 6, canvasW, 8);

  const upperH = canvasH - groundH - 10;
  const fh = upperH / floors;
  for (let f = 0; f < floors; f++) {
    const top = 8 + f * fh;
    g.fillStyle = trim;
    g.fillRect(0, top, canvasW, 4);
    for (let col = 0; col < cols; col++) {
      const cw = canvasW / cols;
      const ww = cw * 0.5;
      const wh = fh * 0.55;
      const wx = col * cw + (cw - ww) / 2;
      const wy = top + fh * 0.22;
      g.fillStyle = frame;
      g.fillRect(wx - 4, wy - 4, ww + 8, wh + 8);
      const grd = g.createLinearGradient(0, wy, 0, wy + wh);
      grd.addColorStop(0, glassTop);
      grd.addColorStop(1, glassBot);
      g.fillStyle = grd;
      g.fillRect(wx, wy, ww, wh);
      g.fillStyle = 'rgba(255,255,255,0.28)';
      g.fillRect(wx + 3, wy + 3, ww * 0.22, wh * 0.45);
      g.fillStyle = frame;
      g.fillRect(wx + ww / 2 - 1.5, wy, 3, wh);
      if ((f + col) % 3 === 0) {
        g.globalAlpha = 0.45;
        g.fillStyle = curtain;
        g.fillRect(wx + 3, wy + 3, ww * 0.42, wh - 6);
        g.globalAlpha = 1;
      }
    }
  }

  const gcols = shop ? Math.max(2, cols - 1) : cols;
  for (let col = 0; col < gcols; col++) {
    const cw = canvasW / gcols;
    const ww = cw * (shop ? 0.62 : 0.42);
    const wh = groundH * (shop ? 0.62 : 0.55);
    const wx = col * cw + (cw - ww) / 2;
    const wy = canvasH - groundH + groundH * 0.18;
    g.fillStyle = frame;
    g.fillRect(wx - 4, wy - 4, ww + 8, wh + 8);
    g.fillStyle = shop ? '#163044' : glassBot;
    g.fillRect(wx, wy, ww, wh);
    if (shop) {
      g.fillStyle = 'rgba(186, 230, 245, 0.35)';
      g.fillRect(wx + 4, wy + 4, ww * 0.28, wh * 0.55);
    }
  }
  return canvasTexture(c);
}

function glassCurtain(floors, cols) {
  const w = 384;
  const h = 768;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  const sky = g.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, '#d5edf6');
  sky.addColorStop(0.45, '#8ec3d8');
  sky.addColorStop(1, '#5f93ad');
  g.fillStyle = sky;
  g.fillRect(0, 0, w, h);
  g.strokeStyle = '#e7eef2';
  g.lineWidth = 4;
  const fh = h / floors;
  const cw = w / cols;
  for (let y = 0; y <= floors; y++) {
    g.beginPath();
    g.moveTo(0, y * fh);
    g.lineTo(w, y * fh);
    g.stroke();
  }
  for (let x = 0; x <= cols; x++) {
    g.beginPath();
    g.moveTo(x * cw, 0);
    g.lineTo(x * cw, h);
    g.stroke();
  }
  for (let f = 0; f < floors; f++) {
    for (let col = 0; col < cols; col++) {
      if ((f * 5 + col * 3) % 7 === 0) {
        g.fillStyle = 'rgba(12, 42, 62, 0.28)';
        g.fillRect(col * cw + 6, f * fh + 6, cw - 12, fh - 12);
      } else if ((f + col) % 4 === 0) {
        g.fillStyle = 'rgba(255,255,255,0.22)';
        g.fillRect(col * cw + 8, f * fh + 8, cw * 0.22, fh * 0.35);
      }
    }
  }
  return canvasTexture(c);
}

export function turkishFlagTexture() {
  const w = 300;
  const h = 200;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  g.fillStyle = '#E30A17';
  g.fillRect(0, 0, w, h);
  g.fillStyle = '#fff';
  g.beginPath();
  g.arc(112, 100, 48, 0, Math.PI * 2);
  g.arc(128, 100, 38, 0, Math.PI * 2, true);
  g.fill('evenodd');
  star(g, 168, 100, 22, 9);
  g.fill();
  return canvasTexture(c);
}

function star(ctx, x, y, outer, inner, points = 5) {
  ctx.beginPath();
  for (let i = 0; i < points * 2; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = -Math.PI / 2 + (i * Math.PI) / points;
    const px = x + Math.cos(a) * r;
    const py = y + Math.sin(a) * r;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
}

export function clockTexture() {
  const s = 256;
  const c = document.createElement('canvas');
  c.width = s;
  c.height = s;
  const g = c.getContext('2d');
  g.fillStyle = '#f4efe4';
  g.beginPath();
  g.arc(128, 128, 120, 0, Math.PI * 2);
  g.fill();
  g.strokeStyle = '#2c3338';
  g.lineWidth = 8;
  g.stroke();
  g.fillStyle = '#2c3338';
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2 - Math.PI / 2;
    const r1 = i % 3 === 0 ? 88 : 98;
    g.beginPath();
    g.arc(128 + Math.cos(a) * 104, 128 + Math.sin(a) * 104, i % 3 === 0 ? 5 : 3, 0, Math.PI * 2);
    g.fill();
    void r1;
  }
  g.lineCap = 'round';
  g.lineWidth = 8;
  g.beginPath();
  g.moveTo(128, 128);
  g.lineTo(128 + Math.cos(-Math.PI / 2 + 0.4) * 52, 128 + Math.sin(-Math.PI / 2 + 0.4) * 52);
  g.stroke();
  g.lineWidth = 5;
  g.beginPath();
  g.moveTo(128, 128);
  g.lineTo(128 + Math.cos(-Math.PI / 2 + 2.2) * 74, 128 + Math.sin(-Math.PI / 2 + 2.2) * 74);
  g.stroke();
  g.fillStyle = '#E30A17';
  g.beginPath();
  g.arc(128, 128, 6, 0, Math.PI * 2);
  g.fill();
  return canvasTexture(c);
}

export function emblemTexture() {
  const s = 256;
  const c = document.createElement('canvas');
  c.width = s;
  c.height = s;
  const g = c.getContext('2d');
  g.clearRect(0, 0, s, s);
  g.fillStyle = '#f7f1e6';
  g.beginPath();
  g.arc(128, 128, 118, 0, Math.PI * 2);
  g.fill();
  g.strokeStyle = '#6e2436';
  g.lineWidth = 14;
  g.stroke();
  g.strokeStyle = '#c6a15a';
  g.lineWidth = 6;
  g.beginPath();
  g.arc(128, 128, 96, 0, Math.PI * 2);
  g.stroke();
  g.fillStyle = '#8e3048';
  star(g, 128, 132, 58, 24);
  g.fill();
  return canvasTexture(c);
}

export function signTexture(text, bg, fg) {
  const c = document.createElement('canvas');
  c.width = 512;
  c.height = 160;
  const g = c.getContext('2d');
  g.fillStyle = bg;
  g.fillRect(0, 0, 512, 160);
  g.fillStyle = fg;
  g.font = '700 86px "Liberation Sans", "DejaVu Sans", sans-serif';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.fillText(text, 256, 84);
  return canvasTexture(c);
}

export function createMaterials() {
  const limestone = stoneTexture('#efe4d0', 'rgba(120,96,70,0.35)', 8, 6);
  const darkStone = stoneTexture('#d9c7a4', 'rgba(90,70,48,0.4)', 7, 5);
  const burgundy = stoneTexture('#8d3348', 'rgba(40,10,18,0.35)', 2, 10);
  const cream = stoneTexture('#f3ecdf', 'rgba(140,120,90,0.28)', 6, 8);
  const sand = stoneTexture('#e4c99a', 'rgba(120,90,50,0.3)', 6, 8);
  const blueGray = stoneTexture('#d5dde3', 'rgba(70,90,110,0.28)', 4, 12);
  return {
    limestone: std({ map: limestone }),
    darkStone: std({ map: darkStone }),
    burgundy: std({ map: burgundy }),
    cream: std({ map: cream }),
    sand: std({ map: sand }),
    blueGray: std({ map: blueGray }),
    roof: std({ map: roofTexture(), roughness: 0.95 }),
    trim: std({ color: '#f7f1e4', roughness: 0.72 }),
    trimDark: std({ color: '#cbb892', roughness: 0.8 }),
    door: std({ color: '#3e2a22', roughness: 0.6 }),
    glass: std({ color: '#9fd4e4', roughness: 0.15, metalness: 0.05, transparent: true, opacity: 0.92 }),
    curtainGlass: std({ map: glassCurtain(8, 4), roughness: 0.18, metalness: 0.04 }),
    gold: std({ color: '#e3c16f', roughness: 0.45, metalness: 0.25 }),
    bronze: std({ color: '#8d5a32', roughness: 0.5, metalness: 0.2 }),
    hedge: std({ color: '#2f7a45', roughness: 0.95 }),
    water: std({ color: '#3c93c4', roughness: 0.15, metalness: 0.05, transparent: true, opacity: 0.9 }),
    basin: std({ color: '#d7dbe0', roughness: 0.55 }),
    flag: std({ map: turkishFlagTexture(), roughness: 0.7, side: THREE.DoubleSide }),
    emblem: std({ map: emblemTexture(), roughness: 0.55 }),
    clock: std({ map: clockTexture(), roughness: 0.4 }),
    pole: std({ color: '#4d555c', roughness: 0.4, metalness: 0.3 }),
    plaza: std({ map: stoneTexture('#e7e2d8', 'rgba(90,90,90,0.25)', 10, 10) }),
    benchWood: std({ color: '#8d5a3c', roughness: 0.8 }),
    benchIron: std({ color: '#2c3338', roughness: 0.45, metalness: 0.2 }),
    awning: [
      std({ color: '#c4493a', roughness: 0.75 }),
      std({ color: '#2f6f86', roughness: 0.75 }),
      std({ color: '#d28a2e', roughness: 0.75 }),
    ],
    selection: new THREE.MeshBasicMaterial({ color: '#f0c14a', transparent: true, opacity: 0.9, side: THREE.DoubleSide }),
  };
}
