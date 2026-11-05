import * as THREE from 'three';
import { signTexture } from './materials.js';

const Y = 0.03;

function add(parent, mesh) {
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function box(parent, w, h, d, x, y, z, mat) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  return add(parent, m);
}

function cyl(parent, rt, rb, h, x, y, z, mat, seg = 16) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
  m.position.set(x, y, z);
  return add(parent, m);
}

function column(parent, x, y, z, h, r, mat) {
  cyl(parent, r * 1.28, r * 1.4, r * 0.45, x, y + r * 0.22, z, mat);
  cyl(parent, r * 0.92, r, h - r * 1.15, x, y + h * 0.5, z, mat);
  cyl(parent, r * 1.45, r * 1.1, r * 0.42, x, y + h - r * 0.55, z, mat);
  box(parent, r * 3.2, r * 0.36, r * 3.2, x, y + h - r * 0.12, z, mat);
}

function pediment(parent, w, h, d, x, y, z, mat) {
  const shape = new THREE.Shape();
  shape.moveTo(-w / 2, 0);
  shape.lineTo(w / 2, 0);
  shape.lineTo(0, h);
  shape.closePath();
  const geo = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: false });
  geo.translate(0, 0, -d / 2);
  geo.computeVertexNormals();
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  return add(parent, m);
}

function flag(parent, x, y, z, mat, w = 0.7, h = 0.46) {
  cyl(parent, 0.025, 0.03, 1.15, x, y + 0.55, z, mat.pole, 8);
  const cloth = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat.flag);
  cloth.position.set(x + w / 2, y + 1.05, z);
  return add(parent, cloth);
}

function sign(parent, text, x, y, z, w, h, bg, fg) {
  const mat = new THREE.MeshStandardMaterial({
    map: signTexture(text, bg, fg),
    roughness: 0.55,
    metalness: 0,
  });
  return box(parent, w, h, 0.045, x, y, z, mat);
}

function windowBay(parent, x, y, z, w, h, mats, dz = 0.04) {
  box(parent, w, h, 0.04, x, y, z, mats.trim);
  box(parent, w * 0.78, h * 0.78, 0.05, x, y, z + dz, mats.glass);
}

function hedgeRow(parent, x, z, len, alongX, mats) {
  const w = alongX ? len : 0.28;
  const d = alongX ? 0.28 : len;
  box(parent, w, 0.32, d, x, 0.16, z, mats.hedge);
  box(parent, w * 0.92, 0.16, d * 0.8, x, 0.38, z, mats.hedge);
}

function buildTBMM(mats) {
  const g = new THREE.Group();
  const podiumH = 0.28;
  box(g, 7.4, podiumH, 3.6, 0, podiumH / 2, -0.15, mats.darkStone);
  box(g, 7.7, 0.08, 3.9, 0, 0.04, -0.15, mats.trimDark);

  const bodyH = 1.05;
  const bodyY = podiumH + bodyH / 2;
  box(g, 6.8, bodyH, 2.35, 0, bodyY, -0.35, mats.limestone);
  box(g, 7.0, 0.1, 2.55, 0, podiumH + bodyH + 0.05, -0.35, mats.trim);
  box(g, 6.5, 0.12, 2.15, 0, podiumH + bodyH + 0.16, -0.35, mats.darkStone);

  const steps = 7;
  for (let i = 0; i < steps; i++) {
    const depth = 0.2;
    const z = 1.05 + i * 0.2;
    const w = 3.15 + i * 0.16;
    const rise = 0.055;
    box(g, w, rise, depth + 0.01, 0, rise / 2 + i * rise * 0.15, z, i % 2 ? mats.limestone : mats.trim);
  }

  const colH = 0.98;
  const colY = podiumH;
  const colZ = 1.02;
  for (let i = 0; i < 8; i++) {
    const x = -1.85 + i * (3.7 / 7);
    column(g, x, colY, colZ, colH, 0.085, mats.trim);
  }
  box(g, 4.15, 0.1, 0.36, 0, colY + colH + 0.02, colZ, mats.trim);
  box(g, 4.35, 0.08, 0.42, 0, colY + colH + 0.1, colZ, mats.gold);
  pediment(g, 4.25, 0.48, 0.36, 0, colY + colH + 0.14, colZ, mats.trim);
  box(g, 0.55, 0.72, 0.08, 0, podiumH + 0.4, 0.88, mats.door);
  box(g, 0.7, 0.12, 0.16, 0, podiumH + 0.82, 0.9, mats.trim);

  for (const side of [-1, 1]) {
    for (let row = 0; row < 3; row++) {
      for (let col = 0; col < 3; col++) {
        const x = side * (2.15 + col * 0.42);
        const y = podiumH + 0.28 + row * 0.3;
        windowBay(g, x, y, 0.84, 0.3, 0.4, mats);
      }
    }
  }

  sign(g, 'TBMM', 0, podiumH + bodyH + 0.42, -0.35, 1.15, 0.28, '#1d3550', '#f7f1e4');
  flag(g, 2.4, podiumH + bodyH + 0.2, -0.9, mats, 0.78, 0.5);
  hedgeRow(g, -2.7, 1.7, 1.6, true, mats);
  hedgeRow(g, 2.7, 1.7, 1.6, true, mats);
  cyl(g, 0.55, 0.55, 0.08, 0, 0.05, 2.55, mats.basin, 20);
  cyl(g, 0.4, 0.4, 0.04, 0, 0.09, 2.55, mats.water, 20);
  cyl(g, 0.06, 0.08, 0.28, 0, 0.2, 2.55, mats.trim, 10);

  g.position.set(0, Y, -8.15);
  return g;
}

function buildBelediye(mats) {
  const g = new THREE.Group();
  const w = 2.7;
  const d = 2.05;
  const ground = 0.48;
  box(g, w + 0.16, 0.1, d + 0.16, 0, 0.05, 0, mats.trimDark);
  box(g, w, ground, d, 0, 0.1 + ground / 2, 0, mats.darkStone);
  for (let i = 0; i < 5; i++) {
    const x = -0.96 + i * 0.48;
    column(g, x, 0.1, d / 2 - 0.02, ground * 0.92, 0.055, mats.trim);
  }
  box(g, 0.42, 0.36, 0.06, 0, 0.3, d / 2 + 0.02, mats.door);

  const floors = 4;
  const fh = 0.3;
  const upperH = floors * fh;
  box(g, w - 0.08, upperH, d - 0.12, 0, 0.1 + ground + upperH / 2, -0.02, mats.cream);
  for (let f = 0; f < floors; f++) {
    const y = 0.1 + ground + f * fh + fh / 2;
    box(g, w + 0.02, 0.045, d + 0.02, 0, y + fh / 2 - 0.03, -0.02, mats.trimDark);
    for (let col = 0; col < 5; col++) {
      const x = -0.96 + col * 0.48;
      windowBay(g, x, y, d / 2 - 0.04, 0.32, 0.2, mats, 0.02);
    }
  }
  const roofY = 0.1 + ground + upperH;
  box(g, w - 0.16, 0.05, d - 0.16, 0, roofY + 0.025, -0.02, mats.roof);
  box(g, w + 0.08, 0.1, 0.08, 0, roofY + 0.05, d / 2 - 0.02, mats.trim);
  box(g, w + 0.08, 0.1, 0.08, 0, roofY + 0.05, -d / 2, mats.trim);
  box(g, 0.08, 0.1, d, w / 2, roofY + 0.05, -0.02, mats.trim);
  box(g, 0.08, 0.1, d, -w / 2, roofY + 0.05, -0.02, mats.trim);
  box(g, 0.7, 0.28, 0.55, 0.7, roofY + 0.22, -0.3, mats.darkStone);
  cyl(g, 0.04, 0.04, 0.45, 0.7, roofY + 0.5, -0.3, mats.pole, 6);

  const clock = new THREE.Mesh(new THREE.CircleGeometry(0.22, 24), mats.clock);
  clock.position.set(0, 0.1 + ground + upperH * 0.72, d / 2 + 0.02);
  add(g, clock);
  box(g, 0.5, 0.5, 0.06, 0, 0.1 + ground + upperH * 0.72, d / 2 - 0.02, mats.gold);

  sign(g, 'BELEDİYE', 0, 0.1 + ground + 0.02, d / 2 + 0.05, 1.7, 0.22, '#1f4d3a', '#f4efe4');
  flag(g, -1.15, 0.02, 1.35, mats, 0.55, 0.36);

  for (let i = 0; i < 6; i++) {
    const z = -0.7 + i * 0.28;
    box(g, 0.55, 0.035, 0.22, 0, 0.035 + i * 0.02, d / 2 + 0.25 + i * 0.2, mats.limestone);
  }

  g.position.set(-7.5, Y, -2);
  return g;
}

function buildBank(mats) {
  const g = new THREE.Group();
  const w = 1.85;
  const d = 1.55;
  const baseH = 0.5;
  box(g, w + 0.12, 0.1, d + 0.12, 0, 0.05, 0, mats.darkStone);
  box(g, w, baseH, d, 0, 0.1 + baseH / 2, 0, mats.limestone);
  for (const x of [-w / 2 + 0.08, w / 2 - 0.08]) {
    box(g, 0.12, baseH, d + 0.04, x, 0.1 + baseH / 2, 0, mats.darkStone);
  }
  box(g, 0.46, 0.38, 0.08, 0, 0.32, d / 2 + 0.02, mats.bronze);
  cyl(g, 0.16, 0.16, 0.04, 0, 0.1 + baseH - 0.02, d / 2 + 0.04, mats.gold, 20);
  windowBay(g, -0.48, 0.34, d / 2 + 0.01, 0.34, 0.28, mats);
  windowBay(g, 0.48, 0.34, d / 2 + 0.01, 0.34, 0.28, mats);

  const floors = 7;
  const fh = 0.26;
  const upperH = floors * fh;
  const glassMat = mats.curtainGlass;
  box(g, w - 0.06, upperH, d - 0.08, 0, 0.1 + baseH + upperH / 2, 0, glassMat);
  for (let f = 0; f <= floors; f++) {
    const y = 0.1 + baseH + f * fh;
    box(g, w + 0.02, 0.035, d + 0.02, 0, y, 0, mats.trim);
  }
  for (let i = 0; i < 5; i++) {
    const x = -w / 2 + 0.2 + i * ((w - 0.2) / 4);
    box(g, 0.035, upperH, 0.04, x, 0.1 + baseH + upperH / 2, d / 2 + 0.01, mats.trim);
  }
  const roofY = 0.1 + baseH + upperH;
  box(g, w + 0.16, 0.1, d + 0.14, 0, roofY + 0.05, 0, mats.darkStone);
  box(g, w * 0.55, 0.22, d * 0.4, 0, roofY + 0.2, 0, mats.limestone);
  sign(g, 'BANKA', 0, roofY + 0.42, 0, 1.15, 0.26, '#12324a', '#f4efe4');
  box(g, 0.9, 0.08, 0.5, 0, 0.06, d / 2 + 0.45, mats.trimDark);

  g.position.set(2.55, Y, -2);
  return g;
}

function buildParti(mats) {
  const g = new THREE.Group();
  const w = 2.55;
  const d = 1.85;
  box(g, w + 0.2, 0.1, d + 0.25, 0, 0.05, 0.05, mats.trimDark);
  box(g, w, 0.42, d, 0, 0.31, 0, mats.limestone);
  box(g, 0.5, 0.34, 0.08, 0, 0.32, d / 2 + 0.02, mats.door);
  for (let i = 0; i < 4; i++) {
    const x = -0.9 + i * 0.6;
    if (Math.abs(x) < 0.2) continue;
    windowBay(g, x, 0.32, d / 2 + 0.01, 0.36, 0.24, mats);
  }

  const upperH = 0.95;
  box(g, w - 0.05, upperH, d - 0.08, 0, 0.52 + upperH / 2, -0.02, mats.burgundy);
  const partyRoof = 0.52 + upperH;
  box(g, w - 0.18, 0.05, d - 0.16, 0, partyRoof + 0.02, -0.02, mats.roof);
  box(g, w + 0.06, 0.1, 0.08, 0, partyRoof + 0.05, d / 2 - 0.04, mats.trim);
  box(g, w + 0.06, 0.1, 0.08, 0, partyRoof + 0.05, -d / 2, mats.trim);
  box(g, 0.08, 0.1, d, w / 2, partyRoof + 0.05, -0.02, mats.trim);
  box(g, 0.08, 0.1, d, -w / 2, partyRoof + 0.05, -0.02, mats.trim);
  for (let row = 0; row < 2; row++) {
    for (let col = 0; col < 4; col++) {
      const x = -0.9 + col * 0.6;
      const y = 0.78 + row * 0.4;
      windowBay(g, x, y, d / 2 - 0.02, 0.36, 0.26, mats);
    }
  }

  const emblem = new THREE.Mesh(new THREE.CircleGeometry(0.34, 28), mats.emblem);
  emblem.position.set(0, 1.15, d / 2 + 0.02);
  add(g, emblem);

  sign(g, 'PARTİ', 0, 0.58, d / 2 + 0.06, 1.35, 0.22, '#f4efe4', '#6e2436');

  for (let i = 0; i < 5; i++) {
    box(g, 1.6 - i * 0.08, 0.045, 0.28, 0, 0.04 + i * 0.03, d / 2 + 0.28 + i * 0.22, mats.limestone);
  }

  flag(g, -1.05, 0.02, 1.45, mats, 0.5, 0.34);
  const partyFlagMat = new THREE.MeshStandardMaterial({ color: '#8e3048', roughness: 0.7, side: THREE.DoubleSide });
  for (const x of [1.05, 1.45]) {
    cyl(g, 0.02, 0.025, 0.9, x, 0.45, 1.35, mats.pole, 6);
    const cloth = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 0.28), partyFlagMat);
    cloth.position.set(x + 0.22, 0.78, 1.35);
    add(g, cloth);
  }

  box(g, 0.55, 0.22, 0.4, 0.75, 1.6, -0.35, mats.limestone);
  cyl(g, 0.03, 0.03, 0.4, 0.75, 1.9, -0.35, mats.pole, 6);

  g.position.set(-2.5, Y, 6);
  return g;
}

function hitBox(w, h, d, y, z, kurum) {
  const mesh = new THREE.Mesh(
    new THREE.BoxGeometry(w, h, d),
    new THREE.MeshBasicMaterial({ visible: false }),
  );
  mesh.position.set(0, y, z);
  mesh.userData.kurum = kurum;
  return mesh;
}

export function buildLandmarks(scene, mats) {
  const tbmm = buildTBMM(mats);
  const belediye = buildBelediye(mats);
  const banka = buildBank(mats);
  const parti = buildParti(mats);

  const institutions = [
    {
      id: 'tbmm',
      kicker: 'Yasama',
      name: 'Türkiye Büyük Millet Meclisi',
      short: 'TBMM',
      desc: 'Milletvekilleri, kanun teklifleri, Genel Kurul oylamaları ve meclis başkanlığı. Sütunlu tören cephesi Ankara’daki meclis yapısından esinlenir.',
      stats: [
        ['Sandalye', '600'],
        ['Gündem', '4 tasarı'],
        ['Dönem', '28'],
      ],
      action: 'Meclis masası',
      group: tbmm,
      label: new THREE.Vector3(0, 2.55, -8.15),
      ring: 2.3,
    },
    {
      id: 'belediye',
      kicker: 'Yerel yönetim',
      name: 'Ankara Büyükşehir Belediyesi',
      short: 'Belediye',
      desc: 'Belediye bütçesi, ruhsat, imar, hizmet ihaleleri ve il karnesi. Saatli belediye konağı bu ilin belediye masasını açar.',
      stats: [
        ['Kasa', '128 mr'],
        ['Memnuniyet', '%72'],
        ['Ruhsat', '14'],
      ],
      action: 'Belediye masası',
      group: belediye,
      label: new THREE.Vector3(-7.5, 2.15, -2),
      ring: 1.45,
    },
    {
      id: 'banka',
      kicker: 'Finans',
      name: 'Banka',
      short: 'Banka',
      desc: 'Hesaplar, krediler, çekler, mevduat ve güven notu. Cam giydirme kule, ildeki banka kurumunu temsil eder.',
      stats: [
        ['Mevduat', '86 mr'],
        ['Kredi', '41 mr'],
        ['Güven', 'B+'],
      ],
      action: 'Banka masası',
      group: banka,
      label: new THREE.Vector3(2.55, 2.85, -2),
      ring: 1.15,
    },
    {
      id: 'parti',
      kicker: 'Siyaset',
      name: 'Parti Merkezi',
      short: 'Parti',
      desc: 'Üyelik, kurultay, adaylık, il teşkilatı ve parti kasası. Amblem ve kürsü, oyuncunun kendi partisi içindir; gerçek bir parti logosu değildir.',
      stats: [
        ['Üye', '12.480'],
        ['İl teşkilatı', '81'],
        ['Kasa', '6,4 mr'],
      ],
      action: 'Parti masası',
      group: parti,
      label: new THREE.Vector3(-2.5, 2.15, 6),
      ring: 1.35,
    },
  ];

  const hits = {
    tbmm: hitBox(7.6, 2.3, 4.6, 1.15, 0.3, institutions[0]),
    belediye: hitBox(3, 2.1, 2.6, 1.05, 0.15, institutions[1]),
    banka: hitBox(2.1, 2.7, 1.9, 1.35, 0.1, institutions[2]),
    parti: hitBox(2.9, 2.0, 2.5, 1.0, 0.2, institutions[3]),
  };

  const clickable = [];
  for (const inst of institutions) {
    scene.add(inst.group);
    const hit = hits[inst.id];
    inst.group.add(hit);
    clickable.push(hit);
  }
  return { institutions, clickable };
}
