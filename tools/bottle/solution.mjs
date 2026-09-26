import { rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const runtimeSpecifier = process.env.QODER_GLTF_RUNTIME
  ? pathToFileURL(path.resolve(process.env.QODER_GLTF_RUNTIME)).href
  : '@phodal/modeling-glb';
const { createModelBundle, modelCreate } = await import(runtimeSpecifier);

// Replace only defineModel(). Keep the delivery block below intact.
const mm = (value) => value / 1000;

// The bottle is authored to the silhouette the game already clips liquid
// against: the 55 x 150 box of BottlePainter's path in lib/widgets/tube_widget.dart.
// Millimetres, so a profile point can be checked against that painter by eye.
const BODY_RADIUS = 27.5;
const NECK_RADIUS = 11;
const FOOT_RADIUS = 12.5;
const HEIGHT = 150;
const CORNER_HEIGHT = 15;
const BODY_TOP = 102.5;
const NECK_TOP = 145;

function quadratic(from, control, to, steps) {
  const points = [];
  for (let step = 1; step <= steps; step++) {
    const t = step / steps;
    const u = 1 - t;
    points.push([
      u * u * from[0] + 2 * u * t * control[0] + t * t * to[0],
      u * u * from[1] + 2 * u * t * control[1] + t * t * to[1],
    ]);
  }
  return points;
}

// [radius, height] pairs from the foot to the mouth: strictly rising, positive.
function halfProfile() {
  return [
    [FOOT_RADIUS, 0],
    ...quadratic(
      [FOOT_RADIUS, 0],
      [BODY_RADIUS, 0],
      [BODY_RADIUS, CORNER_HEIGHT],
      6,
    ),
    [BODY_RADIUS, BODY_TOP],
    ...quadratic(
      [BODY_RADIUS, BODY_TOP],
      [BODY_RADIUS, 119.5],
      [NECK_RADIUS, 127.5],
      8,
    ),
    [NECK_RADIUS, NECK_TOP],
  ];
}

const source = defineModel();

function defineModel() {
  return modelCreate('build the water-sort bottle for pre-rendered skins')
    .appearance('bottle.glass', {
      baseColor: '#E8F6FF',
      metallic: 0,
      roughness: 0.08,
    })
    .part('bottle.body', {
      name: 'BottleBody',
      appearance: 'bottle.glass',
      geometry: {
        type: 'profile.revolve',
        profile: halfProfile().map(([radius, height]) => [
          mm(radius),
          mm(height),
        ]),
        radialSegments: 48,
      },
    })
    .part('bottle.rim', {
      name: 'BottleRim',
      parent: 'bottle.body',
      appearance: 'bottle.glass',
      translation: [0, mm((NECK_TOP + HEIGHT) / 2), 0],
      geometry: {
        type: 'primitive.hollow-cylinder',
        outerRadius: mm(NECK_RADIUS + 2.5),
        innerRadius: mm(NECK_RADIUS - 1),
        height: mm(HEIGHT - NECK_TOP),
        radialSegments: 32,
        axis: 'y',
      },
    })
    .expectBounds({
      min: [mm(-BODY_RADIUS), 0, mm(-BODY_RADIUS)],
      max: [mm(BODY_RADIUS), mm(HEIGHT), mm(BODY_RADIUS)],
      tolerance: 0.0005,
    })
    .budget({
      maxOperations: 8,
      maxGeneratedInstances: 2,
      maxNodes: 4,
      maxVertices: 6000,
      maxTriangles: 6000,
      maxBytes: 2 * 1024 * 1024,
    });
}

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
