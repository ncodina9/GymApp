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

writeFileSync(
  resolve(obsidianGymPath, 'Dashboard entrenamiento.md'),
  buildDashboardNote(),
);

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
date,performed_at,week,session,exercise,type,target,set_number,status,load_kg,load_type,planned_equipment,actual_equipment,reps,rir,pain_knee,pain_wrist,pain_shoulder,pain_lumbar,pain_other,set_note,exercise_decision,exercise_note,superset_id,superset_order,round_number
2026-09-07,2026-09-07T19:42:10.000+02:00,1,Lunes - Torso fuerza,Press banca con barra,Básico,5x5 @ 65 kg,1,done,65,total,barbell,barbell,5,2,0,0,0,0,,OK,,,,,
\`\`\`

El importador normaliza el CSV maestro a esas cabeceras y omite las series que ya estén registradas.

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

function buildDashboardNote() {
  return `# Dashboard entrenamiento

Datos principales:

- Plan activo: \`10. Gym/data/Plan entrenamiento calendario.csv\`
- Registro serie a serie: \`10. Gym/data/Registro entrenamiento series.csv\`
- Estadísticas derivadas: \`10. Gym/data/Estadisticas entrenamiento.csv\`
- Historial antiguo GymBook: \`10. Gym/data/GymBook logs normalizado.jsonl\`
- Resumen antiguo GymBook: \`10. Gym/data/GymBook resumen ejercicios.json\`

## Panel visual

\`\`\`dataviewjs
const calendar = parseCsv(await app.vault.adapter.read("10. Gym/data/Plan entrenamiento calendario.csv"));
const logText = await app.vault.adapter.read("10. Gym/data/Registro entrenamiento series.csv").catch(() => "");
const statisticsText = await app.vault.adapter.read("10. Gym/data/Estadisticas entrenamiento.csv").catch(() => "");
const logs = parseCsv(logText).filter(row => row.status === "done");
const statisticsRows = parseCsv(statisticsText);
const volumeExposures = statisticsRows.filter(row => row.table === "exercise_volume_exposure");
const volumeSource = volumeExposures.length ? volumeExposures : buildVolumeExposuresFromLogs(logs);
const today = new Date();
const todayIso = today.toISOString().slice(0, 10);
const nextSession = calendar.find(row => row.date >= todayIso) ?? calendar.at(-1);
const currentWeek = Number(nextSession?.week ?? logs.at(-1)?.week ?? 1);
const weekPlan = calendar.filter(row => Number(row.week) === currentWeek);
const weekLogs = logs.filter(row => Number(row.week) === currentWeek);
const completedSessionKeys = new Set(weekLogs.map(row => \`\${row.date}|\${row.session}\`));
const totalSets = logs.length;
const avgRir = average(logs.map(row => number(row.rir)).filter(value => Number.isFinite(value)));
const volume = volumeSource.reduce((sum, row) => sum + number(row.value), 0);
const painSets = logs.filter(row =>
  ["pain_knee", "pain_wrist", "pain_shoulder", "pain_lumbar", "pain_other"]
    .some(key => number(row[key]) > 0)
).length;

dv.el("style", \`
.training-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:12px 0 18px}
.training-card{border:1px solid var(--background-modifier-border);border-radius:8px;padding:12px;background:var(--background-secondary)}
.training-label{font-size:12px;color:var(--text-muted);margin-bottom:4px}
.training-value{font-size:24px;font-weight:700;line-height:1.1}
.training-sub{font-size:12px;color:var(--text-muted);margin-top:5px}
.training-canvas{width:100%;height:260px;border:1px solid var(--background-modifier-border);border-radius:8px;background:var(--background-primary);margin:8px 0 18px}
.training-list{display:grid;gap:8px;margin:8px 0 18px}
.training-item{border:1px solid var(--background-modifier-border);border-radius:8px;padding:10px;background:var(--background-secondary)}
.training-item strong{display:block;margin-bottom:3px}
.training-muted{color:var(--text-muted);font-size:12px}
\`);

const cards = dv.el("div", "", { cls: "training-grid" });
cards.append(card("Semana", currentWeek, nextSession?.week_focus_label ?? ""));
cards.append(card("Sesiones semana", \`\${completedSessionKeys.size}/\${weekPlan.length}\`, nextSession?.week_focus ?? ""));
cards.append(card("Series registradas", totalSets, logs.length ? \`RIR medio \${format(avgRir, 1)}\` : "Sin registros"));
cards.append(card("Volumen registrado", \`\${Math.round(volume)} kg\`, volumeExposures.length ? "Desde CSV estadístico v4" : "Calculado desde series"));

dv.header(3, "Objetivo semanal");
const weekBox = dv.el("div", "", { cls: "training-list" });
weekPlan.forEach(session => {
  const done = completedSessionKeys.has(\`\${session.date}|\${session.session_label}\`) || completedSessionKeys.has(\`\${session.date}|\${session.session}\`);
  weekBox.append(item(
    \`\${session.day} \${session.date}: \${session.session}\`,
    \`\${done ? "Hecho" : "Pendiente"} · \${session.planned_sets} series · \${session.basic_count} básicos · \${session.focus}\`
  ));
});

dv.header(3, "Progreso por ejercicio");
drawExerciseVolumeChart(dv.el("canvas", "", { cls: "training-canvas" }), volumeSource);
dv.table(
  ["Ejercicio", "Series", "Mejor carga", "Mejores reps", "RIR medio", "Última decisión"],
  exerciseSummary(logs).slice(0, 12).map(row => [
    row.exercise,
    row.sets,
    row.bestLoad,
    row.bestReps,
    format(row.avgRir, 1),
    row.lastDecision || ""
  ])
);

dv.header(3, "Tendencia de cargas principales");
drawLoadTrendChart(dv.el("canvas", "", { cls: "training-canvas" }), logs);

dv.header(2, "Calendario del plan activo");
dv.table(
  ["Semana", "Fecha", "Día", "Sesión", "Fase", "Series", "Básicos", "Foco"],
  calendar.map(r => [r.week, r.date, r.day, r.session_label, r.phase, r.planned_sets, r.basic_count, r.week_focus_label])
);

dv.header(2, "Próximas sesiones");
dv.table(
  ["Fecha", "Sesión", "Objetivos"],
  calendar.filter(r => r.date >= todayIso).slice(0, 6).map(r => [r.date, r.session_label, r.exercise_targets])
);

dv.header(2, "Registro serie a serie");
if (logs.length === 0) {
  dv.paragraph("Todavía no hay series registradas desde GymApp.");
} else {
  dv.table(
    ["Fecha", "Sesión", "Ejercicio", "Serie", "Estado", "Carga", "Material", "Reps", "RIR", "Nota"],
    logs.slice(-40).reverse().map(r => [r.date, r.session, r.exercise, r.set_number, r.status, r.load_kg, r.actual_equipment || r.planned_equipment || "", r.reps, r.rir, r.set_note])
  );
}

dv.header(2, "Historial GymBook");
dv.paragraph("Los ficheros de GymBook quedan como referencia histórica previa a GymApp. No son la fuente de verdad del plan actual.");

function parseCsv(text) {
  const lines = text.trim().split(/\\r?\\n/).filter(Boolean);
  if (lines.length <= 1) return [];
  const headers = parseCsvLine(lines.shift());
  return lines.map(line => {
    const values = parseCsvLine(line);
    return Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""]));
  });
}

function parseCsvLine(line) {
  const values = [];
  let current = "";
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    const next = line[index + 1];
    if (char === '"' && quoted && next === '"') {
      current += '"';
      index += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      values.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  values.push(current);
  return values;
}

function number(value) {
  const parsed = Number(String(value ?? "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : 0;
}

function average(values) {
  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0;
}

function format(value, digits = 0) {
  return Number.isFinite(value) ? value.toFixed(digits) : "";
}

function parseSets(value) {
  const match = String(value ?? "").match(/^(\\d+)/);
  return match ? Number(match[1]) : 0;
}

function card(label, value, sub) {
  const el = document.createElement("div");
  el.className = "training-card";
  el.innerHTML = \`<div class="training-label">\${escapeHtml(label)}</div><div class="training-value">\${escapeHtml(value)}</div><div class="training-sub">\${escapeHtml(sub)}</div>\`;
  return el;
}

function item(title, body) {
  const el = document.createElement("div");
  el.className = "training-item";
  el.innerHTML = \`<strong>\${escapeHtml(title)}</strong><div class="training-muted">\${escapeHtml(body)}</div>\`;
  return el;
}

function exerciseSummary(logs) {
  const groups = groupBy(logs, row => row.exercise);
  return Object.entries(groups).map(([exercise, rows]) => {
    const last = rows.at(-1) ?? {};
    return {
      exercise,
      sets: rows.length,
      bestLoad: Math.max(...rows.map(row => number(row.load_kg))),
      bestReps: Math.max(...rows.map(row => number(row.reps))),
      avgRir: average(rows.map(row => number(row.rir))),
      volume: rows.reduce((sum, row) => sum + number(row.load_kg) * number(row.reps), 0),
      lastDecision: last.exercise_decision ?? "",
    };
  }).sort((a, b) => b.volume - a.volume || b.sets - a.sets);
}

function buildVolumeExposuresFromLogs(logs) {
  return Object.entries(groupBy(logs, row => \`\${row.date}|\${row.session}|\${row.exercise}\`)).map(([key, rows]) => {
    const [date, session, exercise] = key.split("|");
    const loadType = rows.find(row => row.load_type)?.load_type ?? "";
    const value = rows.reduce((sum, row) => {
      const load = number(row.load_kg);
      const effectiveLoad = loadType === "per_dumbbell" ? load * 2 : load;
      return sum + effectiveLoad * number(row.reps);
    }, 0);
    return {
      table: "exercise_volume_exposure",
      date,
      week: rows[0]?.week ?? "",
      session,
      exercise,
      primary_muscles: "",
      value,
      value_2: \`\${rows.length} sets\`,
      notes: \`\${rows.reduce((sum, row) => sum + number(row.reps), 0)} reps · 0s\`,
    };
  });
}

function exerciseVolumeSummary(rows) {
  return Object.entries(groupBy(rows, row => row.exercise)).map(([exercise, values]) => ({
    exercise,
    sets: values.reduce((sum, row) => sum + parseSets(row.value_2), 0),
    volume: values.reduce((sum, row) => sum + number(row.value), 0),
  })).sort((a, b) => b.volume - a.volume || b.sets - a.sets);
}

function groupBy(rows, getKey) {
  return rows.reduce((groups, row) => {
    const key = getKey(row) || "Sin clasificar";
    groups[key] ??= [];
    groups[key].push(row);
    return groups;
  }, {});
}

function drawExerciseVolumeChart(canvas, volumeRows) {
  const data = exerciseVolumeSummary(volumeRows)
    .filter(row => row.volume > 0)
    .slice(0, 8)
    .reverse();
  drawBarChart(canvas, data.map(row => ({ label: row.exercise, value: row.volume })), "Volumen por ejercicio");
}

function drawLoadTrendChart(canvas, logs) {
  const basics = ["Press banca con barra", "Dominadas lastradas", "Remo inclinado con barra", "Press militar sentado en banco", "Sentadilla con barra", "Peso muerto rumano con barra", "Hip thrust / puente con barra"];
  const series = basics.map(exercise => ({
    label: exercise,
    points: logs
      .filter(row => row.exercise === exercise)
      .map(row => ({ x: row.performed_at || row.date, y: number(row.load_kg) }))
      .filter(point => point.y > 0)
  })).filter(item => item.points.length);
  drawLineChart(canvas, series, "Carga por serie");
}

function drawBarChart(canvas, data, title) {
  prepareCanvas(canvas);
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  const pad = { top: 34, right: 22, bottom: 24, left: 150 };
  clear(ctx, w, h, title);
  if (!data.length) return empty(ctx, w, h, "Sin datos suficientes");
  const max = Math.max(...data.map(item => item.value));
  const rowH = (h - pad.top - pad.bottom) / data.length;
  ctx.font = "12px system-ui";
  data.forEach((item, index) => {
    const y = pad.top + index * rowH + rowH * 0.22;
    const barW = ((w - pad.left - pad.right) * item.value) / max;
    ctx.fillStyle = "rgba(76, 141, 245, 0.85)";
    ctx.fillRect(pad.left, y, barW, Math.max(8, rowH * 0.45));
    ctx.fillStyle = getTextColor();
    ctx.fillText(truncate(item.label, 22), 12, y + 11);
    ctx.fillText(String(Math.round(item.value)), pad.left + barW + 6, y + 11);
  });
}

function drawLineChart(canvas, series, title) {
  prepareCanvas(canvas);
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  const pad = { top: 34, right: 22, bottom: 30, left: 42 };
  clear(ctx, w, h, title);
  if (!series.length) return empty(ctx, w, h, "Sin datos suficientes");
  const maxPoints = Math.max(...series.map(item => item.points.length));
  const maxY = Math.max(...series.flatMap(item => item.points.map(point => point.y)));
  const colors = ["#4c8df5", "#22a06b", "#f5a524", "#d45b7a", "#8b5cf6", "#0891b2", "#64748b"];
  ctx.strokeStyle = "rgba(130,130,130,.35)";
  ctx.beginPath();
  ctx.moveTo(pad.left, pad.top);
  ctx.lineTo(pad.left, h - pad.bottom);
  ctx.lineTo(w - pad.right, h - pad.bottom);
  ctx.stroke();
  series.forEach((item, idx) => {
    const color = colors[idx % colors.length];
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    item.points.forEach((point, index) => {
      const x = pad.left + ((w - pad.left - pad.right) * index) / Math.max(1, maxPoints - 1);
      const y = h - pad.bottom - ((h - pad.top - pad.bottom) * point.y) / maxY;
      if (index === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
    item.points.forEach((point, index) => {
      const x = pad.left + ((w - pad.left - pad.right) * index) / Math.max(1, maxPoints - 1);
      const y = h - pad.bottom - ((h - pad.top - pad.bottom) * point.y) / maxY;
      ctx.beginPath();
      ctx.arc(x, y, 3, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.font = "11px system-ui";
    ctx.fillText(truncate(item.label, 20), pad.left + 8, pad.top + 14 + idx * 14);
  });
}

function prepareCanvas(canvas) {
  const width = canvas.clientWidth || 720;
  const height = canvas.clientHeight || 260;
  canvas.width = width;
  canvas.height = height;
}

function clear(ctx, w, h, title) {
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = getTextColor();
  ctx.font = "600 14px system-ui";
  ctx.fillText(title, 12, 22);
}

function empty(ctx, w, h, label) {
  ctx.fillStyle = "rgba(130,130,130,.8)";
  ctx.font = "13px system-ui";
  ctx.fillText(label, 14, h / 2);
}

function getTextColor() {
  return getComputedStyle(document.body).getPropertyValue("--text-normal").trim() || "#222";
}

function truncate(value, max) {
  return String(value).length > max ? String(value).slice(0, max - 1) + "…" : String(value);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
\`\`\`
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
    const key = row[9] || row[10];
    const current = summaries.get(key) ?? {
      exerciseId: row[9],
      exerciseName: row[10],
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
