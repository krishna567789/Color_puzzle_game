import { rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const runtimeSpecifier = process.env.QODER_GLTF_RUNTIME
  ? pathToFileURL(path.resolve(process.env.QODER_GLTF_RUNTIME)).href
  : '@phodal/modeling-glb';
const { createModelBundle, modelCreate } = await import(runtimeSpecifier);

// Replace only defineModel(). Keep the delivery block below intact.
// Define the primary mass, semantic root, expected bounds, and budgets before
// adding bounded groups of detail. The scaffold fails closed until authored so
// a sample object's geometry can never leak into the requested model.
const HALF = 0.008;
const BEVEL = 0.0014;
const PIP_RADIUS = 0.0016;
const PIP_HEIGHT = 0.0007;
const PIP_OFFSET = 0.0034;
const SURFACE = HALF;
const OUTER = HALF + PIP_HEIGHT / 2;

// Opposite faces sum to seven: 1/6, 2/5, 3/4. Classic Ludo dice carve the one
// and four pips red, the rest black.
const FACES = [
  { value: 1, red: true, rotationRad: [0, 0, 0], map: () => [0, SURFACE, 0], pips: [[0, 0]] },
  {
    value: 6,
    rotationRad: [0, 0, 0],
    map: (u, v) => [u, -SURFACE, v],
    pips: [-1, 1].flatMap((u) => [-1, 0, 1].map((v) => [u * PIP_OFFSET, v * PIP_OFFSET])),
  },
  {
    value: 3,
    rotationRad: [0, 0, Math.PI / 2],
    map: (u, v) => [SURFACE, u, v],
    pips: [[-1, -1], [0, 0], [1, 1]].map(([u, v]) => [u * PIP_OFFSET, v * PIP_OFFSET]),
  },
  {
    value: 4,
    red: true,
    rotationRad: [0, 0, Math.PI / 2],
    map: (u, v) => [-SURFACE, u, v],
    pips: [-1, 1].flatMap((u) => [-1, 1].map((v) => [u * PIP_OFFSET, v * PIP_OFFSET])),
  },
  {
    value: 2,
    rotationRad: [Math.PI / 2, 0, 0],
    map: (u, v) => [u, v, SURFACE],
    pips: [[-1, -1], [1, 1]].map(([u, v]) => [u * PIP_OFFSET, v * PIP_OFFSET]),
  },
  {
    value: 5,
    rotationRad: [Math.PI / 2, 0, 0],
    map: (u, v) => [u, v, -SURFACE],
    pips: [[0, 0], ...[-1, 1].flatMap((u) => [-1, 1].map((v) => [u * PIP_OFFSET, v * PIP_OFFSET]))],
  },
];

function defineModel() {
  let model = modelCreate('Build a 16 mm Ludo dice (पासा) as a rounded ivory cube with 21 pip discs')
    .appearance('die.shell.material', { baseColor: '#F6F1E4', metallic: 0.02, roughness: 0.3 })
    .appearance('pip.black.material', { baseColor: '#1B1B1D', metallic: 0.05, roughness: 0.45 })
    .appearance('pip.red.material', { baseColor: '#B3231C', metallic: 0.05, roughness: 0.4 })
    .feature('die.body.feature', {
      type: 'primitive.beveled-box',
      size: [HALF * 2, HALF * 2, HALF * 2],
      bevelRadius: BEVEL,
      bevelSegments: 3,
    })
    .feature('pip.disc.feature', {
      type: 'primitive.cylinder',
      radius: PIP_RADIUS,
      height: PIP_HEIGHT,
      radialSegments: 20,
      axis: 'y',
    })
    .component('die.body.component', { feature: 'die.body.feature', appearance: 'die.shell.material' })
    .component('pip.black.component', { feature: 'pip.disc.feature', appearance: 'pip.black.material' })
    .component('pip.red.component', { feature: 'pip.disc.feature', appearance: 'pip.red.material' })
    .occurrence('ludo.die', { name: 'LudoDice' })
    .occurrence('ludo.die.body', { parent: 'ludo.die', component: 'die.body.component', name: 'DiceBody' });

  for (const face of FACES) {
    face.pips.forEach((pip, index) => {
      model = model.occurrence(`ludo.die.pip.f${face.value}.${index}`, {
        parent: 'ludo.die',
        component: face.red ? 'pip.red.component' : 'pip.black.component',
        name: `PipFace${face.value}_${index}`,
        translation: face.map(pip[0], pip[1]),
        rotationRad: face.rotationRad,
      });
    });
  }

  return model
    .expectBounds({
      min: [-OUTER, -OUTER, -OUTER],
      max: [OUTER, OUTER, OUTER],
      tolerance: 0.0004,
    })
    .budget({
      maxOperations: 64,
      maxGeneratedInstances: 64,
      maxNodes: 32,
      maxMeshes: 4,
      maxVertices: 6000,
      maxTriangles: 6000,
      maxBytes: 1024 * 1024,
    });
}

const source = defineModel();
const bundle = await createModelBundle(source.program());
await Promise.all([
  writeAtomic('program.gltf.json', JSON.stringify(bundle.program, null, 2) + '\n'),
  writeAtomic('artifact.glb', bundle.artifact),
  writeAtomic('artifact.gltf-project.json', bundle.projectSidecar),
  writeAtomic('capability-report.json', JSON.stringify(bundle.capabilityReport, null, 2) + '\n'),
]);

process.stdout.write(JSON.stringify({
  status: 'committed',
  revision: bundle.inspection.revision,
  bounds: bundle.inspection.bounds,
  counts: bundle.validation.counts,
}) + '\n');

async function writeAtomic(filePath, data) {
  const absolute = path.resolve(filePath);
  const temporary = path.join(path.dirname(absolute), '.' + path.basename(absolute) + '.' + process.pid + '.tmp');
  await writeFile(temporary, data);
  await rename(temporary, absolute);
}
