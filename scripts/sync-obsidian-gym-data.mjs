import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '..');
const planPath = resolve(repoRoot, 'data/trainingPlan.json');
const obsidianGymPath =
  '/Users/nstr/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/10. Gym';
const obsidianDataPath = resolve(obsidianGymPath, 'data');

const plan = JSON.parse(readFileSync(planPath, 'utf8'));
const calendarPath = resolve(
  obsidianDataPath,
  'Plan entrenamiento calendario.csv',
);
const workoutLogPath = resolve(
  obsidianDataPath,
  'Registro entrenamiento series.csv',
);
const statisticsPath = resolve(
  obsidianDataPath,
  'Estadisticas entrenamiento.csv',
);
const legacyCalendarPath = resolve(
  obsidianDataPath,
  'Plan 12 semanas calendario.csv',
);
const legacyManualLogPath = resolve(
  obsidianDataPath,
  'Registro entrenamiento manual.csv',
);

const calendarRows = [
  [
    'week',
    'date',
    'day',
    'session',
    'session_label',
    'phase',
    'week_focus_label',
    'week_focus',
    'estimated_minutes',
    'focus',
    'exercise_count',
    'basic_count',
    'planned_sets',
    'exercises',
    'exercise_targets',
    'exercise_details',
  ],
  ...plan.sessions.map((session) => {
    const basicCount = session.exercises.filter((exercise) =>
      normalize(exercise.type).startsWith('basico'),
    ).length;
    const plannedSets = session.exercises.reduce(
      (sum, exercise) => sum + exercise.sets.length,
      0,
    );

    return [
      session.week,
      session.date,
      session.weekday,
      session.label,
      session.sessionLabel,
      session.exercises[0]?.phase ?? '',
      session.weekFocusLabel ?? '',
      session.weekFocus ?? '',
      session.estimatedMinutes,
      session.focus,
      session.exercises.length,
      basicCount,
      plannedSets,
      session.exercises.map((exercise) => exercise.name).join('; '),
      session.exercises
        .map((exercise) => `${exercise.name}: ${exercise.target}`)
        .join('; '),
      session.exercises
        .map((exercise) => {
          const firstSet = exercise.sets[0] ?? {};
          const rest = firstSet.restSeconds
            ? `descanso ${formatRest(firstSet.restSeconds)}`
            : 'descanso n.a.';
          return `${exercise.name}: ${exercise.target}, ${rest}`;
        })
        .join('; '),
    ];
  }),
];

writeFileSync(calendarPath, toCsv(calendarRows));
writeFileSync(
  statisticsPath,
  buildObsidianStatisticsCsv(plan, readWorkoutLogRows(workoutLogPath)),
);

writeFileSync(
  resolve(obsidianGymPath, 'Registro entrenamiento.md'),
  buildTrainingLogNote(plan),
);

rmIfExists(resolve(obsidianGymPath, 'Dashboard entrenamiento.md'));
rmIfExists(legacyCalendarPath);
rmIfExists(legacyManualLogPath);

function buildTrainingLogNote(trainingPlan) {
  const exerciseNames = Array.from(
    new Set(
      trainingPlan.sessions.flatMap((session) =>
        session.exercises.map((exercise) => exercise.name),
      ),
    ),
  ).sort((a, b) => a.localeCompare(b, 'es'));

  return `# Registro entrenamiento

La fuente de verdad del planning es \`GymApp/data/trainingPlan.json\`.

La companion app registra una fila por serie y exporta el CSV final para guardarlo en \`10. Gym/data/Registro entrenamiento series.csv\` o concatenarlo con ese fichero maestro.

## Flujo actual

1. Abrir GymApp en el iPhone.
2. Elegir el entrenamiento previsto o uno de la semana.
3. Revisar la vista previa para preparar el material.
4. Registrar cada serie con carga, reps, RIR, molestias y feedback.
5. Guardar el CSV exportado en \`10. Gym/sesiones/exports\`.
6. Ejecutar desde GymApp: \`npm run import:obsidian-workouts\`.

## CSV maestro serie a serie

Archivo: \`10. Gym/data/Registro entrenamiento series.csv\`

Formato:

\`\`\`csv
date,performed_at,week,session,exercise_id,base_exercise_id,exercise,base_exercise,variant_label,type,target,set_number,status,load_kg,load_type,planned_equipment,actual_equipment,reps,rir,pain_knee,pain_wrist,pain_shoulder,pain_lumbar,pain_other,set_note,exercise_decision,exercise_note,superset_id,superset_order,round_number
2026-09-07,2026-09-07T19:42:10.000+02:00,1,Lunes - Torso fuerza,press-banca-barra,press-banca,Press banca con barra,Press banca,Barra,Básico,5x5 @ 65 kg,1,done,65,total,barbell,barbell,5,2,0,0,0,0,,OK,,,,,
\`\`\`

El importador normaliza el CSV maestro a esas cabeceras, rellena datos de ejercicio base desde el planning cuando importa exports antiguos y omite las series que ya estén registradas.

## Nombres estándar

Estos nombres salen del plan activo:

${exerciseNames.map((name) => `- ${name}`).join('\n')}

## CSV estadístico derivado

Archivo: \`10. Gym/data/Estadisticas entrenamiento.csv\`

Se genera con \`npm run sync:obsidian\` desde el plan activo y el CSV maestro serie a serie. Usa el schema \`gymapp.statistics-export\` version \`4\` e incluye filas \`exercise_volume_exposure\` para reconstruir volumen por semana, sesión, bloque, patrón y músculo.

## Reglas de interpretación de carga

- \`total\`: carga total en barra, multipower o movimiento equivalente.
- \`external\`: lastre añadido, por ejemplo dominadas con \`+5 kg\`.
- \`per_dumbbell\`: peso por mancuerna.
- \`machine\`: carga indicada por máquina o polea; vacío si todavía no hay referencia fiable.
- \`bodyweight\`: peso corporal registrado como \`0 kg\` en la app.
- \`planned_equipment\`: material previsto en el plan.
- \`actual_equipment\`: material usado realmente ese día.
`;
}

function readWorkoutLogRows(filePath) {
  if (!existsSync(filePath)) {
    return [];
  }

  return parseCsv(readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''))
    .filter((row) => row.status === 'done' || row.status === 'completed')
    .map((row) => ({
      ...row,
      status: row.status === 'completed' ? 'done' : row.status,
    }));
}

function buildObsidianStatisticsCsv(trainingPlan, logs) {
  const exportedAt = new Date().toISOString();
  const headers = [
    'schema_name',
    'schema_version',
    'exported_at',
    'app_version',
    'table',
    'date',
    'week',
    'session_id',
    'session',
    'exercise_id',
    'exercise',
    'target',
    'load_type',
    'planned_equipment',
    'actual_equipment',
    'training_block',
    'movement_pattern',
    'primary_muscles',
    'metric',
    'value',
    'value_2',
    'status',
    'tone',
    'recommendation',
    'notes',
  ];
  const schemaName = 'gymapp.statistics-export';
  const schemaVersion = 4;
  const appVersion = 'obsidian-sync';
  const planSessionByKey = new Map();
  const exerciseBySessionAndName = new Map();

  trainingPlan.sessions.forEach((session) => {
    const sessionKeys = [
      `${session.date}|${session.label}`,
      `${session.date}|${session.sessionLabel}`,
    ];

    sessionKeys.forEach((key) => planSessionByKey.set(key, session));
    session.exercises.forEach((exercise) => {
      sessionKeys.forEach((key) =>
        exerciseBySessionAndName.set(`${key}|${exercise.name}`, exercise),
      );
    });
  });

  const sessions = aggregateRows(logs, (row) => `${row.date}|${row.session}`);
  const sessionHistoryRows = sessions.map(([key, rows]) => {
    const [date, sessionLabel] = key.split('|');
    const planSession = planSessionByKey.get(key);

    return [
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      'session_history',
      date,
      rows[0]?.week ?? planSession?.week ?? '',
      planSession?.sessionId ?? '',
      sessionLabel,
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      'session',
      '',
      planSession?.estimatedMinutes ?? '',
      'complete',
      '',
      '',
      `${rows.length} completed · ${rows.length} attempted`,
    ];
  });
  const exposureRows = aggregateRows(
    logs,
    (row) => `${row.date}|${row.session}|${row.exercise}`,
  ).map(([key, rows]) => {
    const [date, sessionLabel, exerciseName] = key.split('|');
    const planSession = planSessionByKey.get(`${date}|${sessionLabel}`);
    const exercise = exerciseBySessionAndName.get(key);
    const loadType =
      rows.find((row) => row.load_type)?.load_type ??
      inferLoadTypeFromExercise(exercise);
    const completedSets = rows.length;
    const totalReps = rows.reduce((sum, row) => sum + number(row.reps), 0);
    const totalDurationSeconds = rows.reduce(
      (sum, row) => sum + parseDurationSeconds(row.target),
      0,
    );
    const loadVolume = rows.reduce(
      (sum, row) => sum + getEffectiveLoadKg(row, loadType) * number(row.reps),
      0,
    );

    return [
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      'exercise_volume_exposure',
      date,
      rows[0]?.week ?? planSession?.week ?? '',
      planSession?.sessionId ?? '',
      sessionLabel,
      exercise?.exerciseId ?? '',
      exerciseName,
      exercise?.target ?? rows[0]?.target ?? '',
      loadType,
      rows.find((row) => row.planned_equipment)?.planned_equipment ??
        exercise?.equipment ??
        '',
      rows.find((row) => row.actual_equipment)?.actual_equipment ??
        rows.find((row) => row.planned_equipment)?.planned_equipment ??
        exercise?.equipment ??
        '',
      exercise?.trainingBlock ?? '',
      exercise?.movementPattern ?? '',
      (exercise?.primaryMuscles ?? []).join('|'),
      'volume',
      Math.round(loadVolume),
      `${completedSets} sets`,
      '',
      '',
      '',
      `${totalReps} reps · ${totalDurationSeconds}s`,
    ];
  });
  const exerciseRows = summarizeExerciseVolume(exposureRows).map((summary) => [
    schemaName,
    schemaVersion,
    exportedAt,
    appVersion,
    'exercise_volume',
    '',
    '',
    '',
    '',
    summary.exerciseId,
    summary.exerciseName,
    '',
    '',
    '',
    '',
    summary.trainingBlock,
    summary.movementPattern,
    summary.primaryMuscles,
    'volume',
    Math.round(summary.volume),
    `${summary.sets} sets`,
    '',
    '',
    '',
    `${summary.reps} reps · ${summary.seconds}s`,
  ]);
  const muscleRows = summarizeMuscleVolume(exposureRows).map((summary) => [
    schemaName,
    schemaVersion,
    exportedAt,
    appVersion,
    'muscle_volume',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    summary.muscle,
    'volume',
    Math.round(summary.volume),
    `${summary.sets} sets`,
    '',
    '',
    '',
    `${summary.reps} reps · ${summary.seconds}s`,
  ]);
  const rows = [
    headers,
    ...buildStatisticsSummaryRows({
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      trainingPlan,
      logs,
    }),
    ...sessionHistoryRows,
    ...muscleRows,
    ...exerciseRows,
    ...exposureRows,
  ];
  const invalidRow = rows.find((row) => row.length !== headers.length);

  if (invalidRow) {
    throw new Error(
      `Invalid Obsidian statistics CSV row length: expected ${headers.length}, got ${invalidRow.length}.`,
    );
  }

  return toCsv(rows);
}

function buildStatisticsSummaryRows({
  schemaName,
  schemaVersion,
  exportedAt,
  appVersion,
  trainingPlan,
  logs,
}) {
  const currentWeek = Number(logs.at(-1)?.week ?? 1);
  const weekPlan = trainingPlan.sessions.filter(
    (session) => session.week === currentWeek,
  );
  const weekLogs = logs.filter((row) => Number(row.week) === currentWeek);
  const completedSessionKeys = new Set(
    weekLogs.map((row) => `${row.date}|${row.session}`),
  );
  const painHits = logs.filter((row) =>
    [
      'pain_knee',
      'pain_wrist',
      'pain_shoulder',
      'pain_lumbar',
      'pain_other',
    ].some((key) => number(row[key]) > 0),
  ).length;
  const metrics = [
    [
      'week_adherence',
      completedSessionKeys.size,
      weekPlan.length,
      weekPlan[0]?.weekFocusLabel ?? '',
    ],
    ['stored_sessions', new Set(logs.map((row) => row.session)).size, '', ''],
    ['completed_sessions', completedSessionKeys.size, '', ''],
    ['skipped_sets', 0, '', ''],
    ['pain_hits', painHits, '', ''],
  ];

  return metrics.map(([metric, value, value2, notes]) => [
    schemaName,
    schemaVersion,
    exportedAt,
    appVersion,
    'summary',
    '',
    currentWeek,
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    metric,
    value,
    value2,
    '',
    '',
    '',
    notes,
  ]);
}

function aggregateRows(rows, getKey) {
  return Array.from(
    rows
      .reduce((groups, row) => {
        const key = getKey(row);
        const group = groups.get(key) ?? [];
        group.push(row);
        groups.set(key, group);
        return groups;
      }, new Map())
      .entries(),
  ).sort((a, b) => a[0].localeCompare(b[0], 'es'));
}

function summarizeExerciseVolume(exposureRows) {
  const summaries = new Map();

  exposureRows.forEach((row) => {
    const exerciseGroup = getVolumeExerciseGroup(row[9], row[10]);
    const key = exerciseGroup.id;
    const current = summaries.get(key) ?? {
      exerciseId: exerciseGroup.id,
      exerciseName: exerciseGroup.name,
      trainingBlock: row[15],
      movementPattern: row[16],
      primaryMuscles: row[17],
      volume: 0,
      sets: 0,
      reps: 0,
      seconds: 0,
    };
    current.volume += number(row[19]);
    current.sets += parseSets(row[20]);
    current.reps += parseNotesReps(row[24]);
    current.seconds += parseNotesSeconds(row[24]);
    summaries.set(key, current);
  });

  return Array.from(summaries.values()).sort(
    (a, b) =>
      b.sets - a.sets ||
      b.volume - a.volume ||
      a.exerciseName.localeCompare(b.exerciseName, 'es'),
  );
}

function getVolumeExerciseGroup(exerciseId, exerciseName) {
  const groups = {
    'elevaciones-laterales-volumen': {
      id: 'elevaciones-laterales',
      name: 'Elevaciones laterales',
    },
    'triceps-polea-simple': {
      id: 'triceps-polea-simple',
      name: 'Tríceps en polea',
    },
    'triceps-polea-volumen': {
      id: 'triceps-polea-simple',
      name: 'Tríceps en polea',
    },
    'extension-triceps-polea': {
      id: 'triceps-polea-simple',
      name: 'Tríceps en polea',
    },
  };

  return (
    groups[exerciseId] ?? { id: exerciseId || exerciseName, name: exerciseName }
  );
}

function summarizeMuscleVolume(exposureRows) {
  const summaries = new Map();

  exposureRows.forEach((row) => {
    row[17]
      .split('|')
      .map((muscle) => muscle.trim())
      .filter(Boolean)
      .forEach((muscle) => {
        const current = summaries.get(muscle) ?? {
          muscle,
          volume: 0,
          sets: 0,
          reps: 0,
          seconds: 0,
        };
        current.volume += number(row[19]);
        current.sets += parseSets(row[20]);
        current.reps += parseNotesReps(row[24]);
        current.seconds += parseNotesSeconds(row[24]);
        summaries.set(muscle, current);
      });
  });

  return Array.from(summaries.values()).sort(
    (a, b) =>
      b.sets - a.sets ||
      b.volume - a.volume ||
      a.muscle.localeCompare(b.muscle, 'es'),
  );
}

function getEffectiveLoadKg(row, loadType) {
  if (loadType === 'bodyweight') {
    return 0;
  }

  const load = number(row.load_kg);

  if (load <= 0) {
    return 0;
  }

  return loadType === 'per_dumbbell' ? load * 2 : load;
}

function inferLoadTypeFromExercise(exercise) {
  if (exercise?.equipment === 'dumbbell') {
    return 'per_dumbbell';
  }

  if (
    exercise?.equipment === 'cable' ||
    exercise?.equipment === 'plate_loaded_machine'
  ) {
    return 'machine';
  }

  if (exercise?.equipment === 'external') {
    return 'external';
  }

  if (exercise?.equipment === 'bodyweight') {
    return 'bodyweight';
  }

  return 'total';
}

function parseDurationSeconds(target) {
  const match = String(target ?? '').match(/(\d+)\s*s\b/i);
  return match ? Number(match[1]) : 0;
}

function parseSets(value) {
  const match = String(value ?? '').match(/^(\d+)/);
  return match ? Number(match[1]) : 0;
}

function parseNotesReps(value) {
  const match = String(value ?? '').match(/(\d+)\s+reps/i);
  return match ? Number(match[1]) : 0;
}

function parseNotesSeconds(value) {
  const match = String(value ?? '').match(/(\d+)s/i);
  return match ? Number(match[1]) : 0;
}

function toCsv(rows) {
  return `${rows.map((row) => row.map(csvEscape).join(',')).join('\n')}\n`;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let current = '';
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (char === '"' && quoted && next === '"') {
      current += '"';
      index += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === ',' && !quoted) {
      row.push(current);
      current = '';
    } else if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && next === '\n') {
        index += 1;
      }
      row.push(current);
      rows.push(row);
      row = [];
      current = '';
    } else {
      current += char;
    }
  }

  if (current !== '' || row.length > 0) {
    row.push(current);
    rows.push(row);
  }

  if (rows.length === 0) {
    return [];
  }

  const headers = rows[0];
  return rows
    .slice(1)
    .filter((values) => values.some((value) => value.trim() !== ''))
    .map((values) =>
      Object.fromEntries(
        headers.map((header, index) => [header, values[index] ?? '']),
      ),
    );
}

function csvEscape(value) {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function number(value) {
  const parsed = Number(String(value ?? '').replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : 0;
}

function normalize(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function formatRest(seconds) {
  if (seconds % 60 === 0) {
    return `${seconds / 60} min`;
  }

  return `${seconds} s`;
}

function rmIfExists(path) {
  try {
    rmSync(path);
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      throw error;
    }
  }
}
