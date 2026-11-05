import * as THREE from 'three';
import { makeFacade } from './materials.js';

const Y = 0.03;

// Kenney road-straight runs along X. road-bend opens toward -X and -Z.
const ROT = {
  straightX: 0,
  straightZ: Math.PI / 2,
  bend: { wn: 0, ne: -Math.PI / 2, es: Math.PI, sw: Math.PI / 2 },
  endOpeningX: 0,
};

const XS = [-10, -5, 0, 5, 10];
const ZS = [-4, 0, 4, 8, 12];

function key(x, z) {
  return `${x},${z}`;
}

function buildRoadSet() {
  const roads = new Set();
  const add = (x, z) => roads.add(key(x, z));
  for (const z of ZS) {
    for (let x = -10; x <= 10; x++) add(x, z);
  }
  for (const x of XS) {
    for (let z = -4; z <= 12; z++) add(x, z);
  }
  return roads;
}

function neighbors(roads, x, z) {
  return {
    n: roads.has(key(x, z - 1)),
    e: roads.has(key(x + 1, z)),
    s: roads.has(key(x, z + 1)),
    w: roads.has(key(x - 1, z)),
  };
}

function classify(nbs) {
  const { n, e, s, w } = nbs;
  const arms = [n, e, s, w].filter(Boolean).length;
  if (arms >= 3) return { kind: 'road-intersection', rot: 0 };
  if (n && s) return { kind: 'road-straight', rot: ROT.straightZ };
  if (e && w) return { kind: 'road-straight', rot: ROT.straightX };
  if (w && n) return { kind: 'road-bend', rot: ROT.bend.wn };
  if (n && e) return { kind: 'road-bend', rot: ROT.bend.ne };
  if (e && s) return { kind: 'road-bend', rot: ROT.bend.es };
  if (s && w) return { kind: 'road-bend', rot: ROT.bend.sw };
  if (e || w) return { kind: 'road-end', rot: w ? Math.PI : 0 };
  if (n || s) return { kind: 'road-end', rot: s ? -Math.PI / 2 : Math.PI / 2 };
  return { kind: 'tile-low', rot: 0 };
}

function firstMesh(gltf) {
  let mesh = null;
  gltf.scene.traverse((o) => {
    if (!mesh && o.isMesh) mesh = o;
  });
  return mesh;
}

function prepMaterial(mat) {
  mat.metalness = 0;
  mat.roughness = 1;
  if (mat.map) {
    mat.map.colorSpace = THREE.SRGBColorSpace;
    mat.map.anisotropy = 8;
    mat.map.magFilter = THREE.NearestFilter;
    mat.map.minFilter = THREE.NearestFilter;
    mat.map.generateMipmaps = false;
  }
}

const FILES = {
  roads: ['road-straight', 'road-intersection', 'road-bend', 'road-crossing', 'road-end', 'tile-low', 'light-curved', 'traffic-light'],
  suburban: ['tree-large', 'tree-small', 'path-stones-long', 'path-stones-short', 'planter'],
  cars: ['sedan', 'taxi', 'van', 'suv', 'police', 'ambulance'],
};

export async function loadKits(loader) {
  const meshes = {};
  const cars = {};
  const jobs = [];
  for (const [kit, names] of Object.entries(FILES)) {
    for (const name of names) {
      const url = `./assets/kenney/${kit}/${name}.glb`;
      jobs.push(
        loader.loadAsync(url).then((gltf) => {
          if (kit === 'cars') {
            gltf.scene.traverse((o) => {
              if (o.isMesh && o.material) prepMaterial(o.material);
            });
            cars[name] = gltf.scene;
          } else {
            const mesh = firstMesh(gltf);
            if (mesh.material) prepMaterial(mesh.material);
            if (name === 'tile-low' && mesh.material) mesh.material.color = new THREE.Color('#d7e4b4');
            meshes[name] = mesh;
          }
        }),
      );
    }
  }
  await Promise.all(jobs);
  return { meshes, cars };
}

function instances(scene, mesh, items, { cast = false, receive = true } = {}) {
  if (!items.length) return null;
  const inst = new THREE.InstancedMesh(mesh.geometry, mesh.material, items.length);
  inst.castShadow = cast;
  inst.receiveShadow = receive;
  const dummy = new THREE.Object3D();
  items.forEach((it, i) => {
    dummy.position.set(it.x, it.y ?? 0, it.z);
    dummy.rotation.set(it.rx || 0, it.rot || 0, 0);
    dummy.scale.setScalar(it.scale ?? 1);
    dummy.updateMatrix();
    inst.setMatrixAt(i, dummy.matrix);
  });
  inst.instanceMatrix.needsUpdate = true;
  scene.add(inst);
  return inst;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const PALETTES = [
  { wall: '#f3ecdf', base: '#cbb892', trim: '#efe2c9', frame: '#f7f4ee', glassTop: '#d7eef5', glassBot: '#7eb4c6', curtain: '#c4493a' },
  { wall: '#e7d7b8', base: '#b08968', trim: '#f0e2c8', frame: '#fffaf2', glassTop: '#d5e7ef', glassBot: '#6fa4b8', curtain: '#2f6f86' },
  { wall: '#d9e2e4', base: '#8aa0a8', trim: '#eef3f4', frame: '#f4f7f8', glassTop: '#e7f4f8', glassBot: '#5d8ea3', curtain: '#d28a2e' },
  { wall: '#f0d6c8', base: '#a6533c', trim: '#f6e4d4', frame: '#fff8f3', glassTop: '#dceff5', glassBot: '#6e9aaf', curtain: '#2f6f4a' },
  { wall: '#e6e0d4', base: '#6d7c86', trim: '#f3efe6', frame: '#fbfaf7', glassTop: '#d4ebf3', glassBot: '#4f86a0', curtain: '#8e3048' },
];

function buildingMaterials(THREE_unused, spec) {
  void THREE_unused;
  const faceH = spec.floors * spec.fh + spec.baseH;
  const map = makeFacade({
    faceW: spec.w,
    faceH,
    floors: spec.floors,
    cols: spec.cols,
    shop: spec.shop,
    ...spec.palette,
  });
  const wall = new THREE.MeshStandardMaterial({ map, roughness: 0.88, metalness: 0 });
  const sideMap = makeFacade({
    faceW: spec.d,
    faceH,
    floors: spec.floors,
    cols: Math.max(2, spec.cols - 1),
    shop: false,
    ...spec.palette,
  });
  const side = new THREE.MeshStandardMaterial({ map: sideMap, roughness: 0.9, metalness: 0 });
  return { wall, side };
}

function addMesh(parent, geo, mat, x, y, z) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  m.receiveShadow = true;
  parent.add(m);
  return m;
}

function pitchedRoof(w, d, rise) {
  const shape = new THREE.Shape();
  shape.moveTo(-w / 2, 0);
  shape.lineTo(w / 2, 0);
  shape.lineTo(0, rise);
  shape.closePath();
  const geo = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: false });
  geo.translate(0, 0, -d / 2);
  geo.computeVertexNormals();
  return geo;
}

function placeBuilding(scene, mats, spec) {
  const g = new THREE.Group();
  const { wall, side } = buildingMaterials(null, spec);
  const h = spec.baseH + spec.floors * spec.fh;
  const materials = [side, side, mats.roof, mats.darkStone, wall, wall];
  const body = new THREE.Mesh(new THREE.BoxGeometry(spec.w, h, spec.d), materials);
  body.position.y = h / 2;
  body.castShadow = true;
  body.receiveShadow = true;
  g.add(body);
  addMesh(g, new THREE.BoxGeometry(spec.w + 0.08, 0.08, spec.d + 0.08), mats.trimDark, 0, 0.04, 0);
  const lip = 0.07;
  addMesh(g, new THREE.BoxGeometry(spec.w + 0.04, 0.1, lip), mats.trim, 0, h, spec.d / 2);
  addMesh(g, new THREE.BoxGeometry(spec.w + 0.04, 0.1, lip), mats.trim, 0, h, -spec.d / 2);
  addMesh(g, new THREE.BoxGeometry(lip, 0.1, spec.d), mats.trim, spec.w / 2, h, 0);
  addMesh(g, new THREE.BoxGeometry(lip, 0.1, spec.d), mats.trim, -spec.w / 2, h, 0);

  if (spec.pitch) {
    const roof = new THREE.Mesh(pitchedRoof(spec.w + 0.18, spec.d + 0.12, 0.42), mats.roof);
    roof.position.y = h;
    roof.castShadow = true;
    g.add(roof);
    addMesh(g, new THREE.BoxGeometry(0.16, 0.28, 0.16), mats.darkStone, spec.w * 0.28, h + 0.32, 0);
  } else {
    addMesh(g, new THREE.BoxGeometry(spec.w * 0.28, 0.22, spec.d * 0.32), mats.blueGray, spec.w * 0.18, h + 0.15, -spec.d * 0.12);
    addMesh(g, new THREE.CylinderGeometry(0.1, 0.1, 0.16, 10), mats.trimDark, -spec.w * 0.22, h + 0.14, spec.d * 0.1);
  }

  if (spec.shop) {
    const awn = mats.awning[spec.awning];
    addMesh(g, new THREE.BoxGeometry(spec.w * 0.82, 0.035, 0.32), awn, 0, spec.baseH * 0.95, spec.d / 2 + 0.12);
  } else if (spec.floors >= 4) {
    for (let f = 1; f < spec.floors; f += 2) {
      const y = spec.baseH + f * spec.fh + 0.04;
      addMesh(g, new THREE.BoxGeometry(spec.w * 0.42, 0.04, 0.22), mats.trim, 0, y, spec.d / 2 + 0.08);
      addMesh(g, new THREE.BoxGeometry(spec.w * 0.42, 0.1, 0.03), mats.pole, 0, y + 0.07, spec.d / 2 + 0.18);
    }
  }

  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      addMesh(
        g,
        new THREE.BoxGeometry(0.08, h, 0.08),
        mats.trimDark,
        sx * (spec.w / 2),
        h / 2,
        sz * (spec.d / 2),
      );
    }
  }

  g.position.set(spec.x, Y, spec.z);
  scene.add(g);
}

const BLOCKED = [
  { x0: -4.2, x1: 4.2, z0: -11.2, z1: -5.4 },
  { x0: -9.3, x1: -5.7, z0: -3.4, z1: -0.7 },
  { x0: 1.2, x1: 3.9, z0: -3.4, z1: -0.7 },
  { x0: -4.2, x1: -0.8, z0: 4.6, z1: 7.5 },
  { x0: -9.4, x1: -5.6, z0: 0.6, z1: 3.5 },
];

function blocked(x, z, w, d) {
  const x0 = x - w / 2;
  const x1 = x + w / 2;
  const z0 = z - d / 2;
  const z1 = z + d / 2;
  return BLOCKED.some((b) => x1 > b.x0 && x0 < b.x1 && z1 > b.z0 && z0 < b.z1);
}

function fillBlocks(scene, mats) {
  const rand = mulberry32(20261105);
  const bandsX = [-7.5, -2.5, 2.5, 7.5];
  const bandsZ = [-2, 2, 6, 10];
  let paletteI = 0;
  for (const cx of bandsX) {
    for (const cz of bandsZ) {
      for (const side of [-1, 1]) {
        const w = 1.35 + rand() * 0.25;
        const d = 1.2 + rand() * 0.25;
        const x = cx + side * 0.92;
        const z = cz + (rand() - 0.5) * 0.25;
        if (blocked(x, z, w, d)) continue;
        const shop = rand() < 0.45;
        const floors = shop ? 2 + (rand() < 0.4 ? 1 : 0) : 3 + Math.floor(rand() * 4);
        const spec = {
          x,
          z,
          w,
          d,
          floors,
          fh: 0.28,
          baseH: shop ? 0.42 : 0.32,
          cols: w > 1.45 ? 4 : 3,
          shop,
          pitch: shop || floors <= 3,
          awning: Math.floor(rand() * 3),
          palette: PALETTES[paletteI % PALETTES.length],
        };
        paletteI += 1;
        placeBuilding(scene, mats, spec);
      }
    }
  }
}

function park(scene, meshes) {
  const cx = -7.5;
  const cz = 2;
  const paths = [];
  for (let i = 0; i < 4; i++) {
    paths.push({ x: cx, y: 0.025, z: cz - 1.15 + i * 0.55, rot: Math.PI / 2, scale: 2.5 });
  }
  for (const x of [-1.1, -0.55, 0.55, 1.1]) {
    paths.push({ x: cx + x, y: 0.025, z: cz, rot: 0, scale: 2.3 });
  }
  instances(scene, meshes['path-stones-long'], paths, { receive: true });

  const planters = [
    { x: cx - 0.7, z: cz - 0.7, y: Y, scale: 1.1, rot: 0.4 },
    { x: cx + 0.7, z: cz + 0.7, y: Y, scale: 1.1, rot: 1.2 },
    { x: cx - 0.7, z: cz + 0.7, y: Y, scale: 0.9, rot: 0.2 },
    { x: cx + 0.85, z: cz - 0.55, y: Y, scale: 0.9, rot: 2 },
  ];
  instances(scene, meshes.planter, planters, { cast: true, receive: true });
}

function fountain(scene, mats, x, z, s = 1) {
  const g = new THREE.Group();
  const basin = new THREE.Mesh(new THREE.CylinderGeometry(0.48 * s, 0.52 * s, 0.1 * s, 20), mats.basin);
  basin.position.y = 0.06 * s;
  const water = new THREE.Mesh(new THREE.CylinderGeometry(0.36 * s, 0.36 * s, 0.04 * s, 20), mats.water);
  water.position.y = 0.1 * s;
  water.name = 'water';
  const jet = new THREE.Mesh(new THREE.CylinderGeometry(0.04 * s, 0.07 * s, 0.28 * s, 10), mats.trim);
  jet.position.y = 0.22 * s;
  for (const m of [basin, water, jet]) {
    m.castShadow = m !== water;
    m.receiveShadow = true;
    g.add(m);
  }
  g.position.set(x, Y, z);
  g.userData.water = water;
  scene.add(g);
  return g;
}

function bench(scene, mats, x, z, rot) {
  const g = new THREE.Group();
  const wood = mats.benchWood;
  const iron = mats.benchIron;
  const seat = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.04, 0.2), wood);
  seat.position.y = 0.2;
  const back = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.16, 0.03), wood);
  back.position.set(0, 0.3, -0.09);
  for (const sx of [-0.22, 0.22]) {
    const leg = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.2, 0.18), iron);
    leg.position.set(sx, 0.1, 0);
    g.add(leg);
  }
  g.add(seat, back);
  g.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true;
      o.receiveShadow = true;
    }
  });
  g.position.set(x, Y, z);
  g.rotation.y = rot;
  scene.add(g);
}

function lampsAndSignals(scene, meshes, roads) {
  const lamps = [];
  const lights = [];
  for (const x of XS) {
    for (const z of ZS) {
      if ((x + z) % 10 !== 0 && !(x === 0 && z === -4)) continue;
      lamps.push({ x: x + 0.38, y: 0, z: z + 0.38, rot: Math.PI, scale: 1.15 });
      lamps.push({ x: x - 0.38, y: 0, z: z - 0.38, rot: 0, scale: 1.15 });
      if (x === 0 || z === -4 || z === 0) {
        lights.push({ x: x + 0.42, y: 0, z: z - 0.15, rot: 0, scale: 1.2 });
      }
    }
  }
  for (let z = -2; z <= 10; z += 2) {
    if (ZS.includes(z)) continue;
    lamps.push({ x: 0.42, y: 0, z, rot: -Math.PI / 2, scale: 1.15 });
    lamps.push({ x: -0.42, y: 0, z: z + 1, rot: Math.PI / 2, scale: 1.15 });
  }
  instances(scene, meshes['light-curved'], lamps, { cast: true, receive: true });
  instances(scene, meshes['traffic-light'], lights, { cast: true, receive: true });
  void roads;
}

function planeTree(scene, mats, x, z, scale) {
  const g = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.045 * scale, 0.07 * scale, 0.42 * scale, 6), mats.benchWood);
  trunk.position.y = 0.2 * scale;
  const blobs = [
    [0, 0.52, 0, 0.26],
    [0.14, 0.46, 0.06, 0.18],
    [-0.13, 0.48, -0.05, 0.17],
    [0.02, 0.66, 0.04, 0.15],
  ];
  for (const [bx, by, bz, r] of blobs) {
    const leaf = new THREE.Mesh(new THREE.SphereGeometry(r * scale, 8, 6), mats.hedge);
    leaf.position.set(bx * scale, by * scale, bz * scale);
    g.add(leaf);
  }
  g.add(trunk);
  g.position.set(x, Y, z);
  g.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true;
      o.receiveShadow = true;
    }
  });
  scene.add(g);
}

function trees(scene, meshes) {
  const rand = mulberry32(7);
  const large = [];
  const small = [];
  const pushTree = (x, z, scale, kind) => {
    const item = { x, y: Y, z, rot: rand() * Math.PI * 2, scale };
    (kind === 'large' ? large : small).push(item);
  };
  for (let z = -3; z <= 11; z += 2) {
    if (ZS.includes(z)) continue;
    pushTree(0.55, z, 1.55, 'large');
    pushTree(-0.55, z + 1, 1.35, 'small');
  }
  for (let x = -9; x <= 9; x += 2) {
    if (XS.includes(x) || Math.abs(x) < 1) continue;
    pushTree(x, -4.55, 1.4, x % 4 === 0 ? 'large' : 'small');
  }
  const parkTrees = [
    [-9.1, 0.9], [-8.8, 3.1], [-6.2, 0.85], [-6.0, 3.15],
    [-9.0, 2.0], [-6.15, 2.05], [-8.2, 1.15], [-6.9, 3.0],
  ];
  for (const [x, z] of parkTrees) pushTree(x, z, 1.7, 'large');
  for (const x of [-3.4, -2.2, 2.2, 3.4]) {
    pushTree(x, -6.35, 1.5, 'large');
    pushTree(x, -10.3, 1.35, 'small');
  }
  for (const [x, z] of [[-10.8, -6], [10.8, 2], [-10.8, 8], [10.8, 10], [6.2, -6.5], [-6.2, 8.5]]) {
    pushTree(x, z, 1.8, 'large');
  }
  instances(scene, meshes['tree-large'], large, { cast: true, receive: true });
  instances(scene, meshes['tree-small'], small, { cast: true, receive: true });
}

function rightOffset(dir, amount) {
  const len = Math.hypot(dir.x, dir.z) || 1;
  const fx = dir.x / len;
  const fz = dir.z / len;
  return { x: -fz * amount, z: fx * amount };
}

function makeLoop(points) {
  const pts = points.map((p) => new THREE.Vector3(p[0], 0, p[1]));
  pts.push(pts[0].clone());
  const seg = [];
  let total = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const len = pts[i].distanceTo(pts[i + 1]);
    seg.push({ a: pts[i], b: pts[i + 1], len, start: total });
    total += len;
  }
  return { seg, total };
}

function pointOn(path, dist) {
  const d = ((dist % path.total) + path.total) % path.total;
  for (const s of path.seg) {
    if (d <= s.start + s.len || s === path.seg[path.seg.length - 1]) {
      const t = s.len === 0 ? 0 : (d - s.start) / s.len;
      const pos = s.a.clone().lerp(s.b, Math.min(1, Math.max(0, t)));
      const dir = s.b.clone().sub(s.a);
      return { pos, dir };
    }
  }
  return { pos: path.seg[0].a.clone(), dir: new THREE.Vector3(1, 0, 0) };
}

const CAR_SCALE = 0.2;
const CAR_LIFT = 0.3 * CAR_SCALE;

function spawnCars(scene, cars) {
  const loops = [
    makeLoop([[-10, -4], [10, -4], [10, 12], [-10, 12]]),
    makeLoop([[-5, 0], [5, 0], [5, 8], [-5, 8]]),
    makeLoop([[0, -4], [5, -4], [5, 12], [0, 12]]),
    makeLoop([[0, -4], [-5, -4], [-5, 12], [0, 12]]),
  ];
  const kinds = ['sedan', 'taxi', 'van', 'suv', 'police', 'ambulance', 'sedan', 'taxi'];
  const fleet = [];
  kinds.forEach((kind, i) => {
    const path = loops[i % loops.length];
    const root = cars[kind].clone(true);
    root.scale.setScalar(CAR_SCALE);
    root.traverse((o) => {
      if (o.isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
      }
    });
    const wheels = [];
    root.traverse((o) => {
      if (o.name && o.name.startsWith('wheel')) wheels.push(o);
    });
    scene.add(root);
    fleet.push({
      root,
      wheels,
      path,
      dist: (i / kinds.length) * path.total,
      speed: 1.15 + (i % 3) * 0.18,
      lane: 0.16,
    });
  });
  return fleet;
}

export function buildDistrict(scene, kits, mats) {
  const { meshes, cars } = kits;
  const roads = buildRoadSet();
  const buckets = new Map();
  const push = (kind, x, z, rot) => {
    if (!buckets.has(kind)) buckets.set(kind, []);
    buckets.get(kind).push({ x, z, rot, y: 0 });
  };

  for (let x = -12; x <= 12; x++) {
    for (let z = -12; z <= 13; z++) {
      if (roads.has(key(x, z))) {
        const info = classify(neighbors(roads, x, z));
        const useCrossing = info.kind === 'road-straight' && (x === 0 || z === 0) && (x + z) % 4 === 0;
        push(useCrossing ? 'road-crossing' : info.kind, x, z, info.rot);
      } else {
        push('tile-low', x, z, 0);
      }
    }
  }
  for (const [kind, items] of buckets) {
    const cast = kind === 'light-curved' || kind === 'traffic-light';
    instances(scene, meshes[kind], items, { cast, receive: true });
  }

  trees(scene, meshes);
  for (const [x, z, s] of [[-4.35, -6.85, 1.15], [4.35, -6.7, 1.2], [-4.45, -9.6, 1.05], [4.4, -9.55, 1.1], [-8.4, 2.15, 1.25], [-6.6, 2.7, 1.15], [6.4, 6.2, 1.2], [-8.9, 6.4, 1.1]]) {
    planeTree(scene, mats, x, z, s);
  }
  park(scene, meshes);
  lampsAndSignals(scene, meshes, roads);
  fillBlocks(scene, mats);
  const fountains = [
    fountain(scene, mats, -7.5, 2, 1),
    fountain(scene, mats, 2.15, -5.45, 0.7),
  ];
  bench(scene, mats, -6.55, 1.15, 0.4);
  bench(scene, mats, -8.4, 2.85, -0.6);
  bench(scene, mats, -3.15, -5.55, 0.15);
  bench(scene, mats, 3.35, -5.5, -0.2);

  const fleet = spawnCars(scene, cars);
  return {
    fountains,
    update(dt) {
      for (const car of fleet) {
        car.dist += car.speed * dt;
        const { pos, dir } = pointOn(car.path, car.dist);
        const off = rightOffset(dir, car.lane);
        car.root.position.set(pos.x + off.x, Y + CAR_LIFT, pos.z + off.z);
        car.root.rotation.y = Math.atan2(dir.x, dir.z);
        const spin = car.dist / (CAR_SCALE * 0.32);
        for (const w of car.wheels) w.rotation.x = spin;
      }
      const bob = Math.sin(performance.now() / 500) * 0.012;
      for (const f of fountains) {
        const water = f.userData.water;
        if (water.userData.baseY == null) water.userData.baseY = water.position.y;
        water.position.y = water.userData.baseY + bob;
      }
    },
  };
}
