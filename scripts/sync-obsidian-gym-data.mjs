import { readFileSync, rmSync, writeFileSync } from 'node:fs';
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
    'estimated_minutes',
    'focus',
    'exercise_count',
    'exercises',
  ],
  ...plan.sessions.map((session) => [
    session.week,
    session.date,
    session.weekday,
    session.label,
    session.sessionLabel,
    session.estimatedMinutes,
    session.focus,
    session.exercises.length,
    session.exercises.map((exercise) => exercise.name).join('; '),
  ]),
];

writeFileSync(calendarPath, toCsv(calendarRows));

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
5. Guardar el CSV exportado en Archivos y moverlo o concatenarlo en Obsidian.

## CSV maestro serie a serie

Archivo: \`10. Gym/data/Registro entrenamiento series.csv\`

Formato:

\`\`\`csv
date,week,session,exercise,type,target,set_number,status,load_kg,load_type,reps,rir,pain_knee,pain_wrist,pain_other,set_note,exercise_decision,exercise_note
2026-09-07,1,Lunes - Torso fuerza,Press banca con barra,Básico,5x5 @ 65 kg,1,done,65,total,5,2,0,0,,OK,,
\`\`\`

## Nombres estándar

Estos nombres salen del plan activo:

${exerciseNames.map((name) => `- ${name}`).join('\n')}

## Reglas de interpretación de carga

- \`total\`: carga total en barra, multipower o movimiento equivalente.
- \`external\`: lastre añadido, por ejemplo dominadas con \`+5 kg\`.
- \`per_dumbbell\`: peso por mancuerna.
- \`machine\`: carga indicada por máquina o polea; vacío si todavía no hay referencia fiable.
- \`bodyweight\`: peso corporal registrado como \`0 kg\` en la app.
`;
}

function buildDashboardNote() {
  return `# Dashboard entrenamiento

Datos principales:

- Plan activo: \`10. Gym/data/Plan entrenamiento calendario.csv\`
- Registro serie a serie: \`10. Gym/data/Registro entrenamiento series.csv\`
- Historial antiguo GymBook: \`10. Gym/data/GymBook logs normalizado.jsonl\`
- Resumen antiguo GymBook: \`10. Gym/data/GymBook resumen ejercicios.json\`

## Calendario del plan activo

\`\`\`dataviewjs
const csv = await app.vault.adapter.read("10. Gym/data/Plan entrenamiento calendario.csv");
const rows = parseCsv(csv);
dv.table(
  ["Semana", "Fecha", "Día", "Sesión", "Ejercicios"],
  rows.map(r => [r.week, r.date, r.day, r.session_label, r.exercise_count])
);

function parseCsv(text) {
  const lines = text.trim().split("\\n");
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
\`\`\`

## Registro serie a serie

\`\`\`dataviewjs
const csv = await app.vault.adapter.read("10. Gym/data/Registro entrenamiento series.csv");
const rows = parseCsv(csv);
if (rows.length === 0) {
  dv.paragraph("Todavía no hay series registradas desde GymApp.");
} else {
  dv.table(
    ["Fecha", "Sesión", "Ejercicio", "Serie", "Estado", "Carga", "Reps", "RIR"],
    rows.slice(-40).reverse().map(r => [r.date, r.session, r.exercise, r.set_number, r.status, r.load_kg, r.reps, r.rir])
  );
}

function parseCsv(text) {
  const lines = text.trim().split("\\n");
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
\`\`\`

## Historial GymBook

Los ficheros de GymBook quedan como referencia histórica previa a GymApp. No son la fuente de verdad del plan actual.
`;
}

function toCsv(rows) {
  return `${rows.map((row) => row.map(csvEscape).join(',')).join('\n')}\n`;
}

function csvEscape(value) {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
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
