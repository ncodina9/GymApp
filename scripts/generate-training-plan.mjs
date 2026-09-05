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

const baseSessions = {
  monday: {
    title: 'Lunes - Torso fuerza',
    focus: 'Press, dominadas y remo pesado',
    estimatedMinutes: 60,
    exercises: [
      exercise(
        'press-banca-barra',
        'Press banca con barra',
        'Basico',
        'A',
        5,
        5,
        65,
        150,
        [
          'Si queda demasiado facil, subir solo 2.5 kg la semana siguiente.',
          'Mantener 1-2 RIR en la ultima serie.',
        ],
      ),
      exercise(
        'dominadas-lastradas',
        'Dominadas lastradas',
        'Basico',
        'B',
        5,
        5,
        5,
        150,
        [
          'Registrar siempre el lastre exacto.',
          'Parar si la barbilla no pasa clara.',
        ],
      ),
      exercise(
        'remo-inclinado-barra',
        'Remo inclinado con barra',
        'Basico',
        'C',
        4,
        6,
        57.5,
        120,
        ['Torso firme y mismo angulo en todas las reps.'],
      ),
      exercise(
        'press-militar-pie',
        'Press militar de pie',
        'Basico',
        'D',
        4,
        6,
        35,
        120,
        ['Bloquear abdomen antes de despegar la barra.'],
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
        'Curl biceps alterno',
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
        'Triceps en polea simple',
        'Accesorio',
        'F',
        3,
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
        'Basico',
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
        'Basico',
        'B',
        4,
        6,
        65,
        150,
        ['Cadera atras, espalda neutra y barra pegada.'],
      ),
      exercise(
        'hip-thrust-barra',
        'Hip thrust / puente con barra',
        'Basico',
        'C',
        4,
        8,
        90,
        120,
        ['Pausa clara arriba sin sacrificar bloqueo de cadera.'],
      ),
      exercise(
        'extension-cuadriceps',
        'Extension de cuadriceps',
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
        'Curl femoral maquina',
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
        'Elevacion de gemelos de pie',
        'Accesorio',
        'E',
        4,
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
        3,
        45,
        0,
        45,
        ['Series de 45-60 s sin perder posicion.'],
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
        'Basico',
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
        'Basico',
        'B',
        4,
        9,
        0,
        90,
        ['Rango 8-10 reps, dejando 1-2 reps en recamara.'],
      ),
      exercise(
        'press-militar-velocidad',
        'Press militar velocidad',
        'Basico',
        'C',
        6,
        3,
        30,
        75,
        ['La barra debe moverse rapido. Si se ralentiza, bajar 2.5-5 kg.'],
      ),
      exercise(
        'remo-barra-multipower',
        'Remo con barra o remo en multipower',
        'Basico',
        'D',
        4,
        10,
        52.5,
        90,
        ['Mantener tension y recorrido estable.'],
      ),
      exercise(
        'pullover-mancuerna',
        'Pull-over con mancuerna',
        'Accesorio',
        'E',
        3,
        11,
        28.75,
        75,
        ['Rango 10-12 reps.'],
      ),
      exercise(
        'elevaciones-laterales-volumen',
        'Elevaciones laterales',
        'Accesorio',
        'F1',
        4,
        15,
        9,
        60,
        ['Rango 15-20 reps. Peso por mancuerna.'],
      ),
      exercise(
        'curl-martillo',
        'Curl martillo',
        'Accesorio',
        'F2',
        4,
        11,
        15,
        60,
        ['Rango 10-12 reps. Peso por mancuerna.'],
      ),
      exercise(
        'triceps-polea-volumen',
        'Triceps en polea simple',
        'Accesorio',
        'G',
        4,
        13,
        0,
        60,
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
        'Basico',
        'A',
        4,
        7,
        57.5,
        120,
        ['Rango 6-8 reps. Cuidar muneca.'],
      ),
      exercise(
        'dominadas-supinas',
        'Dominadas supinas',
        'Basico',
        'B',
        4,
        7,
        0,
        120,
        ['Peso corporal o +2.5 kg si sale limpio.'],
      ),
      exercise(
        'rdl-tecnico',
        'Peso muerto rumano tecnico',
        'Basico tecnico',
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
        'Basico',
        'D',
        3,
        11,
        85,
        90,
        ['Rango 10-12 reps. Pausa arriba.'],
      ),
      exercise(
        'gemelos-sentado-multipower',
        'Elevacion de gemelos sentado o en prensa/multipower',
        'Accesorio',
        'E',
        3,
        15,
        0,
        60,
        ['Usar RIR 2 si la maquina no tiene referencia clara.'],
      ),
      exercise(
        'curl-biceps-barra-mancuernas',
        'Curl biceps barra o mancuernas',
        'Accesorio',
        'F1',
        3,
        11,
        15,
        60,
        ['Peso por mancuerna si se usan mancuernas.'],
      ),
      exercise(
        'extension-triceps-polea',
        'Extension triceps polea',
        'Accesorio',
        'F2',
        3,
        11,
        0,
        60,
        ['Rango 10-12 reps con RIR 2.'],
      ),
      exercise(
        'elevacion-lateral-mecanica',
        'Elevacion lateral mecanica',
        'Accesorio',
        'G',
        3,
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
  'press-militar-pie': { step: 2.5, max: 45 },
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

  if (templateWeek >= 5 && templateWeek <= 7 && item.type === 'Basico') {
    setCount = item.exerciseId.includes('dominadas')
      ? 6
      : Math.max(item.setCount, 5);
    reps = Math.max(4, item.reps - 1);
    restSeconds = Math.max(restSeconds, 150);
  }

  if (templateWeek >= 9 && templateWeek <= 11 && item.type === 'Basico') {
    setCount = item.exerciseId.includes('hip-thrust')
      ? 4
      : Math.max(item.setCount, 5);
    reps =
      item.exerciseId.includes('hip-thrust') ||
      item.exerciseId.includes('rumano')
        ? 5
        : 3;
    restSeconds = Math.max(restSeconds, 180);
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
    setCount = item.type === 'Basico' ? 2 : Math.min(2, item.setCount);
    reps = item.type === 'Basico' ? Math.max(3, item.reps) : item.reps;
    restSeconds =
      item.type === 'Basico' ? Math.max(180, restSeconds) : restSeconds;
  }

  const sets = Array.from({ length: setCount }, (_, index) => ({
    setIndex: index + 1,
    targetReps: reps,
    targetWeightKg: roundLoad(weightKg),
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
        : `${setCount}x${reps} @ ${formatKg(roundLoad(weightKg))}`,
    decisionOptions: decisionOptions(item, templateWeek, roundLoad(weightKg), {
      postVacationAdaptation,
    }),
    sets,
  };
}

function decisionOptions(item, week, weightKg, options = {}) {
  if (item.weightKg === 0) {
    return options.postVacationAdaptation
      ? ['Mantener suave', 'Subir reps si facil', 'Marcar molestia']
      : ['Mantener', 'Subir reps', 'Marcar molestia'];
  }

  const step =
    item.type === 'Basico' && item.name.includes('Hip thrust') ? 5 : 2.5;
  const next = roundLoad(weightKg + step);
  const down = roundLoad(Math.max(0, weightKg - step));

  if (options.postVacationAdaptation) {
    return ['Mantener suave', `Subir a ${formatKg(next)}`, 'Marcar molestia'];
  }

  if (week === 4 || week === 8) {
    return [
      'Cerrar descarga',
      `Volver a ${formatKg(item.weightKg)}`,
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
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
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

function formatKg(value) {
  return `${Number.isInteger(value) ? value : value.toFixed(1)} kg`;
}
