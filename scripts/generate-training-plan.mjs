import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = resolve(__dirname, '../data/trainingPlan.json');

const start = new Date('2026-09-07T12:00:00');
const weekdays = [
  { key: 'monday', label: 'lunes', offset: 0 },
  { key: 'tuesday', label: 'martes', offset: 1 },
  { key: 'thursday', label: 'jueves', offset: 3 },
  { key: 'friday', label: 'viernes', offset: 4 },
];

const sourceDocument =
  '/Users/nstr/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/10. Gym/Plan entrenamiento 3 meses.md';

const barbellWeightKg = 20;
const dumbbellLoadsKg = [
  5, 6, 7.5, 8, 9, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30,
];
const plateInventoryKg = [
  { weight: 1.25, count: 4 },
  { weight: 2.5, count: 4 },
  { weight: 5, count: 12 },
  { weight: 10, count: 12 },
  { weight: 15, count: 2 },
  { weight: 20, count: 4 },
];
const barbellLoadsKg = buildBarbellLoads();
const externalLoadsKg = buildPlateCombinationLoads();
const cableLoadsKg = Array.from({ length: 20 }, (_, index) => (index + 1) * 5);

const baseSessions = {
  monday: {
    title: 'Lunes - Torso fuerza',
    focus: 'Press, dominadas y remo pesado',
    estimatedMinutes: 60,
    exercises: [
      exercise(
        'press-banca-barra',
        'Press banca con barra',
        'Básico',
        'A',
        5,
        5,
        65,
        135,
        [
          'Si queda demasiado fácil, subir solo 2.5 kg la semana siguiente.',
          'Mantener 1-2 RIR en la última serie.',
        ],
      ),
      exercise(
        'dominadas-lastradas',
        'Dominadas lastradas',
        'Básico',
        'B',
        5,
        5,
        5,
        135,
        [
          'Registrar siempre el lastre exacto.',
          'Parar si la barbilla no pasa clara.',
        ],
      ),
      exercise(
        'remo-inclinado-barra',
        'Remo inclinado con barra',
        'Básico',
        'C',
        4,
        6,
        57.5,
        120,
        ['Torso firme y mismo ángulo en todas las reps.'],
      ),
      exercise(
        'press-militar-sentado',
        'Press militar sentado en banco',
        'Básico',
        'D',
        3,
        6,
        35,
        90,
        [
          'Sentado en banco para proteger la espalda. Bloquear abdomen antes de despegar la barra.',
        ],
      ),
      exercise(
        'elevaciones-laterales',
        'Elevaciones laterales',
        'Accesorio',
        'E1',
        3,
        15,
        9,
        60,
        ['Rango 15-20 reps. Peso por mancuerna.'],
      ),
      exercise(
        'curl-biceps-alterno',
        'Curl bíceps alterno',
        'Accesorio',
        'E2',
        3,
        9,
        15,
        60,
        ['Rango 8-10 reps. Peso por mancuerna.'],
      ),
      exercise(
        'triceps-polea-simple',
        'Tríceps en polea simple',
        'Accesorio',
        'F',
        2,
        11,
        0,
        60,
        ['Usar RIR 2 hasta acumular historial de polea.'],
      ),
    ],
  },
  tuesday: {
    title: 'Martes - Pierna fuerza controlada',
    focus: 'Sentadilla, bisagra e hip thrust',
    estimatedMinutes: 60,
    exercises: [
      exercise(
        'sentadilla-barra',
        'Sentadilla con barra',
        'Básico',
        'A',
        4,
        5,
        65,
        150,
        [
          'Tempo controlado: 2 s bajada y pausa corta abajo.',
          'Si rodilla molesta, cambiar a multipower o reducir rango.',
        ],
      ),
      exercise(
        'peso-muerto-rumano-barra',
        'Peso muerto rumano con barra',
        'Básico',
        'B',
        4,
        6,
        65,
        150,
        ['Cadera atrás, espalda neutra y barra pegada.'],
      ),
      exercise(
        'hip-thrust-barra',
        'Hip thrust / puente con barra',
        'Básico',
        'C',
        3,
        8,
        90,
        120,
        ['Pausa clara arriba sin sacrificar bloqueo de cadera.'],
      ),
      exercise(
        'extension-cuadriceps',
        'Extensión de cuádriceps',
        'Accesorio',
        'D1',
        3,
        12,
        32.5,
        75,
        ['No empujar dolor de rodilla por encima de 3/10.'],
      ),
      exercise(
        'curl-femoral-maquina',
        'Curl femoral máquina',
        'Accesorio',
        'D2',
        3,
        11,
        0,
        75,
        ['Usar RIR 2 hasta acumular referencia de carga.'],
      ),
      exercise(
        'gemelos-pie',
        'Elevación de gemelos de pie',
        'Accesorio',
        'E',
        3,
        12,
        50,
        60,
        ['Pausa 1 s arriba y bajada controlada.'],
      ),
      exercise(
        'core-plancha-dead-bug',
        'Plancha o dead bug',
        'Accesorio',
        'F',
        2,
        60,
        0,
        45,
        ['Series de 60 s sin perder posición.'],
        { measure: 'duration' },
      ),
    ],
  },
  thursday: {
    title: 'Jueves - Torso volumen y potencia',
    focus: 'Volumen de torso y velocidad',
    estimatedMinutes: 60,
    exercises: [
      exercise(
        'press-banca-inclinado',
        'Press banca inclinado con barra o mancuernas',
        'Básico',
        'A',
        4,
        8,
        47.5,
        90,
        ['Usar 45-50 kg en barra o 22.5 kg por mancuerna.'],
      ),
      exercise(
        'dominadas-peso-corporal',
        'Dominadas peso corporal',
        'Básico',
        'B',
        4,
        9,
        0,
        90,
        ['Rango 8-10 reps, dejando 1-2 reps en recámara.'],
      ),
      exercise(
        'press-militar-sentado-velocidad',
        'Press militar sentado velocidad',
        'Básico',
        'C',
        4,
        3,
        30,
        60,
        [
          'Sentado en banco para proteger la espalda.',
          'La barra debe moverse rápido. Si se ralentiza, bajar 2.5-5 kg.',
        ],
      ),
      exercise(
        'remo-barra-multipower',
        'Remo con barra o remo en multipower',
        'Básico',
        'D',
        4,
        10,
        52.5,
        90,
        ['Mantener tensión y recorrido estable.'],
      ),
      exercise(
        'pullover-mancuerna',
        'Pull-over con mancuerna',
        'Accesorio',
        'E',
        2,
        11,
        28.75,
        60,
        ['Rango 10-12 reps.'],
      ),
      exercise(
        'elevaciones-laterales-volumen',
        'Elevaciones laterales',
        'Accesorio',
        'F1',
        3,
        15,
        9,
        45,
        ['Rango 15-20 reps. Peso por mancuerna.'],
      ),
      exercise(
        'curl-martillo',
        'Curl martillo',
        'Accesorio',
        'F2',
        3,
        11,
        15,
        45,
        ['Rango 10-12 reps. Peso por mancuerna.'],
      ),
      exercise(
        'triceps-polea-volumen',
        'Tríceps en polea simple',
        'Accesorio',
        'G',
        2,
        13,
        0,
        45,
        ['Rango 12-15 reps con RIR 2.'],
      ),
    ],
  },
  friday: {
    title: 'Viernes - Torso accesorio + posterior',
    focus: 'Torso accesorio y cadena posterior',
    estimatedMinutes: 60,
    exercises: [
      exercise(
        'press-cerrado-multipower',
        'Press banca agarre cerrado o press en multipower',
        'Básico',
        'A',
        4,
        7,
        57.5,
        120,
        ['Rango 6-8 reps. Cuidar muñeca.'],
      ),
      exercise(
        'dominadas-supinas',
        'Dominadas supinas',
        'Básico',
        'B',
        3,
        7,
        0,
        120,
        ['Peso corporal o +2.5 kg si sale limpio.'],
      ),
      exercise(
        'rdl-tecnico',
        'Peso muerto rumano técnico',
        'Básico técnico',
        'C',
        3,
        10,
        60,
        90,
        ['Tempo 3 s bajada, 1 s pausa, subida firme.'],
      ),
      exercise(
        'hip-thrust-volumen',
        'Hip thrust volumen',
        'Básico',
        'D',
        3,
        11,
        85,
        90,
        ['Rango 10-12 reps. Pausa arriba.'],
      ),
      exercise(
        'gemelos-sentado-multipower',
        'Elevación de gemelos sentado o en prensa/multipower',
        'Accesorio',
        'E',
        2,
        15,
        0,
        60,
        ['Usar RIR 2 si la máquina no tiene referencia clara.'],
      ),
      exercise(
        'curl-biceps-barra-mancuernas',
        'Curl bíceps barra o mancuernas',
        'Accesorio',
        'F1',
        2,
        11,
        15,
        60,
        ['Peso por mancuerna si se usan mancuernas.'],
      ),
      exercise(
        'extension-triceps-polea',
        'Extensión tríceps polea',
        'Accesorio',
        'F2',
        2,
        11,
        0,
        60,
        ['Rango 10-12 reps con RIR 2.'],
      ),
      exercise(
        'elevacion-lateral-mecanica',
        'Elevación lateral mecánica',
        'Accesorio',
        'G',
        2,
        28,
        9,
        60,
        [
          'Ronda: 10 estrictas, 8 parciales altas/medias, 10 parciales bajas/medias.',
        ],
      ),
    ],
  },
};

const progressions = {
  'press-banca-barra': { step: 2.5, max: 82.5 },
  'dominadas-lastradas': { step: 2.5, max: 15 },
  'remo-inclinado-barra': { step: 2.5, max: 67.5 },
  'press-militar-sentado': { step: 2.5, max: 45 },
  'sentadilla-barra': { step: 2.5, max: 82.5 },
  'peso-muerto-rumano-barra': { step: 5, max: 85 },
  'hip-thrust-barra': { step: 5, max: 115 },
};

const sessions = [];
const skippedDates = new Set(['2026-09-08']);
const dateOverrides = new Map([
  ['5:friday', '2026-10-07'],
  ['6:monday', '2026-10-14'],
  ['12:tuesday', '2026-12-09'],
]);

for (let week = 1; week <= 13; week += 1) {
  for (const weekday of weekdays) {
    const base = baseSessions[weekday.key];
    const date = plannedDate(week, weekday);
    const dateIso = isoDate(date);

    if (skippedDates.has(dateIso)) {
      continue;
    }

    const exercises = base.exercises.map((item) => adaptExercise(item, week));
    sessions.push({
      sessionId: `${dateIso}-${slug(base.title)}`,
      date: dateIso,
      week,
      weekday: weekdayLabel(date),
      sessionLabel: `${capitalize(weekdayLabel(date))} - ${base.title.replace(
        /^[^-]+ - /,
        '',
      )}`,
      label: base.title.replace(/^[^-]+ - /, ''),
      estimatedMinutes: base.estimatedMinutes,
      focus: base.focus,
      weekFocusLabel: getWeekFocusLabel(week),
      weekFocus: getWeekFocus(week),
      source: sourceDocument,
      exercises,
    });
  }
}

sessions.sort((a, b) => a.date.localeCompare(b.date));

writeFileSync(
  outputPath,
  `${JSON.stringify(
    {
      planId: 'training-plan-2026-q4',
      sourceDocument,
      startsOn: '2026-09-07',
      endsOn: '2026-12-18',
      durationWeeks: 13,
      sessions,
    },
    null,
    2,
  )}\n`,
);

function exercise(
  exerciseId,
  name,
  type,
  block,
  setCount,
  reps,
  weightKg,
  restSeconds,
  notes,
  options = {},
) {
  const superset = getSupersetFromBlock(block);

  return {
    exerciseId,
    name,
    type,
    block,
    supersetId: options.supersetId ?? superset?.id,
    supersetOrder: options.supersetOrder ?? superset?.order,
    setCount,
    reps,
    weightKg,
    restSeconds,
    notes,
    measure: options.measure ?? 'reps',
  };
}

function getSupersetFromBlock(block) {
  const match = /^([A-Z])(\d+)$/.exec(block);

  if (!match) {
    return null;
  }

  return {
    id: `superset-${match[1].toLowerCase()}`,
    order: Number(match[2]),
  };
}

function adaptExercise(item, week) {
  const templateWeek = week > 11 ? week - 1 : week;
  const postVacationAdaptation = week === 11;
  const deload = templateWeek === 4 || templateWeek === 8;
  const test = templateWeek === 12;
  const progression = progressions[item.exerciseId];
  let setCount = item.setCount;
  let reps = item.reps;
  let durationSeconds = item.reps;
  let weightKg = item.weightKg;
  let restSeconds = item.restSeconds;
  let phase = 'acumulacion';

  if (templateWeek >= 5 && templateWeek <= 7) {
    phase = 'intensificacion';
  }
  if (templateWeek >= 9 && templateWeek <= 11) {
    phase = 'realizacion';
  }

  if (progression && weightKg > 0) {
    const loadWeek =
      templateWeek > 8
        ? templateWeek - 2
        : templateWeek > 4
          ? templateWeek - 1
          : templateWeek;
    weightKg = Math.min(
      item.weightKg + (loadWeek - 1) * progression.step,
      progression.max,
    );
  }

  if (templateWeek >= 5 && templateWeek <= 7 && isBasic(item)) {
    setCount = getIntensificationSetCount(item);
    reps = getIntensificationReps(item);
    restSeconds = getIntensificationRest(item, restSeconds);
  }

  if (templateWeek >= 9 && templateWeek <= 11 && isBasic(item)) {
    setCount = getRealizationSetCount(item);
    reps = getRealizationReps(item);
    restSeconds = getRealizationRest(item, restSeconds);
  }

  if (postVacationAdaptation) {
    phase = 'readaptacion';
    setCount = item.type === 'Accesorio' ? 2 : Math.min(3, item.setCount);
    reps = item.reps;
    weightKg = roundLoad(weightKg * 0.85);
    restSeconds = Math.min(Math.max(restSeconds, 90), 150);
  }

  if (deload) {
    phase = 'descarga';
    setCount = item.type === 'Accesorio' ? 2 : Math.min(3, item.setCount);
    reps = item.type === 'Accesorio' ? item.reps : Math.max(6, item.reps);
    weightKg = roundLoad(weightKg * 0.875);
    restSeconds = Math.min(restSeconds, 120);
  }

  if (test) {
    phase = 'test';
    setCount = isBasic(item) ? 2 : Math.min(2, item.setCount);
    reps = isBasic(item) ? Math.max(3, item.reps) : item.reps;
    restSeconds = isBasic(item) ? Math.max(180, restSeconds) : restSeconds;
  }

  if (item.measure === 'duration') {
    durationSeconds = 60;
  }

  weightKg = getAvailableLoad(item, weightKg);

  const sets = Array.from({ length: setCount }, (_, index) => ({
    setIndex: index + 1,
    targetReps: reps,
    targetWeightKg: weightKg,
    targetDurationSeconds:
      item.measure === 'duration' ? durationSeconds : undefined,
    restSeconds,
    type: item.measure === 'duration' ? 'timed' : 'working',
  }));

  return {
    exerciseId: item.exerciseId,
    name: item.name,
    type: item.type,
    block: item.block,
    supersetId: item.supersetId,
    supersetOrder: item.supersetOrder,
    phase,
    notes: item.notes.join(' '),
    target:
      item.measure === 'duration'
        ? `${setCount}x${durationSeconds}s`
        : `${setCount}x${reps} @ ${formatKg(weightKg)}`,
    decisionOptions: decisionOptions(item, templateWeek, weightKg, {
      postVacationAdaptation,
    }),
    sets,
  };
}

function getWeekFocus(week) {
  if (week >= 1 && week <= 3) {
    return 'Acumulación técnica: volumen alto-moderado con RIR 2-3.';
  }

  if (week === 4 || week === 8) {
    return 'Descarga: menos carga y menos series para salir fresco.';
  }

  if (week >= 5 && week <= 7) {
    return 'Intensificación: cargas más altas, volumen moderado y RIR 1-2.';
  }

  if (week === 11) {
    return 'Readaptación: recuperar ritmo y técnica antes del tramo final.';
  }

  if (week >= 9 && week <= 12) {
    return 'Realización: top sets controlados, sin fallo técnico.';
  }

  return 'Test y consolidación: marcas útiles dejando una repetición en recámara.';
}

function getWeekFocusLabel(week) {
  if (week >= 1 && week <= 3) {
    return 'Acumulación técnica';
  }

  if (week === 4 || week === 8) {
    return 'Descarga';
  }

  if (week >= 5 && week <= 7) {
    return 'Intensificación';
  }

  if (week === 11) {
    return 'Readaptación';
  }

  if (week >= 9 && week <= 12) {
    return 'Realización';
  }

  return 'Test y consolidación';
}

function getIntensificationSetCount(item) {
  if (item.exerciseId === 'dominadas-lastradas') {
    return 4;
  }

  if (
    item.exerciseId === 'press-militar-sentado' ||
    item.exerciseId === 'press-militar-sentado-velocidad'
  ) {
    return 4;
  }

  if (
    item.exerciseId === 'rdl-tecnico' ||
    item.exerciseId === 'hip-thrust-volumen'
  ) {
    return 3;
  }

  if (
    item.exerciseId === 'press-cerrado-multipower' ||
    item.exerciseId === 'dominadas-supinas'
  ) {
    return 4;
  }

  return Math.min(Math.max(item.setCount, 4), 4);
}

function getIntensificationReps(item) {
  if (item.exerciseId === 'press-militar-sentado-velocidad') {
    return 3;
  }

  if (
    item.exerciseId.includes('hip-thrust') ||
    item.exerciseId.includes('rumano')
  ) {
    return Math.max(5, item.reps - 1);
  }

  return Math.max(4, item.reps - 1);
}

function getIntensificationRest(item, fallbackRestSeconds) {
  if (
    item.exerciseId === 'press-banca-inclinado' ||
    item.exerciseId === 'dominadas-peso-corporal' ||
    item.exerciseId === 'remo-barra-multipower'
  ) {
    return Math.max(fallbackRestSeconds, 105);
  }

  if (item.exerciseId === 'press-militar-sentado-velocidad') {
    return Math.max(fallbackRestSeconds, 75);
  }

  if (
    item.exerciseId === 'press-militar-sentado' ||
    item.exerciseId === 'rdl-tecnico' ||
    item.exerciseId === 'hip-thrust-volumen'
  ) {
    return Math.max(fallbackRestSeconds, 120);
  }

  return Math.max(fallbackRestSeconds, 135);
}

function getRealizationSetCount(item) {
  if (
    item.exerciseId === 'press-banca-barra' ||
    item.exerciseId === 'dominadas-lastradas' ||
    item.exerciseId === 'sentadilla-barra'
  ) {
    return 4;
  }

  if (
    item.exerciseId === 'press-militar-sentado-velocidad' ||
    item.exerciseId === 'rdl-tecnico' ||
    item.exerciseId === 'hip-thrust-volumen'
  ) {
    return 3;
  }

  return Math.min(item.setCount, 3);
}

function getRealizationReps(item) {
  if (
    item.exerciseId.includes('hip-thrust') ||
    item.exerciseId.includes('rumano')
  ) {
    return 5;
  }

  if (item.exerciseId === 'press-militar-sentado-velocidad') {
    return 3;
  }

  return 3;
}

function getRealizationRest(item, fallbackRestSeconds) {
  if (
    item.exerciseId === 'press-banca-barra' ||
    item.exerciseId === 'dominadas-lastradas' ||
    item.exerciseId === 'sentadilla-barra'
  ) {
    return Math.max(fallbackRestSeconds, 150);
  }

  return Math.max(fallbackRestSeconds, 120);
}

function decisionOptions(item, week, weightKg, options = {}) {
  if (item.weightKg === 0) {
    return options.postVacationAdaptation
      ? ['Mantener suave', 'Subir reps si fácil', 'Marcar molestia']
      : ['Mantener', 'Subir reps', 'Marcar molestia'];
  }

  const next = getNextAvailableLoad(item, weightKg);
  const down = getPreviousAvailableLoad(item, weightKg);

  if (options.postVacationAdaptation) {
    return ['Mantener suave', `Subir a ${formatKg(next)}`, 'Marcar molestia'];
  }

  if (week === 4 || week === 8) {
    return [
      'Cerrar descarga',
      `Volver a ${formatKg(getAvailableLoad(item, item.weightKg))}`,
      'Marcar molestia',
    ];
  }

  if (week === 12) {
    return ['Consolidar marca', 'Repetir bloque', 'Marcar molestia'];
  }

  return ['Mantener', `Subir a ${formatKg(next)}`, `Bajar a ${formatKg(down)}`];
}

function plannedDate(week, weekday) {
  const override = dateOverrides.get(`${week}:${weekday.key}`);

  if (override) {
    return new Date(`${override}T12:00:00`);
  }

  const vacationShiftDays = week >= 11 ? 14 : 0;

  return addDays(start, (week - 1) * 7 + weekday.offset + vacationShiftDays);
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function weekdayLabel(date) {
  return [
    'domingo',
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
  ][date.getDay()];
}

function capitalize(value) {
  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`;
}

function slug(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

function roundLoad(value) {
  return Math.round(value * 2) / 2;
}

function roundPlateLoad(value) {
  return Math.round(value * 100) / 100;
}

function getAvailableLoad(item, value) {
  if (value <= 0) {
    return 0;
  }

  const loadKind = getLoadKind(item);

  if (loadKind === 'dumbbell') {
    return nearestAvailable(value, dumbbellLoadsKg);
  }

  if (loadKind === 'machine') {
    return nearestAvailable(value, cableLoadsKg);
  }

  if (loadKind === 'external') {
    return nearestAvailable(value, externalLoadsKg);
  }

  return nearestAvailable(value, barbellLoadsKg);
}

function getNextAvailableLoad(item, value) {
  return getAdjacentAvailableLoad(item, value, 1);
}

function getPreviousAvailableLoad(item, value) {
  return getAdjacentAvailableLoad(item, value, -1);
}

function getAdjacentAvailableLoad(item, value, direction) {
  if (value <= 0) {
    return 0;
  }

  const loads = getAvailableLoads(item);
  const currentIndex = loads.findIndex((load) => load === value);
  const index =
    currentIndex >= 0
      ? currentIndex
      : loads.findIndex((load) => load === nearestAvailable(value, loads));
  const nextIndex = Math.min(loads.length - 1, Math.max(0, index + direction));

  return loads[nextIndex] ?? value;
}

function getAvailableLoads(item) {
  const loadKind = getLoadKind(item);

  if (loadKind === 'dumbbell') {
    return dumbbellLoadsKg;
  }

  if (loadKind === 'machine') {
    return cableLoadsKg;
  }

  if (loadKind === 'external') {
    return externalLoadsKg;
  }

  return barbellLoadsKg;
}

function getLoadKind(item) {
  const text =
    `${item.exerciseId} ${item.name} ${item.notes.join(' ')}`.toLowerCase();

  if (item.measure === 'duration' || item.weightKg === 0) {
    return 'bodyweight';
  }

  if (text.includes('dominadas-lastradas')) {
    return 'external';
  }

  if (
    text.includes('peso por mancuerna') ||
    text.includes('elevaciones laterales') ||
    text.includes('elevación lateral') ||
    text.includes('curl martillo') ||
    text.includes('curl bíceps') ||
    (text.includes('mancuerna') && !text.includes('barra o mancuernas'))
  ) {
    return 'dumbbell';
  }

  if (
    text.includes('polea') ||
    (text.includes('máquina') && !text.includes('multipower'))
  ) {
    return 'machine';
  }

  return 'barbell';
}

function isBasic(item) {
  return item.type
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .startsWith('basico');
}

function nearestAvailable(value, loads) {
  return loads.reduce((best, candidate) => {
    const bestDistance = Math.abs(best - value);
    const candidateDistance = Math.abs(candidate - value);

    if (candidateDistance < bestDistance) {
      return candidate;
    }

    if (candidateDistance === bestDistance && candidate < best) {
      return candidate;
    }

    return best;
  }, loads[0]);
}

function buildBarbellLoads() {
  const sideLoads = buildSidePlateLoads();
  return Array.from(
    new Set(
      sideLoads.map((sideLoad) => roundLoad(barbellWeightKg + sideLoad * 2)),
    ),
  ).sort((a, b) => a - b);
}

function buildSidePlateLoads() {
  const pairs = plateInventoryKg.map((plate) => ({
    weight: plate.weight,
    count: Math.floor(plate.count / 2),
  }));
  const loads = new Set([0]);

  pairs.forEach((plate) => {
    const existing = Array.from(loads);

    existing.forEach((load) => {
      Array.from({ length: plate.count }).forEach((_, index) => {
        loads.add(roundPlateLoad(load + plate.weight * (index + 1)));
      });
    });
  });

  return Array.from(loads);
}

function buildPlateCombinationLoads() {
  const loads = new Set([0]);

  plateInventoryKg.forEach((plate) => {
    const existing = Array.from(loads);

    existing.forEach((load) => {
      Array.from({ length: plate.count }).forEach((_, index) => {
        loads.add(roundPlateLoad(load + plate.weight * (index + 1)));
      });
    });
  });

  return Array.from(loads)
    .filter((load) => load > 0)
    .sort((a, b) => a - b);
}

function formatKg(value) {
  if (Number.isInteger(value)) {
    return `${value} kg`;
  }

  return `${value.toFixed(value * 2 === Math.round(value * 2) ? 1 : 2)} kg`;
}
