import {
  getDurationMinutes,
  type ExerciseProgressInsight,
  type ExerciseProgressionSummary,
  type SessionHistorySummary,
  type TrainingStatsSummary,
  type VolumeSummary,
} from '@/lib/trainingStats';

type StatisticsCsvInput = {
  exportedAt: string;
  appVersion: string;
  stats: TrainingStatsSummary;
  history: SessionHistorySummary[];
  exerciseProgressions: ExerciseProgressionSummary[];
  volumeSummary: VolumeSummary;
};

const schemaName = 'gymapp.statistics-export';
const schemaVersion = 4;

export const getStatisticsCsvFileName = (exportedAt: string) =>
  `${exportedAt.slice(0, 10)}-gymapp-statistics.csv`;

export const buildStatisticsCsv = ({
  exportedAt,
  appVersion,
  stats,
  history,
  exerciseProgressions,
  volumeSummary,
}: StatisticsCsvInput) => {
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
  const insightRows = [
    ...stats.warningInsights,
    ...stats.upInsights,
    ...stats.downInsights,
  ].flatMap((insight) => buildInsightRows({ exportedAt, appVersion, insight }));
  const progressionRows = exerciseProgressions.flatMap((progression) =>
    progression.exposures.map((exposure) => [
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      'exercise_progression',
      exposure.sessionDate,
      '',
      exposure.sessionId,
      exposure.sessionLabel,
      progression.exerciseId,
      progression.exerciseName,
      exposure.target,
      exposure.loadType ?? '',
      exposure.plannedEquipment ?? '',
      exposure.actualEquipment ?? '',
      progression.trainingBlock ?? '',
      progression.movementPattern ?? '',
      progression.primaryMuscles.join('|'),
      'exposure',
      exposure.topLoadKg ?? '',
      exposure.totalDurationSeconds > 0
        ? `${exposure.totalDurationSeconds}s`
        : exposure.totalReps,
      `${exposure.completedSets}/${exposure.plannedSets}`,
      progression.tone,
      progression.recommendation,
      [
        exposure.averageRir !== undefined
          ? `RIR ${formatExportNumber(exposure.averageRir)}`
          : undefined,
        exposure.skippedSets > 0
          ? `${exposure.skippedSets} skipped`
          : undefined,
        exposure.painHits > 0 ? `${exposure.painHits} pain hits` : undefined,
        exposure.decision,
      ]
        .filter(Boolean)
        .join(' · '),
    ]),
  );
  const volumeRows = [
    ...volumeSummary.byMuscle.map((summary) => [
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
      Math.round(summary.totalLoadVolumeKg),
      `${summary.completedSets} sets`,
      '',
      '',
      '',
      `${summary.totalReps} reps · ${summary.totalDurationSeconds}s`,
    ]),
    ...volumeSummary.byExercise.map((summary) => [
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
      summary.trainingBlock ?? '',
      summary.movementPattern ?? '',
      summary.primaryMuscles.join('|'),
      'volume',
      Math.round(summary.totalLoadVolumeKg),
      `${summary.completedSets} sets`,
      '',
      '',
      '',
      `${summary.totalReps} reps · ${summary.totalDurationSeconds}s`,
    ]),
    ...volumeSummary.exposures.map((summary) => [
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      'exercise_volume_exposure',
      summary.sessionDate ?? '',
      summary.weekNumber ?? '',
      summary.sessionId ?? '',
      summary.sessionLabel ?? '',
      summary.exerciseId,
      summary.exerciseName,
      '',
      '',
      '',
      '',
      summary.trainingBlock ?? '',
      summary.movementPattern ?? '',
      summary.primaryMuscles.join('|'),
      'volume',
      Math.round(summary.totalLoadVolumeKg),
      `${summary.completedSets} sets`,
      '',
      '',
      '',
      `${summary.totalReps} reps · ${summary.totalDurationSeconds}s`,
    ]),
  ];

  const rows = [
    headers,
    ...buildSummaryRows({ exportedAt, appVersion, stats }),
    ...buildHistoryRows({ exportedAt, appVersion, history }),
    ...insightRows,
    ...progressionRows,
    ...volumeRows,
  ];
  const invalidRow = rows.find((row) => row.length !== headers.length);

  if (invalidRow) {
    throw new Error(
      `Invalid statistics CSV row length: expected ${headers.length}, got ${invalidRow.length}.`,
    );
  }

  return rows
    .map((row) => row.map((value) => csvEscape(value)).join(','))
    .join('\n');
};

const buildSummaryRows = ({
  exportedAt,
  appVersion,
  stats,
}: {
  exportedAt: string;
  appVersion: string;
  stats: TrainingStatsSummary;
}) =>
  [
    [
      'week_adherence',
      stats.weekCompletedSessions,
      stats.weekTotalSessions,
      `Semana ${stats.weekNumber} · ${stats.weekFocusLabel}`,
    ],
    ['stored_sessions', stats.storedSessions, '', ''],
    ['completed_sessions', stats.completedSessions, '', ''],
    ['average_duration_minutes', stats.averageDurationMinutes ?? '', '', ''],
    ['average_delta_minutes', stats.averageDeltaMinutes ?? '', '', ''],
    ['warning_insights', stats.warningInsights.length, '', ''],
    ['up_insights', stats.upInsights.length, '', ''],
    ['down_insights', stats.downInsights.length, '', ''],
    ['skipped_sets', stats.skippedSets, '', ''],
    ['pain_hits', stats.painHits, '', ''],
  ].map(([metric, value, value2, notes]) => [
    schemaName,
    schemaVersion,
    exportedAt,
    appVersion,
    'summary',
    '',
    stats.weekNumber,
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

const buildHistoryRows = ({
  exportedAt,
  appVersion,
  history,
}: {
  exportedAt: string;
  appVersion: string;
  history: SessionHistorySummary[];
}) =>
  history.map((summary) => {
    const actualMinutes = getDurationMinutes(
      summary.startedAt,
      summary.finishedAt,
    );
    const status = summary.exportedAt
      ? 'exported'
      : summary.finishedAt || summary.attemptedSets >= summary.totalSets
        ? 'complete'
        : 'in_progress';

    return [
      schemaName,
      schemaVersion,
      exportedAt,
      appVersion,
      'session_history',
      summary.sessionDate,
      summary.weekNumber,
      summary.sessionId,
      summary.sessionLabel,
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
      actualMinutes ?? '',
      summary.derivedEstimatedMinutes,
      status,
      '',
      '',
      `${summary.completedSets}/${summary.totalSets} completed · ${summary.attemptedSets} attempted`,
    ];
  });

const buildInsightRows = ({
  exportedAt,
  appVersion,
  insight,
}: {
  exportedAt: string;
  appVersion: string;
  insight: ExerciseProgressInsight;
}) => [
  [
    schemaName,
    schemaVersion,
    exportedAt,
    appVersion,
    'exercise_insight',
    insight.lastDate,
    '',
    '',
    insight.nextSessionLabel ?? '',
    insight.exerciseId,
    insight.exerciseName,
    insight.target,
    insight.lastLoadType ?? '',
    insight.lastPlannedEquipment ?? '',
    insight.lastActualEquipment ?? '',
    '',
    '',
    '',
    'signal',
    insight.lastLoadKg ?? '',
    insight.lastDurationSeconds !== undefined
      ? `${insight.lastDurationSeconds}s`
      : (insight.lastReps ?? ''),
    `${insight.completedSets}/${insight.plannedSets}`,
    insight.tone,
    insight.recommendation,
    [
      insight.lastRir !== undefined
        ? `RIR ${formatExportNumber(insight.lastRir)}`
        : undefined,
      insight.skippedSets > 0 ? `${insight.skippedSets} skipped` : undefined,
      insight.painHits > 0 ? `${insight.painHits} pain hits` : undefined,
      insight.lastDecision,
      insight.nextDate ? `next ${insight.nextDate}` : undefined,
    ]
      .filter(Boolean)
      .join(' · '),
  ],
];

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
