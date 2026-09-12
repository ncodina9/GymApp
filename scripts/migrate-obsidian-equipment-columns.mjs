import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';

const obsidianGymPath =
  '/Users/nstr/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/10. Gym';
const exportsDir = resolve(obsidianGymPath, 'sesiones/exports');
const masterCsvPath = resolve(
  obsidianGymPath,
  'data/Registro entrenamiento series.csv',
);

const canonicalHeaders = [
  'date',
  'performed_at',
  'week',
  'session',
  'exercise_id',
  'base_exercise_id',
  'exercise',
  'base_exercise',
  'variant_label',
  'type',
  'target',
  'set_number',
  'status',
  'load_kg',
  'load_type',
  'planned_equipment',
  'actual_equipment',
  'reps',
  'rir',
  'pain_knee',
  'pain_wrist',
  'pain_shoulder',
  'pain_lumbar',
  'pain_other',
  'set_note',
  'exercise_decision',
  'exercise_note',
  'superset_id',
  'superset_order',
  'round_number',
];

const exerciseMigrations = new Map([
  [
    'Curl femoral máquina',
    {
      exercise: 'Curl femoral en banco con discos',
      target: '3x11 @ 20 kg',
      loadType: 'machine',
      equipment: 'plate_loaded_machine',
    },
  ],
  [
    'Elevación de gemelos de pie',
    {
      exercise: 'Elevación de gemelos en multipower',
      target: '3x12 @ 58 kg',
      loadType: 'total',
      equipment: 'multipower',
      actualLoadKg: '58',
    },
  ],
  [
    'Press banca inclinado con barra o mancuernas',
    {
      exercise: 'Press banca inclinado con barra',
      target: '4x8 @ 47.5 kg',
      loadType: 'total',
      equipment: 'barbell',
    },
  ],
  [
    'Remo con barra o remo en multipower',
    {
      exercise: 'Remo en multipower',
      target: '4x10 @ 53 kg',
      loadType: 'total',
      equipment: 'multipower',
      actualLoadKg: '53',
    },
  ],
]);

const defaultEquipmentByLoadType = {
  total: 'barbell',
  external: 'external',
  per_dumbbell: 'dumbbell',
  machine: 'cable',
  bodyweight: 'bodyweight',
};

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');

const files = [
  ...listCsvFiles(exportsDir),
  ...(existsSync(masterCsvPath) ? [masterCsvPath] : []),
];

let changedFiles = 0;

for (const filePath of files) {
  const parsed = readCsv(filePath);
  const migratedRows = parsed.rows.map(migrateRow);
  const output = toCsv([canonicalHeaders, ...migratedRows.map(rowToArray)]);
  const input = readFileSync(filePath, 'utf8');

  if (output !== normalizeFinalNewline(input)) {
    changedFiles += 1;
    console.log(
      `${dryRun ? 'Cambiaría' : 'Actualizado'}: ${basename(filePath)}`,
    );

    if (!dryRun) {
      writeFileSync(filePath, output, 'utf8');
    }
  }
}

console.log(
  `${dryRun ? 'DRY RUN' : 'Migración completada'}: ${changedFiles}/${files.length} ficheros con cambios.`,
);

function listCsvFiles(directoryPath) {
  if (!existsSync(directoryPath)) {
    return [];
  }

  return readdirSync(directoryPath, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.csv'))
    .map((entry) => resolve(directoryPath, entry.name))
    .sort((a, b) => basename(a).localeCompare(basename(b), 'es'));
}

function migrateRow(row) {
  const migrated = Object.fromEntries(
    canonicalHeaders.map((header) => [header, row[header] ?? '']),
  );
  const exerciseMigration = exerciseMigrations.get(row.exercise);
  const equipment =
    exerciseMigration?.equipment ??
    row.actual_equipment ??
    row.planned_equipment ??
    defaultEquipmentByLoadType[row.load_type] ??
    '';

  if (exerciseMigration) {
    migrated.exercise = exerciseMigration.exercise;
    migrated.base_exercise = row.base_exercise || exerciseMigration.exercise;
    migrated.target = exerciseMigration.target;
    migrated.load_type = exerciseMigration.loadType;

    if (exerciseMigration.actualLoadKg && migrated.status !== 'skipped') {
      migrated.load_kg = exerciseMigration.actualLoadKg;
    }
  }

  migrated.exercise_id = row.exercise_id;
  migrated.base_exercise_id = row.base_exercise_id || row.exercise_id;
  migrated.base_exercise =
    migrated.base_exercise || row.base_exercise || row.exercise;
  migrated.variant_label = row.variant_label;
  migrated.planned_equipment = row.planned_equipment || equipment;
  migrated.actual_equipment = row.actual_equipment || equipment;
  migrated.exercise_decision = normalizeDecision(row.exercise_decision);

  return migrated;
}

function normalizeDecision(decision) {
  if (!decision) {
    return '';
  }

  const normalized = decision.toLowerCase();

  if (normalized.includes('subir') && normalized.includes('rep')) {
    return 'Subir reps';
  }

  if (normalized.includes('bajar') && normalized.includes('rep')) {
    return 'Bajar reps';
  }

  if (normalized.includes('subir')) {
    return 'Subir peso';
  }

  if (normalized.includes('bajar')) {
    return 'Bajar peso';
  }

  if (normalized.includes('molestia')) {
    return 'Marcar molestia';
  }

  if (normalized.includes('mantener')) {
    return 'Mantener';
  }

  return decision;
}

function readCsv(filePath) {
  const rows = parseCsv(readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
  const headers = rows[0] ?? [];
  const bodyRows = rows
    .slice(1)
    .filter((row) => row.some((value) => value.trim() !== ''));

  return {
    headers,
    rows: bodyRows.map((values) =>
      Object.fromEntries(
        headers.map((header, index) => [header, values[index] ?? '']),
      ),
    ),
  };
}

function rowToArray(row) {
  return canonicalHeaders.map((header) => row[header] ?? '');
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

  return rows;
}

function toCsv(rows) {
  return `${rows.map((row) => row.map(csvEscape).join(',')).join('\n')}\n`;
}

function csvEscape(value) {
  const text = String(value ?? '');
  return /[",\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function normalizeFinalNewline(text) {
  return text.endsWith('\n') ? text : `${text}\n`;
}
