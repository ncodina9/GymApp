import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';

const obsidianGymPath =
  '/Users/nstr/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/10. Gym';

const defaultSourceDir = resolve(obsidianGymPath, 'sesiones/exports');
const defaultTargetPath = resolve(
  obsidianGymPath,
  'data/Registro entrenamiento series.csv',
);

const canonicalHeaders = [
  'date',
  'performed_at',
  'week',
  'session',
  'exercise',
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

const args = parseArgs(process.argv.slice(2));
const sourceDir = resolve(args.source ?? defaultSourceDir);
const targetPath = resolve(args.target ?? defaultTargetPath);
const dryRun = args.dryRun ?? false;

const targetRows = readCsvFileIfExists(targetPath);
const normalizedTargetRows = targetRows.map((row) =>
  normalizeRow(row, targetRows.headers),
);
const seenKeys = buildSeenKeys(normalizedTargetRows);

const sourceFiles = listCsvFiles(sourceDir);
const importedRows = [];
const skippedRows = [];

for (const sourceFile of sourceFiles) {
  const sourceRows = readCsvFile(sourceFile);

  for (const row of sourceRows) {
    const normalizedRow = normalizeRow(row, sourceRows.headers);
    const duplicateKey = findDuplicateKey(normalizedRow, seenKeys);

    if (duplicateKey) {
      skippedRows.push({ sourceFile, duplicateKey, row: normalizedRow });
      continue;
    }

    addRowKeys(normalizedRow, seenKeys);
    importedRows.push({ sourceFile, row: normalizedRow });
  }
}

const outputRows = [
  canonicalHeaders,
  ...normalizedTargetRows.map(rowToArray),
  ...importedRows.map(({ row }) => rowToArray(row)),
];

if (!dryRun) {
  writeFileSync(targetPath, toCsv(outputRows), 'utf8');
}

console.log(
  [
    dryRun
      ? 'DRY RUN: no se ha modificado el CSV maestro.'
      : 'CSV maestro actualizado.',
    `Destino: ${targetPath}`,
    `Exports revisados: ${sourceFiles.length}`,
    `Filas existentes normalizadas: ${normalizedTargetRows.length}`,
    `Filas nuevas importadas: ${importedRows.length}`,
    `Filas omitidas por duplicado: ${skippedRows.length}`,
  ].join('\n'),
);

if (importedRows.length > 0) {
  const importsByFile = countBy(importedRows, ({ sourceFile }) =>
    basename(sourceFile),
  );
  console.log('\nImportadas por archivo:');
  for (const [fileName, count] of importsByFile) {
    console.log(`- ${fileName}: ${count}`);
  }
}

function parseArgs(rawArgs) {
  const parsed = {};

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    const nextArg = rawArgs[index + 1];

    if (arg === '--dry-run') {
      parsed.dryRun = true;
    } else if (arg === '--source') {
      if (!nextArg) {
        throw new Error('Falta el valor de --source.');
      }
      parsed.source = nextArg;
      index += 1;
    } else if (arg === '--target') {
      if (!nextArg) {
        throw new Error('Falta el valor de --target.');
      }
      parsed.target = nextArg;
      index += 1;
    } else {
      throw new Error(`Argumento no reconocido: ${arg}`);
    }
  }

  return parsed;
}

function listCsvFiles(directoryPath) {
  if (!existsSync(directoryPath)) {
    return [];
  }

  return readdirSync(directoryPath, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.csv'))
    .map((entry) => resolve(directoryPath, entry.name))
    .sort((a, b) => basename(a).localeCompare(basename(b), 'es'));
}

function readCsvFileIfExists(filePath) {
  if (!existsSync(filePath)) {
    return attachHeaders([]);
  }

  return readCsvFile(filePath);
}

function readCsvFile(filePath) {
  const text = readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
  const rows = parseCsv(text);

  if (rows.length === 0) {
    return attachHeaders([]);
  }

  const headers = rows[0];
  const bodyRows = rows
    .slice(1)
    .filter((row) => row.some((value) => value.trim() !== ''))
    .map((values) =>
      Object.fromEntries(
        headers.map((header, index) => [header, values[index] ?? '']),
      ),
    );

  return attachHeaders(bodyRows, headers);
}

function attachHeaders(rows, headers = canonicalHeaders) {
  Object.defineProperty(rows, 'headers', {
    value: headers,
    enumerable: false,
  });
  return rows;
}

function normalizeRow(row, sourceHeaders) {
  const normalized = Object.fromEntries(
    canonicalHeaders.map((header) => [header, row[header] ?? '']),
  );

  if (!sourceHeaders.includes('status')) {
    normalized.status = 'done';
  }

  return normalized;
}

function buildSeenKeys(rows) {
  const seenKeys = new Set();
  rows.forEach((row) => addRowKeys(row, seenKeys));
  return seenKeys;
}

function addRowKeys(row, seenKeys) {
  getRowKeys(row).forEach((key) => seenKeys.add(key));
}

function findDuplicateKey(row, seenKeys) {
  return getRowKeys(row).find((key) => seenKeys.has(key));
}

function getRowKeys(row) {
  const keys = [];

  if (row.performed_at) {
    keys.push(`performed_at:${row.performed_at}`);
  }

  if (row.date && row.session && row.exercise && row.set_number) {
    keys.push(
      [
        'series',
        row.date,
        row.session,
        row.exercise,
        row.set_number,
        row.superset_id,
        row.superset_order,
        row.round_number,
      ].join('|'),
    );
    keys.push(
      [
        'legacy-series',
        row.date,
        row.session,
        row.exercise,
        row.set_number,
      ].join('|'),
    );
  }

  return keys;
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

function countBy(items, getKey) {
  const counts = new Map();

  for (const item of items) {
    const key = getKey(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  return Array.from(counts.entries()).sort((a, b) =>
    a[0].localeCompare(b[0], 'es'),
  );
}
