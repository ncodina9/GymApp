import type {
  StoredSessionMetadata,
  StoredSetEvent,
} from '@/lib/workoutStorage';

export type ExportAppearanceTheme = 'system' | 'light' | 'dark';

export type ExportPhase =
  | 'today'
  | 'preview'
  | 'set'
  | 'feedback'
  | 'rest'
  | 'transition'
  | 'done'
  | 'settings';

export type LoadType =
  | 'total'
  | 'external'
  | 'per_dumbbell'
  | 'machine'
  | 'bodyweight';

export type ExportTrainingSet = {
  setIndex: number;
  targetReps?: number;
  targetWeightKg: number;
  targetDurationSeconds?: number;
  restSeconds: number;
  type: 'working' | 'timed';
};

export type ExportExercise = {
  exerciseId: string;
  name: string;
  type: string;
  block: string;
  supersetId?: string;
  supersetOrder?: number;
  phase: string;
  notes: string;
  target: string;
  decisionOptions: string[];
  sets: ExportTrainingSet[];
};

export type ExportTrainingSession = {
  sessionId: string;
  date: string;
  week: number;
  weekday: string;
  sessionLabel: string;
  label: string;
  estimatedMinutes: number;
  focus: string;
  weekFocusLabel: string;
  weekFocus: string;
  exercises: ExportExercise[];
};

export type ExportTrainingPlan = {
  planId: string;
  startsOn: string;
  endsOn: string;
  durationWeeks: number;
  sessions: ExportTrainingSession[];
};

export type ExportSessionSummary = {
  sessionId: string;
  sessionDate: string;
  sessionLabel: string;
  estimatedMinutes: number;
  derivedEstimatedMinutes: number;
  attemptedSets: number;
  completedSets: number;
  totalSets: number;
  schemaVersion?: number;
  startedAt?: string;
  finishedAt?: string;
  exportedAt?: string;
  firstPerformedAt: string;
  lastPerformedAt: string;
};

export type FullTrainingDataExport = {
  schemaName: 'gymapp.full-training-data-export';
  schemaVersion: 1;
  exportedAt: string;
  app: {
    name: string;
    version: string;
  };
  source: {
    platform: 'pwa';
    localStores: string[];
  };
  plan: ExportTrainingPlan;
  settings: {
    appearanceTheme: ExportAppearanceTheme;
    keepScreenAwake: boolean;
  };
  activeWorkout: {
    selectedSessionId: string;
    phase: ExportPhase;
    exerciseIndex: number;
    setIndex: number;
    startedAt?: string;
    finishedAt?: string;
  };
  sessions: {
    sessionId: string;
    sessionDate: string;
    sessionLabel: string;
    planSession: ExportTrainingSession;
    summary: ExportSessionSummary;
    metadata?: StoredSessionMetadata;
    decisions: Record<string, string>;
    events: StoredSetEvent[];
  }[];
};

export type FullTrainingDataExportInput = {
  plan: ExportTrainingPlan;
  events: StoredSetEvent[];
  metadata: StoredSessionMetadata[];
  summaries: ExportSessionSummary[];
  exportedAt: string;
  app: {
    name: string;
    version: string;
  };
  settings: {
    appearanceTheme: ExportAppearanceTheme;
    keepScreenAwake: boolean;
  };
  activeWorkout: FullTrainingDataExport['activeWorkout'];
};

export const inferLoadType = (
  exercise: Pick<ExportExercise, 'name' | 'notes' | 'sets'> | undefined,
): LoadType => {
  const text = `${exercise?.name ?? ''} ${exercise?.notes ?? ''}`.toLowerCase();

  if (text.includes('dominadas') && !text.includes('peso corporal')) {
    return 'external';
  }

  if (text.includes('press banca inclinado con barra o mancuernas')) {
    return 'total';
  }

  if (
    text.includes('mancuerna') ||
    text.includes('mancuernas') ||
    text.includes('elevaciones laterales') ||
    text.includes('elevacion lateral') ||
    text.includes('elevación lateral') ||
    text.includes('curl biceps alterno') ||
    text.includes('curl bíceps alterno') ||
    text.includes('curl martillo') ||
    text.includes('pull-over')
  ) {
    return 'per_dumbbell';
  }

  if (
    text.includes('polea') ||
    text.includes('maquina') ||
    text.includes('máquina')
  ) {
    return 'machine';
  }

  if ((exercise?.sets[0]?.targetWeightKg ?? 0) === 0) {
    return 'bodyweight';
  }

  return 'total';
};

export const formatExportTarget = (target: string, loadType: LoadType) =>
  loadType === 'external'
    ? target.replace(/@\s*(\d+(?:[.,]\d+)?)\s*kg/i, '@ +$1 kg')
    : target;

export const getWorkoutCsvFileName = (session: ExportTrainingSession) =>
  `${session.date}-${slugifyFilePart(session.label)}.csv`;

export const getFullJsonExportFileName = (planId: string, exportedAt: string) =>
  `${exportedAt.slice(0, 10)}-${slugifyFilePart(planId)}-backup.json`;

export const buildWorkoutCsv = (
  session: ExportTrainingSession,
  records: StoredSetEvent[],
  decisions: Record<string, string>,
) => {
  const headers = [
    'date',
    'week',
    'session',
    'exercise',
    'type',
    'target',
    'set_number',
    'status',
    'load_kg',
    'load_type',
    'reps',
    'rir',
    'pain_knee',
    'pain_wrist',
    'pain_other',
    'set_note',
    'exercise_decision',
    'exercise_note',
    'superset_id',
    'superset_order',
    'round_number',
  ];

  const sortedRecords = [...records].sort((a, b) =>
    a.performedAt.localeCompare(b.performedAt),
  );
  const lastRecordKeyByExercise = new Map<string, string>();

  sortedRecords.forEach((record) => {
    lastRecordKeyByExercise.set(
      record.exerciseId,
      `${record.exerciseIndex}-${record.setIndex}`,
    );
  });

  const rows = sortedRecords.map((record) => {
    const exercise =
      session.exercises[record.exerciseIndex] ??
      session.exercises.find((item) => item.exerciseId === record.exerciseId);
    const isSkipped = record.status === 'skipped';
    const isLastExerciseRow =
      lastRecordKeyByExercise.get(record.exerciseId) ===
      `${record.exerciseIndex}-${record.setIndex}`;
    const loadType = inferLoadType(exercise);
    const isUnknownMachineLoad =
      loadType === 'machine' && record.actualWeightKg === 0;
    const setNote = isSkipped
      ? ['skipped', record.note].filter(Boolean).join(': ')
      : record.note;

    return [
      session.date,
      session.week,
      session.sessionLabel,
      exercise?.name ?? record.exerciseId,
      exercise?.type ?? '',
      formatExportTarget(exercise?.target ?? '', loadType),
      record.setIndex + 1,
      record.status === 'completed' ? 'done' : 'skipped',
      isSkipped || isUnknownMachineLoad
        ? ''
        : formatExportNumber(record.actualWeightKg),
      loadType,
      isSkipped
        ? ''
        : record.actualDurationSeconds !== undefined
          ? `${record.actualDurationSeconds}s`
          : record.actualReps,
      isSkipped ? '' : record.rirLast,
      record.painKnee,
      record.painWrist,
      record.painOther,
      setNote,
      isLastExerciseRow ? (decisions[record.exerciseId] ?? '') : '',
      isLastExerciseRow ? (exercise?.notes ?? '') : '',
      record.supersetId ?? exercise?.supersetId ?? '',
      record.supersetOrder ?? exercise?.supersetOrder ?? '',
      record.roundNumber ?? record.setIndex + 1,
    ];
  });

  return [headers, ...rows]
    .map((row) => row.map((value) => csvEscape(value)).join(','))
    .join('\n');
};

export const buildFullTrainingDataExport = ({
  plan,
  events,
  metadata,
  summaries,
  exportedAt,
  app,
  settings,
  activeWorkout,
}: FullTrainingDataExportInput): FullTrainingDataExport => {
  const eventsBySession = new Map<string, StoredSetEvent[]>();
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );

  events.forEach((event) => {
    const sessionEvents = eventsBySession.get(event.sessionId) ?? [];
    sessionEvents.push(event);
    eventsBySession.set(event.sessionId, sessionEvents);
  });

  const localSessionIds = Array.from(
    new Set([
      ...events.map((event) => event.sessionId),
      ...metadata.map((item) => item.sessionId),
    ]),
  ).sort();
  const summariesBySession = new Map(
    summaries.map((summary) => [summary.sessionId, summary]),
  );

  return {
    schemaName: 'gymapp.full-training-data-export',
    schemaVersion: 1,
    exportedAt,
    app,
    source: {
      platform: 'pwa',
      localStores: ['IndexedDB:setEvents', 'IndexedDB:sessionMetadata'],
    },
    plan,
    settings,
    activeWorkout,
    sessions: localSessionIds.flatMap((sessionId) => {
      const planSession =
        plan.sessions.find((session) => session.sessionId === sessionId) ??
        plan.sessions[0];

      if (!planSession) {
        return [];
      }

      const sessionEvents = [...(eventsBySession.get(sessionId) ?? [])].sort(
        (a, b) => a.performedAt.localeCompare(b.performedAt),
      );
      const metadataItem = metadataBySession.get(sessionId);
      const summary =
        summariesBySession.get(sessionId) ??
        buildFallbackSessionSummary(planSession, sessionEvents, metadataItem);

      return [
        {
          sessionId,
          sessionDate: planSession.date,
          sessionLabel: planSession.sessionLabel,
          planSession,
          summary,
          ...(metadataItem ? { metadata: metadataItem } : {}),
          decisions: metadataItem?.decisions ?? {},
          events: sessionEvents,
        },
      ];
    }),
  };
};

const buildFallbackSessionSummary = (
  session: ExportTrainingSession,
  events: StoredSetEvent[],
  metadata?: StoredSessionMetadata,
): ExportSessionSummary => ({
  sessionId: session.sessionId,
  sessionDate: session.date,
  sessionLabel: session.label,
  estimatedMinutes: session.estimatedMinutes,
  derivedEstimatedMinutes: session.estimatedMinutes,
  attemptedSets: events.length,
  completedSets: events.filter((event) => event.status === 'completed').length,
  totalSets: session.exercises.reduce(
    (total, exercise) => total + exercise.sets.length,
    0,
  ),
  ...(metadata?.schemaVersion ? { schemaVersion: metadata.schemaVersion } : {}),
  ...(metadata?.startedAt ? { startedAt: metadata.startedAt } : {}),
  ...(metadata?.finishedAt ? { finishedAt: metadata.finishedAt } : {}),
  ...(metadata?.exportedAt ? { exportedAt: metadata.exportedAt } : {}),
  firstPerformedAt: events[0]?.performedAt ?? metadata?.startedAt ?? '',
  lastPerformedAt:
    events.at(-1)?.performedAt ??
    metadata?.finishedAt ??
    metadata?.startedAt ??
    '',
});

const slugifyFilePart = (value: string) =>
  value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const csvEscape = (value: string | number) => {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
};

const formatExportNumber = (value: number) => {
  if (Number.isInteger(value)) {
    return String(value);
  }

  return Number(value.toFixed(2)).toString();
};
