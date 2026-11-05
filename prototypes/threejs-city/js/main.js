import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { createMaterials } from './materials.js';
import { loadKits, buildDistrict } from './district.js';
import { buildLandmarks } from './landmarks.js';

const host = document.getElementById('scene');
const panel = document.getElementById('panel');
const hint = document.getElementById('hint');
const statusEl = document.getElementById('status');

const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
host.append(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color('#8ebfe0');
scene.fog = new THREE.Fog('#b7d4ea', 26, 58);

const camera = new THREE.PerspectiveCamera(32, innerWidth / innerHeight, 0.1, 180);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 0.2, 1);
camera.position.set(13, 18, 15);
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.enableRotate = false;
controls.screenSpacePanning = true;
controls.zoomToCursor = false;
controls.mouseButtons.LEFT = THREE.MOUSE.PAN;
controls.mouseButtons.RIGHT = THREE.MOUSE.PAN;
controls.touches.ONE = THREE.TOUCH.PAN;
controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;
controls.minDistance = 7;
controls.maxDistance = 38;
controls.update();

scene.add(new THREE.HemisphereLight(0xfff6ea, 0x6d8f5c, 1.15));
const sun = new THREE.DirectionalLight(0xfff0d2, 2.35);
sun.position.set(-18, 26, 10);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -24;
sun.shadow.camera.right = 24;
sun.shadow.camera.top = 24;
sun.shadow.camera.bottom = -24;
sun.shadow.camera.near = 2;
sun.shadow.camera.far = 70;
sun.shadow.bias = -0.00035;
sun.shadow.normalBias = 0.025;
sun.target.position.set(0, 0, 1);
scene.add(sun, sun.target);
const fill = new THREE.DirectionalLight(0xc9ddf2, 0.55);
fill.position.set(12, 10, 16);
scene.add(fill);

const ground = new THREE.Mesh(
  new THREE.CircleGeometry(80, 48),
  new THREE.MeshStandardMaterial({ color: '#7ea86a', roughness: 1 }),
);
ground.rotation.x = -Math.PI / 2;
ground.position.y = -0.04;
ground.receiveShadow = true;
scene.add(ground);

const mats = createMaterials();
const ring = new THREE.Mesh(new THREE.RingGeometry(0.72, 0.9, 48), mats.selection);
ring.rotation.x = -Math.PI / 2;
ring.position.y = 0.05;
ring.visible = false;
scene.add(ring);

const loader = new GLTFLoader();
const labelLayer = document.getElementById('labels');
let district = null;
let institutions = [];
let clickable = [];
let selected = null;

function showStatus(text) {
  statusEl.hidden = !text;
  statusEl.textContent = text || '';
}

function openKurum(inst) {
  selected = inst;
  document.getElementById('kicker').textContent = inst.kicker;
  document.getElementById('name').textContent = inst.name;
  document.getElementById('desc').textContent = inst.desc;
  const stats = document.getElementById('stats');
  stats.replaceChildren();
  for (const [label, value] of inst.stats) {
    const card = document.createElement('div');
    const strong = document.createElement('strong');
    strong.textContent = value;
    const span = document.createElement('span');
    span.textContent = label;
    card.append(strong, span);
    stats.append(card);
  }
  const note = document.getElementById('action-note');
  note.hidden = true;
  document.getElementById('action').onclick = () => {
    note.hidden = false;
  };
  panel.hidden = false;
  ring.visible = true;
  ring.position.x = inst.group.position.x;
  ring.position.z = inst.group.position.z;
  ring.scale.setScalar(inst.ring);
  hint.classList.add('gone');
}

function closePanel() {
  panel.hidden = true;
  ring.visible = false;
  selected = null;
}

document.getElementById('close').onclick = closePanel;
document.getElementById('reset').onclick = () => {
  controls.target.set(0, 0.2, 1);
  camera.position.set(13, 18, 15);
  controls.update();
};
addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closePanel();
});

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const pointers = new Map();
let gesture = null;

function localPoint(e) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
}

renderer.domElement.addEventListener('pointerdown', (e) => {
  pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (pointers.size === 1) {
    gesture = { id: e.pointerId, x: e.clientX, y: e.clientY, moved: false };
  } else {
    gesture = null;
  }
});
renderer.domElement.addEventListener('pointermove', (e) => {
  const start = pointers.get(e.pointerId);
  if (start && Math.hypot(e.clientX - start.x, e.clientY - start.y) > 8 && gesture?.id === e.pointerId) {
    gesture.moved = true;
    hint.classList.add('gone');
  }
  if (e.pointerType === 'mouse' && pointers.size === 0) {
    localPoint(e);
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(clickable, false)[0];
    renderer.domElement.style.cursor = hit ? 'pointer' : 'grab';
  }
});
renderer.domElement.addEventListener('pointerup', (e) => {
  const start = gesture;
  pointers.delete(e.pointerId);
  if (!start || start.id !== e.pointerId || start.moved || pointers.size > 0) return;
  localPoint(e);
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObjects(clickable, false)[0];
  if (!hit) {
    closePanel();
    return;
  }
  openKurum(hit.object.userData.kurum);
});
renderer.domElement.addEventListener('pointercancel', (e) => {
  pointers.delete(e.pointerId);
  gesture = null;
});

const projection = new THREE.Vector3();
const hitPoint = new THREE.Vector3();
const labelNodes = new Map();

function ensureLabel(inst) {
  let node = labelNodes.get(inst.id);
  if (node) return node;
  node = document.createElement('div');
  node.className = 'tag';
  node.textContent = inst.short;
  labelLayer.append(node);
  labelNodes.set(inst.id, node);
  return node;
}

function updateLabels() {
  for (const inst of institutions) {
    const node = ensureLabel(inst);
    projection.copy(inst.label).project(camera);
    const visible = projection.z > 0 && projection.z < 1;
    node.style.display = visible ? 'block' : 'none';
    if (!visible) continue;
    node.style.left = `${((projection.x + 1) * innerWidth) / 2}px`;
    node.style.top = `${((1 - projection.y) * innerHeight) / 2}px`;
    node.classList.toggle('on', selected?.id === inst.id);
  }
  window.__anchors = {};
  for (const inst of institutions) {
    inst.group.localToWorld(hitPoint.set(0, 0.7, 0.15));
    hitPoint.project(camera);
    window.__anchors[inst.id] = {
      x: ((hitPoint.x + 1) * innerWidth) / 2,
      y: ((1 - hitPoint.y) * innerHeight) / 2,
    };
  }
}

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const dt = Math.min(clock.getDelta(), 0.05);
  controls.update();
  district?.update(dt);
  updateLabels();
  renderer.render(scene, camera);
});

showStatus('Şehir yükleniyor…');
try {
  const kits = await loadKits(loader);
  district = buildDistrict(scene, kits, mats);
  const built = buildLandmarks(scene, mats);
  institutions = built.institutions;
  clickable = built.clickable;
  showStatus('');
  window.__cityReady = true;
  window.__openKurum = (id) => {
    const inst = institutions.find((item) => item.id === id);
    if (inst) openKurum(inst);
  };
} catch (err) {
  console.error(err);
  showStatus('Modeller yüklenemedi. Sayfayı bir HTTP sunucusuyla açın.');
  window.__cityError = String(err);
}
