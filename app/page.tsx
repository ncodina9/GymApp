'use client';

import {
  BarChart3,
  Check,
  CalendarDays,
  ChevronRight,
  Database,
  Download,
  ArrowDownRight,
  ArrowLeft,
  ArrowUpRight,
  Equal,
  History,
  House,
  Minus,
  Pause,
  Palette,
  Play,
  Plus,
  RotateCcw,
  Settings,
  Smartphone,
  Trash2,
  X,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { Button } from '@/components/ui/button';
import {
  NativeSelect,
  NativeSelectOption,
} from '@/components/ui/native-select';
import { Progress } from '@/components/ui/progress';
import { Switch } from '@/components/ui/switch';
import planData from '@/data/trainingPlan.json';
import packageData from '@/package.json';
import {
  buildFullTrainingDataExport,
  buildWorkoutCsv,
  getFullJsonExportFileName,
  getWorkoutCsvFileName,
  inferEquipmentLoadType,
  inferLoadType,
  type ExportPhase,
  type LoadType,
} from '@/lib/sessionExport';
import { estimateSessionDurationFromSteps } from '@/lib/sessionDuration';
import {
  buildStatisticsCsv,
  getStatisticsCsvFileName,
} from '@/lib/statisticsExport';
import {
  getRecommendedSession as getRecommendedSelectableSession,
  getWeekSessions,
  resolveSelectedSession,
  toIsoDate,
} from '@/lib/sessionSelection';
import {
  getDurationMinutes,
  getExerciseProgressInsights,
  getExerciseProgressionSummaries,
  getSessionHistorySummaries,
  getTrainingStatsSummary,
  getVolumeSummary,
  isSessionHistoryComplete,
  type ExerciseProgressInsight,
  type ExerciseProgressionSummary,
  type SessionHistorySummary,
  type TrainingStatsSummary,
  type VolumeSummary,
} from '@/lib/trainingStats';
import {
  buildExecutionSteps,
  getCompletedExerciseIds,
  getNextStepLabel,
  getStepIndex,
  getSupersetMembers,
  getSupersetRoundCount,
} from '@/lib/workoutSequence';
import {
  clearAllSessionEvents,
  clearSessionEvents,
  loadAllSessionEvents,
  loadSessionEvents,
  loadSessionMetadata,
  markSessionExported,
  markSessionExerciseDecision,
  markSessionFinished,
  markSessionStarted,
  purgeExportedSessionsOlderThan,
  saveSetEvent,
  type StoredSetEvent,
} from '@/lib/workoutStorage';

type Phase =
  | 'today'
  | 'preview'
  | 'set'
  | 'edit-set'
  | 'feedback'
  | 'rest'
  | 'transition'
  | 'done'
  | 'settings';

type AppearanceTheme = 'system' | 'light' | 'dark';
type WakeLockStatus = 'off' | 'active' | 'unsupported' | 'blocked';
type SettingsSection =
  | 'index'
  | 'appearance'
  | 'training'
  | 'installation'
  | 'upcoming'
  | 'local-data'
  | 'statistics'
  | 'history';
type StatisticsSection =
  | 'summary'
  | 'duration'
  | 'volume'
  | 'review'
  | 'progression'
  | 'export';
type OfflineStatus =
  | 'checking'
  | 'ready'
  | 'update-available'
  | 'missing'
  | 'unsupported'
  | 'insecure'
  | 'error';

type OfflineInfo = {
  swVersion?: string;
  cacheName?: string;
  cachedUrls?: number;
  checkedAt?: string;
};

type TrainingSet = {
  setIndex: number;
  targetReps?: number;
  targetWeightKg: number;
  targetDurationSeconds?: number;
  restSeconds: number;
  type: 'working' | 'timed';
};

type Exercise = {
  exerciseId: string;
  name: string;
  type: string;
  block: string;
  equipment?: string;
  trainingBlock?: string;
  movementPattern?: string;
  primaryMuscles?: string[];
  secondaryMuscles?: string[];
  supersetId?: string;
  supersetOrder?: number;
  phase: string;
  notes: string;
  target: string;
  decisionOptions: string[];
  sets: TrainingSet[];
};

type ExerciseEquipment = NonNullable<Exercise['equipment']>;

type TrainingSession = {
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
  exercises: Exercise[];
};

type TrainingPlan = {
  planId: string;
  startsOn: string;
  endsOn: string;
  durationWeeks: number;
  sessions: TrainingSession[];
};

type WorkoutDraft = {
  phase: Phase;
  selectedSessionId: string;
  exerciseIndex: number;
  setIndex: number;
  editedReps: number;
  editedWeight: number;
  editedDurationSeconds: number;
  weightStep: WeightStep;
  setTimerRemaining: number;
  isSetTimerRunning: boolean;
  setTimerEndsAt?: string;
  restRemaining: number;
  restEndsAt?: string;
  records: StoredSetEvent[];
  decisions: Record<string, string>;
  equipmentByExercise: Record<string, ExerciseEquipment>;
  startedAt?: string;
  finishedAt?: string;
  transitionExerciseIds: string[];
  transitionNextPhase: 'set' | 'rest' | 'done';
  suppressTransitionOnce: boolean;
  editedRir: number;
  painKnee: number;
  painWrist: number;
  painShoulder: number;
  painLowerBack: number;
  painOther: number;
  setNote: string;
};

type SaveStatus = 'idle' | 'saving' | 'saved';

type WakeLockSentinel = EventTarget & {
  released?: boolean;
  release: () => Promise<void>;
};

type WakeLockNavigator = Navigator & {
  wakeLock?: {
    request: (type: 'screen') => Promise<WakeLockSentinel>;
  };
};

type OrientationScreen = Screen & {
  orientation?: ScreenOrientation & {
    lock?: (orientation: OrientationLockType) => Promise<void>;
    unlock?: () => void;
  };
};

type WebMcpTool = {
  name: string;
  title: string;
  description: string;
  inputSchema: object;
  annotations: { readOnlyHint: boolean; untrustedContentHint: boolean };
  execute: (input: unknown) => unknown;
};

type WebMcpDocument = Document & {
  modelContext?: {
    registerTool: (
      tool: WebMcpTool,
      options?: { signal?: AbortSignal },
    ) => void | Promise<void>;
  };
};

type WeightStep = 0.5 | 1 | 1.25 | 2.5 | 5;

type SessionDurationEstimate = ReturnType<
  typeof estimateSessionDurationFromSteps
>;

const trainingPlan = planData as TrainingPlan;
const appVersion = packageData.version;
const storageKey = `gymapp:${trainingPlan.planId}:draft`;
const themeStorageKey = 'gymapp:appearance-theme';
const wakeLockStorageKey = 'gymapp:keep-screen-awake';
const exportedSessionRetentionDays = 30;

const barbellWeightKg = 20;
const multipowerBarWeightKg = 18;
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
const cableLoadsKg = Array.from({ length: 20 }, (_, index) => (index + 1) * 5);

const fallbackSession = trainingPlan.sessions[0];
const appearanceThemes: { value: AppearanceTheme; label: string }[] = [
  { value: 'system', label: 'Sistema' },
  { value: 'light', label: 'Claro' },
  { value: 'dark', label: 'Oscuro' },
];
const actionStyles = {
  back: 'border-[var(--action-back-border)] bg-[var(--action-back)] text-[var(--action-back-foreground)] hover:bg-[var(--action-back-hover)] dark:border-[var(--action-back-border)] dark:bg-[var(--action-back)] dark:text-[var(--action-back-foreground)] dark:hover:bg-[var(--action-back-hover)]',
  skip: 'border-[var(--action-skip-border)] bg-[var(--action-skip)] text-[var(--action-skip-foreground)] hover:bg-[var(--action-skip-hover)] dark:border-[var(--action-skip-border)] dark:bg-[var(--action-skip)] dark:text-[var(--action-skip-foreground)] dark:hover:bg-[var(--action-skip-hover)]',
  reset:
    'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)] hover:bg-[var(--action-reset-hover)]',
  delete:
    'border-[var(--action-delete-border)] bg-[var(--action-delete)] text-[var(--action-delete-foreground)] hover:bg-[var(--action-delete-hover)]',
  minus:
    'border-[var(--action-minus-border)] bg-[var(--action-minus)] text-[var(--action-minus-foreground)] hover:bg-[var(--action-minus-hover)]',
  plus: 'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)] hover:bg-[var(--action-plus-hover)]',
  rest: 'border-[var(--action-rest-border)] bg-[var(--action-rest)] text-[var(--action-rest-foreground)] hover:bg-[var(--action-rest-hover)] dark:border-[var(--action-rest-border)] dark:bg-[var(--action-rest)] dark:text-[var(--action-rest-foreground)] dark:hover:bg-[var(--action-rest-hover)]',
};

const wakeLockStatusLabels: Record<WakeLockStatus, string> = {
  off: 'Desactivada',
  active: 'Activa en este dispositivo',
  unsupported: 'No compatible aquí',
  blocked: 'No concedida por el navegador',
};
const offlineStatusLabels: Record<OfflineStatus, string> = {
  checking: 'Comprobando caché',
  ready: 'Lista para uso sin conexión',
  'update-available': 'Actualización disponible',
  missing: 'Abre la app con conexión',
  unsupported: 'No compatible aquí',
  insecure: 'Necesita HTTPS',
  error: 'No se pudo comprobar',
};

function SkipSetIcon({ className }: { className?: string }) {
  return (
    <svg
      aria-hidden="true"
      className={className}
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle cx="12" cy="16.25" fill="currentColor" r="2.35" />
      <path
        d="M4.8 14.1C6.7 8.5 11 6.35 17.15 8.8"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2.25"
      />
      <path
        d="M15.1 5.8l3.65 3.85-4.95 1.15"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2.25"
      />
    </svg>
  );
}

const canUseServiceWorker = () => {
  if (typeof window === 'undefined') {
    return false;
  }

  return (
    window.location.protocol === 'https:' ||
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1'
  );
};

const requestPortraitOrientation = () => {
  if (typeof window === 'undefined') {
    return;
  }

  const orientation = (window.screen as OrientationScreen).orientation;
  void orientation?.lock?.('portrait').catch(() => undefined);
};

const readServiceWorkerInfo = (worker: ServiceWorker) =>
  new Promise<OfflineInfo>((resolve) => {
    const channel = new MessageChannel();
    const timeout = window.setTimeout(() => resolve({}), 1200);

    channel.port1.onmessage = (event) => {
      window.clearTimeout(timeout);
      const data = event.data as Partial<{
        type: string;
        version: string;
        cacheName: string;
        precacheUrls: string[];
      }>;

      if (data.type !== 'GYMAPP_SW_STATUS') {
        resolve({});
        return;
      }

      resolve({
        swVersion: data.version,
        cacheName: data.cacheName,
        cachedUrls: data.precacheUrls?.length,
      });
    };

    worker.postMessage({ type: 'GYMAPP_GET_SW_STATUS' }, [channel.port2]);
  });

const checkOfflineReadiness = async (): Promise<{
  status: OfflineStatus;
  info: OfflineInfo;
}> => {
  if (
    typeof window === 'undefined' ||
    !('serviceWorker' in navigator) ||
    !('caches' in window)
  ) {
    return { status: 'unsupported', info: {} };
  }

  if (!canUseServiceWorker()) {
    return { status: 'insecure', info: {} };
  }

  try {
    const registration = await navigator.serviceWorker.getRegistration('/');
    const worker =
      registration?.waiting ?? registration?.active ?? registration?.installing;
    const cachedRoot = await caches.match('/');
    const info = worker ? await readServiceWorkerInfo(worker) : {};

    return {
      status: registration?.waiting
        ? 'update-available'
        : registration?.active && cachedRoot
          ? 'ready'
          : 'missing',
      info: { ...info, checkedAt: new Date().toISOString() },
    };
  } catch {
    return { status: 'error', info: { checkedAt: new Date().toISOString() } };
  }
};

const registerServiceWorker = ({
  onStatus,
  onInfo,
}: {
  onStatus: (status: OfflineStatus) => void;
  onInfo: (info: OfflineInfo) => void;
}) => {
  if (
    typeof window === 'undefined' ||
    !('serviceWorker' in navigator) ||
    !canUseServiceWorker()
  ) {
    onStatus(
      typeof window !== 'undefined' && !canUseServiceWorker()
        ? 'insecure'
        : 'unsupported',
    );
    return;
  }

  const register = () => {
    void navigator.serviceWorker
      .register('/sw.js')
      .then((registration) => {
        onStatus(registration.waiting ? 'update-available' : 'ready');
        registration.addEventListener('updatefound', () => {
          const nextWorker = registration.installing;

          nextWorker?.addEventListener('statechange', () => {
            if (nextWorker.state === 'installed') {
              onStatus(
                navigator.serviceWorker.controller
                  ? 'update-available'
                  : 'ready',
              );
            }
          });
        });

        return checkOfflineReadiness();
      })
      .then((result) => {
        onStatus(result.status);
        onInfo(result.info);
      })
      .catch(() => onStatus('error'));
  };

  if (document.readyState === 'complete') {
    register();
    return;
  }

  window.addEventListener('load', register, { once: true });
};

const isAppearanceTheme = (value: unknown): value is AppearanceTheme =>
  value === 'system' || value === 'light' || value === 'dark';

const loadAppearanceTheme = (): AppearanceTheme => {
  if (typeof window === 'undefined') {
    return 'system';
  }

  const stored = window.localStorage.getItem(themeStorageKey);
  return isAppearanceTheme(stored) ? stored : 'system';
};

const loadKeepScreenAwake = () => {
  if (typeof window === 'undefined') {
    return false;
  }

  return window.localStorage.getItem(wakeLockStorageKey) === 'true';
};

const getRecommendedSession = () =>
  getRecommendedSelectableSession(trainingPlan.sessions) ?? fallbackSession;

const makeDraft = (session = getRecommendedSession()): WorkoutDraft => ({
  phase: 'today',
  selectedSessionId: session.sessionId,
  exerciseIndex: 0,
  setIndex: 0,
  editedReps: session.exercises[0].sets[0].targetReps ?? 0,
  editedWeight: session.exercises[0].sets[0].targetWeightKg,
  editedDurationSeconds:
    session.exercises[0].sets[0].targetDurationSeconds ?? 0,
  weightStep: 1,
  setTimerRemaining: session.exercises[0].sets[0].targetDurationSeconds ?? 0,
  isSetTimerRunning: false,
  restRemaining: 0,
  records: [],
  decisions: {},
  equipmentByExercise: {},
  transitionExerciseIds: [],
  transitionNextPhase: 'set',
  suppressTransitionOnce: false,
  editedRir: 2,
  painKnee: 0,
  painWrist: 0,
  painShoulder: 0,
  painLowerBack: 0,
  painOther: 0,
  setNote: 'OK',
});

const isStoredSetEvent = (value: unknown): value is StoredSetEvent =>
  typeof value === 'object' &&
  value !== null &&
  'id' in value &&
  'actualReps' in value &&
  'actualWeightKg' in value &&
  'exerciseId' in value;

const normalizeDraft = (
  draft: Partial<WorkoutDraft> | null,
): WorkoutDraft | null => {
  if (!draft?.selectedSessionId) {
    return null;
  }

  const session =
    resolveSelectedSession(trainingPlan.sessions, draft.selectedSessionId) ??
    fallbackSession;

  return {
    ...makeDraft(session),
    ...draft,
    records: Array.isArray(draft.records)
      ? draft.records.filter(isStoredSetEvent)
      : [],
    decisions: draft.decisions ?? {},
    equipmentByExercise:
      draft.equipmentByExercise && typeof draft.equipmentByExercise === 'object'
        ? (draft.equipmentByExercise as Record<string, ExerciseEquipment>)
        : {},
    ...(draft.startedAt ? { startedAt: draft.startedAt } : {}),
    ...(draft.finishedAt ? { finishedAt: draft.finishedAt } : {}),
    transitionExerciseIds: draft.transitionExerciseIds ?? [],
    transitionNextPhase: draft.transitionNextPhase ?? 'set',
    suppressTransitionOnce: draft.suppressTransitionOnce ?? false,
    editedRir: draft.editedRir ?? 2,
    editedDurationSeconds: draft.editedDurationSeconds ?? 0,
    weightStep: isWeightStep(draft.weightStep) ? draft.weightStep : 1,
    setTimerRemaining: draft.setTimerRemaining ?? 0,
    ...(draft.setTimerEndsAt ? { setTimerEndsAt: draft.setTimerEndsAt } : {}),
    isSetTimerRunning: draft.isSetTimerRunning ?? false,
    ...(draft.restEndsAt ? { restEndsAt: draft.restEndsAt } : {}),
    painKnee: draft.painKnee ?? 0,
    painWrist: draft.painWrist ?? 0,
    painShoulder: draft.painShoulder ?? 0,
    painLowerBack: draft.painLowerBack ?? 0,
    painOther: draft.painOther ?? 0,
    setNote: draft.setNote || 'OK',
  };
};

const loadDraft = (): WorkoutDraft | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(storageKey);
    return raw
      ? normalizeDraft(JSON.parse(raw) as Partial<WorkoutDraft>)
      : null;
  } catch {
    return null;
  }
};

const formatDate = (date: string) =>
  new Intl.DateTimeFormat('es-ES', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${date}T12:00:00`));

const formatChartDate = (date: string) => {
  const [, month, day] = date.split('-');
  return month && day ? `${day}/${month}` : date;
};

const formatWeight = (weight: number) => `${formatDecimal(weight)} kg`;

const formatClock = (totalSeconds: number) => {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = String(safeSeconds % 60).padStart(2, '0');

  return `${minutes}:${seconds}`;
};

const getTimerEndsAt = (seconds: number) =>
  new Date(Date.now() + Math.max(0, seconds) * 1000).toISOString();

const formatDurationMinutes = (minutes: number) => {
  if (minutes < 60) {
    return `${minutes} min`;
  }

  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;

  return remainder > 0 ? `${hours} h ${remainder} min` : `${hours} h`;
};

const getDurationDeltaLabel = (
  actualMinutes: number,
  estimatedMinutes: number,
) => {
  const delta = actualMinutes - estimatedMinutes;

  if (Math.abs(delta) <= 5) {
    return 'En tiempo';
  }

  return delta > 0
    ? `+${delta} min sobre lo previsto`
    : `${Math.abs(delta)} min más rápido`;
};

const formatSignedMinutes = (minutes: number) => {
  if (minutes === 0) {
    return '0 min';
  }

  return minutes > 0 ? `+${minutes} min` : `-${Math.abs(minutes)} min`;
};

const estimateSessionDuration = (session: TrainingSession) =>
  estimateSessionDurationFromSteps(session, buildExecutionSteps(session));

const getDurationEstimateStatus = (estimate: SessionDurationEstimate) => {
  const delta = estimate.totalMinutes - estimate.targetMinutes;

  if (delta <= 5) {
    return 'Dentro del objetivo';
  }

  if (delta <= 15) {
    return `Ajustada: +${delta} min`;
  }

  return `Revisar planning: +${delta} min`;
};

const createEventId = () => {
  if (
    typeof crypto !== 'undefined' &&
    typeof crypto.randomUUID === 'function'
  ) {
    return crypto.randomUUID();
  }

  if (
    typeof crypto !== 'undefined' &&
    typeof crypto.getRandomValues === 'function'
  ) {
    const bytes = crypto.getRandomValues(new Uint32Array(4));
    return Array.from(bytes, (part) => part.toString(16).padStart(8, '0')).join(
      '-',
    );
  }

  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
};

const shareOrDownloadFile = async (file: File, fileName: string) => {
  if (navigator.canShare?.({ files: [file] })) {
    await navigator.share({
      files: [file],
      title: fileName,
    });
    return;
  }

  const url = URL.createObjectURL(file);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  link.click();
  URL.revokeObjectURL(url);
};

const getTodayIso = () => toIsoDate(new Date());

const getSessionById = (sessionId: string | undefined) =>
  resolveSelectedSession(trainingPlan.sessions, sessionId) ?? fallbackSession;

const getDecisionFallbacks = (
  records: StoredSetEvent[],
  currentDecisions: Record<string, string>,
) => {
  const decisions: Record<string, string> = {};

  records.forEach((record) => {
    if (currentDecisions[record.exerciseId]) {
      decisions[record.exerciseId] = currentDecisions[record.exerciseId];
    }
  });

  return decisions;
};

const formatDecimal = (value: number) => {
  if (Number.isInteger(value)) {
    return String(value);
  }

  return Number(value.toFixed(2)).toString();
};

const formatCsvNumber = (value: number) => formatDecimal(value);

const formatPreviewLoad = (weight: number, loadType: LoadType) => {
  const compactWeight = formatCsvNumber(weight);

  if (loadType === 'external') {
    return weight > 0 ? `+${compactWeight}` : '0';
  }

  if (loadType === 'per_dumbbell') {
    return compactWeight;
  }

  if (loadType === 'machine' && weight === 0) {
    return '-';
  }

  return compactWeight;
};

const roundEquipmentLoad = (value: number) => Math.round(value * 100) / 100;

const buildSidePlateLoads = () => {
  const pairs = plateInventoryKg.map((plate) => ({
    weight: plate.weight,
    count: Math.floor(plate.count / 2),
  }));
  const loads = new Set([0]);

  pairs.forEach((plate) => {
    const existing = Array.from(loads);

    existing.forEach((load) => {
      Array.from({ length: plate.count }).forEach((_, index) => {
        loads.add(roundEquipmentLoad(load + plate.weight * (index + 1)));
      });
    });
  });

  return Array.from(loads);
};

const buildPlateCombinationLoads = () => {
  const loads = new Set([0]);

  plateInventoryKg.forEach((plate) => {
    const existing = Array.from(loads);

    existing.forEach((load) => {
      Array.from({ length: plate.count }).forEach((_, index) => {
        loads.add(roundEquipmentLoad(load + plate.weight * (index + 1)));
      });
    });
  });

  return Array.from(loads)
    .filter((load) => load > 0)
    .sort((a, b) => a - b);
};

const buildSymmetricLoadedBarLoads = (barWeightKg: number) =>
  Array.from(
    new Set(
      buildSidePlateLoads().map(
        (sideLoad) => Math.round((barWeightKg + sideLoad * 2) * 2) / 2,
      ),
    ),
  ).sort((a, b) => a - b);

const barbellLoadsKg = buildSymmetricLoadedBarLoads(barbellWeightKg);
const multipowerLoadsKg = buildSymmetricLoadedBarLoads(multipowerBarWeightKg);
const externalLoadsKg = buildPlateCombinationLoads();

const equipmentLabels: Record<ExerciseEquipment, string> = {
  barbell: 'Barra',
  multipower: 'Multipower',
  dumbbell: 'Mancuernas',
  cable: 'Polea',
  plate_loaded_machine: 'Discos',
  external: 'Lastre',
  bodyweight: 'Peso corporal',
};

const formatEquipmentLabel = (equipment?: string) =>
  equipment && equipment in equipmentLabels
    ? equipmentLabels[equipment as ExerciseEquipment]
    : undefined;

const exerciseEquipmentVariants: Record<string, ExerciseEquipment[]> = {
  'press-banca-barra': ['barbell', 'multipower', 'dumbbell'],
  'press-banca-inclinado': ['barbell', 'multipower', 'dumbbell'],
  'press-militar-sentado': ['barbell', 'multipower', 'dumbbell'],
  'press-militar-sentado-velocidad': ['barbell', 'multipower', 'dumbbell'],
  'remo-inclinado-barra': ['barbell', 'multipower'],
  'remo-barra-multipower': ['multipower', 'barbell'],
  'press-cerrado-multipower': ['multipower', 'barbell'],
};

const getExerciseEquipment = (exercise: Exercise): ExerciseEquipment =>
  (exercise.equipment ?? 'barbell') as ExerciseEquipment;

const getExerciseEquipmentOptions = (exercise: Exercise) => {
  const plannedEquipment = getExerciseEquipment(exercise);
  const variants = exerciseEquipmentVariants[exercise.exerciseId] ?? [
    plannedEquipment,
  ];
  const options = variants.includes(plannedEquipment)
    ? variants
    : [plannedEquipment, ...variants];

  return Array.from(new Set(options));
};

const isWeightStep = (value: unknown): value is WeightStep =>
  value === 0.5 ||
  value === 1 ||
  value === 1.25 ||
  value === 2.5 ||
  value === 5;

const getWeightStepOptions = (
  loadType: LoadType,
  equipment?: Exercise['equipment'],
): WeightStep[] => {
  if (
    loadType === 'total' ||
    loadType === 'external' ||
    equipment === 'plate_loaded_machine'
  ) {
    return [1.25, 2.5, 5];
  }

  if (loadType === 'machine') {
    return [5];
  }

  if (loadType === 'bodyweight') {
    return [1];
  }

  return [1, 0.5];
};

const normalizeWeightStep = (
  value: WeightStep,
  loadType: LoadType,
  equipment?: Exercise['equipment'],
): WeightStep => {
  const options = getWeightStepOptions(loadType, equipment);
  return options.includes(value) ? value : options[0];
};

const getAvailableLoadsForType = (
  loadType: LoadType,
  equipment?: Exercise['equipment'],
) => {
  if (loadType === 'per_dumbbell') {
    return dumbbellLoadsKg;
  }

  if (equipment === 'plate_loaded_machine') {
    return externalLoadsKg;
  }

  if (loadType === 'machine') {
    return cableLoadsKg;
  }

  if (loadType === 'total') {
    if (equipment === 'multipower') {
      return multipowerLoadsKg;
    }

    return barbellLoadsKg;
  }

  if (loadType === 'external') {
    return externalLoadsKg;
  }

  return [0];
};

const getWeightDelta = (loadType: LoadType, step: WeightStep) =>
  loadType === 'total' ? step * 2 : step;

const getAdjustedWeight = (
  loadType: LoadType,
  equipment: Exercise['equipment'] | undefined,
  currentWeight: number,
  step: WeightStep,
  direction: -1 | 1,
) => {
  if (loadType === 'bodyweight') {
    return 0;
  }

  const normalizedStep = normalizeWeightStep(step, loadType, equipment);
  const target =
    currentWeight + getWeightDelta(loadType, normalizedStep) * direction;
  const loads = getAvailableLoadsForType(loadType, equipment);

  if (direction > 0) {
    return (
      loads.find((load) => load >= target) ?? loads.at(-1) ?? currentWeight
    );
  }

  return (
    [...loads].reverse().find((load) => load <= Math.max(0, target)) ??
    (loadType === 'machine' || loadType === 'per_dumbbell' ? 0 : currentWeight)
  );
};

const getNearestAvailableLoad = (
  loadType: LoadType,
  equipment: ExerciseEquipment,
  targetWeight: number,
) => {
  const loads = getAvailableLoadsForType(loadType, equipment);

  return loads.reduce(
    (nearest, load) =>
      Math.abs(load - targetWeight) < Math.abs(nearest - targetWeight)
        ? load
        : nearest,
    loads[0] ?? 0,
  );
};

const convertWeightForEquipment = (
  currentWeight: number,
  currentEquipment: ExerciseEquipment,
  nextEquipment: ExerciseEquipment,
) => {
  const currentLoadType =
    inferEquipmentLoadType(currentEquipment) ?? 'bodyweight';
  const nextLoadType = inferEquipmentLoadType(nextEquipment) ?? 'bodyweight';

  if (nextLoadType === 'bodyweight') {
    return 0;
  }

  let estimatedWeight = currentWeight;

  if (currentLoadType === 'total' && nextLoadType === 'per_dumbbell') {
    estimatedWeight = currentWeight / 2;
  } else if (currentLoadType === 'per_dumbbell' && nextLoadType === 'total') {
    estimatedWeight = currentWeight * 2;
  }

  return getNearestAvailableLoad(nextLoadType, nextEquipment, estimatedWeight);
};

const getPreviewLoadLabel = (
  loadType: LoadType,
  equipment?: Exercise['equipment'],
) => {
  if (equipment === 'plate_loaded_machine') {
    return 'discos';
  }

  if (loadType === 'external') {
    return 'lastre';
  }

  if (loadType === 'per_dumbbell') {
    return 'kg/manc.';
  }

  if (loadType === 'machine') {
    return 'máquina';
  }

  return 'kg';
};

const getExerciseDecisionOptions = (exercise: Exercise) => {
  const isTimed = exercise.sets.some(
    (set) => set.type === 'timed' || set.targetDurationSeconds !== undefined,
  );

  if (isTimed) {
    return [
      'Mantener tiempo',
      'Subir tiempo',
      'Bajar tiempo',
      'Mejorar posición',
      'Marcar molestia',
    ];
  }

  const loadType = inferLoadType(exercise);
  const hasPlannedWeight = exercise.sets.some((set) => set.targetWeightKg > 0);
  const canChangeWeight =
    hasPlannedWeight &&
    loadType !== 'bodyweight' &&
    (loadType !== 'machine' || exercise.equipment === 'plate_loaded_machine');

  if (!canChangeWeight) {
    return ['Mantener', 'Subir reps', 'Bajar reps', 'Marcar molestia'];
  }

  return [
    'Mantener',
    'Subir peso',
    'Bajar peso',
    'Subir reps',
    'Bajar reps',
    'Marcar molestia',
  ];
};

const getDefaultExerciseDecision = (exercise: Exercise) =>
  getExerciseDecisionOptions(exercise)[0] ?? 'Mantener';

const getDecisionVisual = (option: string, selected: boolean) => {
  const lower = option.toLowerCase();
  const baseIconClassName = selected
    ? 'text-current'
    : lower.includes('bajar') || lower.includes('molestia')
      ? 'text-red-600'
      : lower.includes('subir')
        ? 'text-emerald-600'
        : 'text-blue-600';

  if (lower.includes('subir')) {
    return {
      icon: <ArrowUpRight className={`size-5 ${baseIconClassName}`} />,
      className: selected
        ? 'border-emerald-600 bg-emerald-600 text-white'
        : 'border-emerald-200 bg-emerald-50 text-emerald-950',
    };
  }

  if (lower.includes('bajar')) {
    return {
      icon: <ArrowDownRight className={`size-5 ${baseIconClassName}`} />,
      className: selected
        ? 'border-red-600 bg-red-600 text-white'
        : 'border-red-200 bg-red-50 text-red-950',
    };
  }

  if (lower.includes('molestia')) {
    return {
      icon: <X className={`size-5 ${baseIconClassName}`} />,
      className: selected
        ? 'border-red-600 bg-red-600 text-white'
        : 'border-red-200 bg-red-50 text-red-950',
    };
  }

  return {
    icon: <Equal className={`size-5 ${baseIconClassName}`} />,
    className: selected
      ? 'border-blue-600 bg-blue-600 text-white'
      : 'border-blue-200 bg-blue-50 text-blue-950',
  };
};

const getExercisePreviewMetrics = (exercise: Exercise) => {
  const loadType = inferLoadType(exercise);
  const loads = Array.from(
    new Set(
      exercise.sets.map((set) =>
        formatPreviewLoad(set.targetWeightKg, loadType),
      ),
    ),
  );

  if (exercise.sets.every((set) => set.type === 'timed')) {
    const durations = Array.from(
      new Set(
        exercise.sets.map((set) => formatClock(set.targetDurationSeconds ?? 0)),
      ),
    );

    return {
      sets: String(exercise.sets.length),
      work: durations.join('/'),
      workLabel: 'tiempo',
      load: loads.join('/'),
      loadLabel: getPreviewLoadLabel(loadType, exercise.equipment),
    };
  }

  const reps = Array.from(
    new Set(exercise.sets.map((set) => set.targetReps ?? 0)),
  );

  return {
    sets: String(exercise.sets.length),
    work: reps.join('/'),
    workLabel: 'reps',
    load: loads.join('/'),
    loadLabel: getPreviewLoadLabel(loadType, exercise.equipment),
  };
};

type NextSetPreview = {
  exerciseName: string;
  series: string;
  work: string;
  workLabel: string;
  load: string;
  loadLabel: string;
};

const getNextSetPreview = (
  session: TrainingSession,
  step: ReturnType<typeof buildExecutionSteps>[number] | undefined,
): NextSetPreview | undefined => {
  if (!step) {
    return undefined;
  }

  const exercise = session.exercises[step.exerciseIndex];
  const set = exercise?.sets[step.setIndex];

  if (!exercise || !set) {
    return undefined;
  }

  const loadType = inferLoadType(exercise);

  if (set.type === 'timed') {
    return {
      exerciseName: exercise.name,
      series: `${step.setIndex + 1}/${exercise.sets.length}`,
      work: formatClock(set.targetDurationSeconds ?? 0),
      workLabel: 'tiempo',
      load: formatPreviewLoad(set.targetWeightKg, loadType),
      loadLabel: getPreviewLoadLabel(loadType, exercise.equipment),
    };
  }

  return {
    exerciseName: exercise.name,
    series: `${step.setIndex + 1}/${exercise.sets.length}`,
    work: String(set.targetReps ?? 0),
    workLabel: 'reps',
    load: formatPreviewLoad(set.targetWeightKg, loadType),
    loadLabel: getPreviewLoadLabel(loadType, exercise.equipment),
  };
};

export default function Home() {
  const [draft, setDraft] = useState<WorkoutDraft>(() => makeDraft());
  const [hasLoadedDraft, setHasLoadedDraft] = useState(false);
  const [appearanceTheme, setAppearanceTheme] =
    useState<AppearanceTheme>('system');
  const [keepScreenAwake, setKeepScreenAwake] = useState(false);
  const [wakeLockStatus, setWakeLockStatus] = useState<WakeLockStatus>('off');
  const [offlineStatus, setOfflineStatus] = useState<OfflineStatus>('checking');
  const [offlineInfo, setOfflineInfo] = useState<OfflineInfo>({});
  const [settingsReturnPhase, setSettingsReturnPhase] =
    useState<Phase>('today');
  const [settingsSection, setSettingsSection] =
    useState<SettingsSection>('index');
  const [sessionHistory, setSessionHistory] = useState<SessionHistorySummary[]>(
    [],
  );
  const [exerciseInsights, setExerciseInsights] = useState<
    ExerciseProgressInsight[]
  >([]);
  const [exerciseProgressions, setExerciseProgressions] = useState<
    ExerciseProgressionSummary[]
  >([]);
  const [volumeSummary, setVolumeSummary] = useState<VolumeSummary>({
    byMuscle: [],
    byExercise: [],
  });
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [isRegisteringSet, setIsRegisteringSet] = useState(false);
  const [saveStatus, setSaveStatus] = useState<SaveStatus>('idle');
  const isRegisteringSetRef = useRef(false);
  const wakeLockRef = useRef<WakeLockSentinel | null>(null);
  const keepScreenAwakeRef = useRef(false);
  const selectedSession = getSessionById(draft.selectedSessionId);
  const selectedSessionDurationEstimate = useMemo(
    () => estimateSessionDuration(selectedSession),
    [selectedSession],
  );
  const executionSteps = useMemo(
    () => buildExecutionSteps(selectedSession),
    [selectedSession],
  );
  const currentExercise = selectedSession.exercises[draft.exerciseIndex];
  const currentSet = currentExercise?.sets[draft.setIndex];
  const currentEquipment = currentExercise
    ? (draft.equipmentByExercise[currentExercise.exerciseId] ??
      getExerciseEquipment(currentExercise))
    : undefined;
  const currentLoadType =
    currentEquipment !== undefined
      ? (inferEquipmentLoadType(currentEquipment) ??
        inferLoadType(currentExercise))
      : inferLoadType(currentExercise);
  const currentStepIndex = getStepIndex(
    executionSteps,
    draft.exerciseIndex,
    draft.setIndex,
  );
  const currentStep =
    currentStepIndex >= 0 ? executionSteps[currentStepIndex] : undefined;
  const nextStep =
    currentStepIndex >= 0 ? executionSteps[currentStepIndex + 1] : undefined;
  const supersetMembers =
    currentStep?.supersetId !== undefined
      ? getSupersetMembers(selectedSession, currentStep.supersetId)
      : [];
  const supersetRoundCount =
    currentStep?.supersetId !== undefined
      ? getSupersetRoundCount(selectedSession, currentStep.supersetId)
      : undefined;
  const nextLinkedStep =
    currentStep?.supersetId !== undefined &&
    nextStep?.supersetId === currentStep.supersetId &&
    nextStep.roundNumber === currentStep.roundNumber
      ? nextStep
      : undefined;
  const nextLinkedExercise =
    nextLinkedStep !== undefined
      ? selectedSession.exercises[nextLinkedStep.exerciseIndex]
      : undefined;
  const totalSets = executionSteps.length;
  const completedSets = draft.records.filter(
    (record) => record.status === 'completed',
  ).length;
  const attemptedSets = draft.records.length;
  const workoutDurationMinutes = getDurationMinutes(
    draft.startedAt,
    draft.finishedAt,
  );
  const progressValue = Math.round((attemptedSets / totalSets) * 100);
  const hasStarted =
    draft.records.length > 0 ||
    draft.exerciseIndex > 0 ||
    draft.setIndex > 0 ||
    draft.phase === 'edit-set' ||
    draft.phase === 'feedback' ||
    draft.phase === 'rest' ||
    draft.phase === 'transition';
  const completedSessionIds = useMemo(
    () =>
      new Set(
        sessionHistory
          .filter((summary) => isSessionHistoryComplete(summary))
          .map((summary) => summary.sessionId),
      ),
    [sessionHistory],
  );

  const weekSessions = useMemo(
    () => getWeekSessions(trainingPlan.sessions, selectedSession),
    [selectedSession],
  );
  const upcomingSessions = useMemo(() => {
    const todayIso = getTodayIso();

    return trainingPlan.sessions
      .filter((session) => session.date >= todayIso)
      .sort((a, b) => a.date.localeCompare(b.date));
  }, []);
  const trainingStats = useMemo(
    () =>
      getTrainingStatsSummary({
        sessions: trainingPlan.sessions,
        recommendedSession: getRecommendedSession(),
        history: sessionHistory,
        insights: exerciseInsights,
      }),
    [sessionHistory, exerciseInsights],
  );

  const refreshSessionHistory = useCallback(async () => {
    setIsLoadingHistory(true);

    try {
      await purgeExportedSessionsOlderThan(exportedSessionRetentionDays);
      const events = await loadAllSessionEvents();
      const metadata = await loadSessionMetadata();
      const todayIso = getTodayIso();
      const nextExerciseInsights = getExerciseProgressInsights(
        trainingPlan.sessions,
        events,
        metadata,
        todayIso,
      );

      setSessionHistory(
        getSessionHistorySummaries(trainingPlan.sessions, events, metadata),
      );
      setExerciseInsights(nextExerciseInsights);
      setExerciseProgressions(
        getExerciseProgressionSummaries(
          trainingPlan.sessions,
          events,
          metadata,
          nextExerciseInsights,
          todayIso,
        ),
      );
      setVolumeSummary(getVolumeSummary(trainingPlan.sessions, events));
    } catch {
      setSessionHistory([]);
      setExerciseInsights([]);
      setExerciseProgressions([]);
      setVolumeSummary({ byMuscle: [], byExercise: [] });
    } finally {
      setIsLoadingHistory(false);
    }
  }, []);

  useEffect(() => {
    keepScreenAwakeRef.current = keepScreenAwake;
  }, [keepScreenAwake]);

  useEffect(() => {
    const preventGesture = (event: Event) => event.preventDefault();
    const preventMultitouch = (event: TouchEvent) => {
      if (event.touches.length > 1) {
        event.preventDefault();
      }
    };

    document.addEventListener('gesturestart', preventGesture);
    document.addEventListener('gesturechange', preventGesture);
    document.addEventListener('gestureend', preventGesture);
    document.addEventListener('touchmove', preventMultitouch, {
      passive: false,
    });

    return () => {
      document.removeEventListener('gesturestart', preventGesture);
      document.removeEventListener('gesturechange', preventGesture);
      document.removeEventListener('gestureend', preventGesture);
      document.removeEventListener('touchmove', preventMultitouch);
    };
  }, []);

  const releaseScreenWakeLock = useCallback(() => {
    const lock = wakeLockRef.current;
    wakeLockRef.current = null;
    setWakeLockStatus('off');

    if (lock && lock.released !== true) {
      void lock.release().catch(() => undefined);
    }
  }, []);

  const requestScreenWakeLock = useCallback(async () => {
    if (typeof navigator === 'undefined') {
      setWakeLockStatus('unsupported');
      return false;
    }

    const wakeLock = (navigator as WakeLockNavigator).wakeLock;

    if (!wakeLock) {
      setWakeLockStatus('unsupported');
      return false;
    }

    if (document.visibilityState !== 'visible') {
      setWakeLockStatus('blocked');
      return false;
    }

    try {
      const lock = await wakeLock.request('screen');
      wakeLockRef.current = lock;
      setWakeLockStatus('active');
      lock.addEventListener(
        'release',
        () => {
          if (wakeLockRef.current === lock) {
            wakeLockRef.current = null;
            setWakeLockStatus(keepScreenAwakeRef.current ? 'blocked' : 'off');
          }
        },
        { once: true },
      );
      return true;
    } catch {
      wakeLockRef.current = null;
      setWakeLockStatus('blocked');
      return false;
    }
  }, []);

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      setDraft(loadDraft() ?? makeDraft());
      setAppearanceTheme(loadAppearanceTheme());
      setKeepScreenAwake(loadKeepScreenAwake());
      setHasLoadedDraft(true);
    }, 0);

    return () => window.clearTimeout(timeout);
  }, []);

  useEffect(() => {
    if (!hasLoadedDraft) {
      return;
    }

    queueMicrotask(() => void refreshSessionHistory());
  }, [hasLoadedDraft, refreshSessionHistory]);

  useEffect(() => {
    if (!hasLoadedDraft || draft.phase !== 'today' || hasStarted) {
      return;
    }

    const recommendedSession = getRecommendedSession();

    if (draft.selectedSessionId !== recommendedSession.sessionId) {
      return;
    }

    const recommendedWeekSessions = getWeekSessions(
      trainingPlan.sessions,
      recommendedSession,
    );
    const isRecommendedWeekComplete = recommendedWeekSessions.every((session) =>
      completedSessionIds.has(session.sessionId),
    );

    if (!isRecommendedWeekComplete) {
      return;
    }

    const nextPendingSession = trainingPlan.sessions.find(
      (session) =>
        session.week > recommendedSession.week &&
        !completedSessionIds.has(session.sessionId),
    );

    if (nextPendingSession) {
      queueMicrotask(() => setDraft(makeDraft(nextPendingSession)));
    }
  }, [
    completedSessionIds,
    draft.phase,
    draft.selectedSessionId,
    hasLoadedDraft,
    hasStarted,
  ]);

  useEffect(() => {
    registerServiceWorker({
      onStatus: setOfflineStatus,
      onInfo: setOfflineInfo,
    });
  }, []);

  useEffect(() => {
    requestPortraitOrientation();
  }, []);

  const checkOffline = useCallback(() => {
    setOfflineStatus('checking');
    void checkOfflineReadiness().then((result) => {
      setOfflineStatus(result.status);
      setOfflineInfo(result.info);
    });
  }, []);

  const updateOfflineVersion = useCallback(() => {
    if (!('serviceWorker' in navigator)) {
      return;
    }

    void navigator.serviceWorker.getRegistration('/').then((registration) => {
      if (!registration?.waiting) {
        checkOffline();
        return;
      }

      registration.waiting.postMessage({ type: 'GYMAPP_SKIP_WAITING' });
      window.setTimeout(() => window.location.reload(), 500);
    });
  }, [checkOffline]);

  useEffect(() => {
    const applyTheme = () => {
      const systemPrefersDark = window.matchMedia(
        '(prefers-color-scheme: dark)',
      ).matches;
      const shouldUseDark =
        appearanceTheme === 'dark' ||
        (appearanceTheme === 'system' && systemPrefersDark);

      document.documentElement.classList.toggle('dark', shouldUseDark);
      document.documentElement.dataset.appearanceTheme = appearanceTheme;
      if (hasLoadedDraft) {
        window.localStorage.setItem(themeStorageKey, appearanceTheme);
      }
    };

    applyTheme();

    if (appearanceTheme !== 'system') {
      return;
    }

    const media = window.matchMedia('(prefers-color-scheme: dark)');
    media.addEventListener('change', applyTheme);

    return () => media.removeEventListener('change', applyTheme);
  }, [appearanceTheme, hasLoadedDraft]);

  useEffect(() => {
    if (!hasLoadedDraft) {
      return;
    }

    window.localStorage.setItem(storageKey, JSON.stringify(draft));
  }, [draft, hasLoadedDraft]);

  useEffect(() => {
    if (draft.phase === 'settings') {
      queueMicrotask(() => void refreshSessionHistory());
    }
  }, [draft.phase, refreshSessionHistory]);

  useEffect(() => {
    if (!hasLoadedDraft) {
      return;
    }

    window.localStorage.setItem(wakeLockStorageKey, String(keepScreenAwake));
  }, [hasLoadedDraft, keepScreenAwake]);

  useEffect(() => {
    if (!keepScreenAwake) {
      queueMicrotask(releaseScreenWakeLock);
      return;
    }

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        void requestScreenWakeLock();
      }
    };
    const handleUserInteraction = () => {
      if (!wakeLockRef.current) {
        void requestScreenWakeLock();
      }
    };

    queueMicrotask(() => void requestScreenWakeLock());
    document.addEventListener('visibilitychange', handleVisibilityChange);
    document.addEventListener('pointerdown', handleUserInteraction, {
      passive: true,
    });

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      document.removeEventListener('pointerdown', handleUserInteraction);
    };
  }, [keepScreenAwake, releaseScreenWakeLock, requestScreenWakeLock]);

  useEffect(() => {
    let cancelled = false;

    void loadSessionEvents(selectedSession.sessionId)
      .then((events) => {
        if (cancelled || events.length === 0) {
          return;
        }

        setDraft((current) =>
          current.selectedSessionId === selectedSession.sessionId
            ? { ...current, records: events }
            : current,
        );
      })
      .catch(() => undefined);

    return () => {
      cancelled = true;
    };
  }, [selectedSession.sessionId]);

  useEffect(() => {
    if (draft.phase !== 'rest' || draft.restRemaining <= 0) {
      return;
    }

    const updateRemaining = () => {
      setDraft((current) => {
        const restEndsAt =
          current.restEndsAt ?? getTimerEndsAt(current.restRemaining);
        const nextRemaining = Math.max(
          0,
          Math.ceil((new Date(restEndsAt).getTime() - Date.now()) / 1000),
        );

        return {
          ...current,
          restRemaining: nextRemaining,
          restEndsAt: nextRemaining > 0 ? restEndsAt : undefined,
        };
      });
    };

    updateRemaining();
    const timer = window.setInterval(updateRemaining, 1000);
    window.addEventListener('focus', updateRemaining);
    document.addEventListener('visibilitychange', updateRemaining);

    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', updateRemaining);
      document.removeEventListener('visibilitychange', updateRemaining);
    };
  }, [draft.phase, draft.restRemaining]);

  useEffect(() => {
    if (
      draft.phase !== 'set' ||
      !draft.isSetTimerRunning ||
      draft.setTimerRemaining <= 0
    ) {
      return;
    }

    const updateRemaining = () => {
      setDraft((current) => {
        const setTimerEndsAt =
          current.setTimerEndsAt ?? getTimerEndsAt(current.setTimerRemaining);
        const nextRemaining = Math.max(
          0,
          Math.ceil((new Date(setTimerEndsAt).getTime() - Date.now()) / 1000),
        );

        return {
          ...current,
          setTimerRemaining: nextRemaining,
          isSetTimerRunning: nextRemaining > 0,
          setTimerEndsAt: nextRemaining > 0 ? setTimerEndsAt : undefined,
        };
      });
    };

    updateRemaining();
    const timer = window.setInterval(updateRemaining, 1000);
    window.addEventListener('focus', updateRemaining);
    document.addEventListener('visibilitychange', updateRemaining);

    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', updateRemaining);
      document.removeEventListener('visibilitychange', updateRemaining);
    };
  }, [draft.phase, draft.isSetTimerRunning, draft.setTimerRemaining]);

  const patchDraft = useCallback((patch: Partial<WorkoutDraft>) => {
    setDraft((current) => ({ ...current, ...patch }));
  }, []);

  const resetWorkoutPosition = useCallback(
    (sessionId = draft.selectedSessionId) => {
      const nextSession = getSessionById(sessionId);
      const clearEvents = clearSessionEvents(nextSession.sessionId).catch(
        () => undefined,
      );
      setDraft(makeDraft(nextSession));

      return clearEvents;
    },
    [draft.selectedSessionId],
  );

  const applyPlannedTargets = useCallback(
    (nextExerciseIndex: number, nextSetIndex: number) => {
      const nextExercise = selectedSession.exercises[nextExerciseIndex];
      const nextSet = nextExercise.sets[nextSetIndex];
      const plannedEquipment = getExerciseEquipment(nextExercise);
      const selectedEquipment =
        draft.equipmentByExercise[nextExercise.exerciseId] ?? plannedEquipment;
      patchDraft({
        editedReps: nextSet.targetReps ?? 0,
        editedWeight:
          selectedEquipment === plannedEquipment
            ? nextSet.targetWeightKg
            : convertWeightForEquipment(
                nextSet.targetWeightKg,
                plannedEquipment,
                selectedEquipment,
              ),
        editedDurationSeconds: nextSet.targetDurationSeconds ?? 0,
        setTimerRemaining: nextSet.targetDurationSeconds ?? 0,
        isSetTimerRunning: false,
        setTimerEndsAt: undefined,
      });
    },
    [draft.equipmentByExercise, patchDraft, selectedSession],
  );

  const completeWorkout = useCallback(() => {
    const finishedAt = new Date().toISOString();
    patchDraft({
      phase: 'done',
      finishedAt,
      transitionExerciseIds: [],
      transitionNextPhase: 'set',
    });
    void markSessionFinished(selectedSession.sessionId, finishedAt)
      .catch(() => undefined)
      .finally(refreshSessionHistory);
  }, [patchDraft, refreshSessionHistory, selectedSession.sessionId]);

  const moveForward = useCallback(() => {
    if (!currentExercise || !currentStep) {
      return;
    }

    const completedExerciseIds = getCompletedExerciseIds(
      selectedSession,
      currentStep,
    );

    if (!nextStep) {
      if (completedExerciseIds.length > 0) {
        patchDraft({
          phase: 'transition',
          transitionExerciseIds: completedExerciseIds,
          transitionNextPhase: 'done',
        });
      } else {
        completeWorkout();
      }
      return;
    }

    applyPlannedTargets(nextStep.exerciseIndex, nextStep.setIndex);
    const shouldShowTransition =
      completedExerciseIds.length > 0 && !draft.suppressTransitionOnce;

    patchDraft({
      exerciseIndex: nextStep.exerciseIndex,
      setIndex: nextStep.setIndex,
      phase: shouldShowTransition ? 'transition' : 'set',
      transitionExerciseIds: shouldShowTransition ? completedExerciseIds : [],
      transitionNextPhase: 'set',
      suppressTransitionOnce: false,
      restEndsAt: undefined,
    });
  }, [
    applyPlannedTargets,
    currentExercise,
    currentStep,
    draft.suppressTransitionOnce,
    completeWorkout,
    nextStep,
    patchDraft,
    selectedSession,
  ]);

  const shouldRestAfterCurrentStep =
    currentStep !== undefined &&
    nextStep !== undefined &&
    (!currentStep.supersetId ||
      currentStep.supersetId !== nextStep.supersetId ||
      nextStep.roundNumber !== currentStep.roundNumber);

  const logCurrentSet = useCallback(
    async (status: 'completed' | 'skipped') => {
      if (!currentSet || isRegisteringSetRef.current) {
        return;
      }

      isRegisteringSetRef.current = true;
      setIsRegisteringSet(true);
      setSaveStatus('saving');

      const nextRecord: StoredSetEvent = {
        id: createEventId(),
        performedAt: new Date().toISOString(),
        planId: trainingPlan.planId,
        sessionId: selectedSession.sessionId,
        sessionDate: selectedSession.date,
        exerciseId: currentExercise.exerciseId,
        exerciseIndex: draft.exerciseIndex,
        setIndex: draft.setIndex,
        supersetId: currentStep?.supersetId,
        supersetOrder: currentStep?.supersetOrder,
        roundNumber: currentStep?.roundNumber ?? draft.setIndex + 1,
        plannedReps: currentSet.targetReps ?? 0,
        plannedWeightKg: currentSet.targetWeightKg,
        plannedDurationSeconds: currentSet.targetDurationSeconds,
        plannedEquipment: currentExercise.equipment,
        actualReps: draft.editedReps,
        actualWeightKg: draft.editedWeight,
        actualDurationSeconds:
          currentSet.type === 'timed'
            ? draft.editedDurationSeconds - draft.setTimerRemaining
            : undefined,
        actualEquipment: currentEquipment,
        restSecondsPlanned: currentSet.restSeconds,
        restSecondsActual: currentSet.restSeconds,
        status,
        rirLast: draft.editedRir,
        painKnee: draft.painKnee,
        painWrist: draft.painWrist,
        painShoulder: draft.painShoulder,
        painLowerBack: draft.painLowerBack,
        painOther: draft.painOther,
        note: draft.setNote,
      };

      try {
        await saveSetEvent(nextRecord);
      } catch {
        window.alert(
          'No se ha podido guardar la serie en este dispositivo. Inténtalo de nuevo.',
        );
        isRegisteringSetRef.current = false;
        setIsRegisteringSet(false);
        setSaveStatus('idle');
        return;
      }

      setSaveStatus('saved');
      window.setTimeout(() => setSaveStatus('idle'), 1800);

      setDraft((current) => ({
        ...current,
        records: [...current.records, nextRecord],
        editedRir: 2,
        painKnee: 0,
        painWrist: 0,
        painShoulder: 0,
        painLowerBack: 0,
        painOther: 0,
        setNote: 'OK',
        isSetTimerRunning: false,
        setTimerEndsAt: undefined,
      }));

      const completedExerciseIds = getCompletedExerciseIds(
        selectedSession,
        currentStep,
      );

      if (!shouldRestAfterCurrentStep || status === 'skipped') {
        moveForward();
        isRegisteringSetRef.current = false;
        setIsRegisteringSet(false);
        return;
      }

      if (completedExerciseIds.length > 0) {
        patchDraft({
          restRemaining: currentSet.restSeconds,
          restEndsAt: undefined,
          phase: 'transition',
          transitionExerciseIds: completedExerciseIds,
          transitionNextPhase: 'rest',
        });
      } else {
        patchDraft({
          restRemaining: currentSet.restSeconds,
          restEndsAt: getTimerEndsAt(currentSet.restSeconds),
          phase: 'rest',
        });
      }
      isRegisteringSetRef.current = false;
      setIsRegisteringSet(false);
    },
    [
      currentSet,
      currentStep,
      currentEquipment,
      draft.editedDurationSeconds,
      draft.editedReps,
      draft.editedWeight,
      draft.editedRir,
      draft.exerciseIndex,
      draft.painKnee,
      draft.painLowerBack,
      draft.painOther,
      draft.painShoulder,
      draft.painWrist,
      draft.setIndex,
      draft.setNote,
      draft.setTimerRemaining,
      currentExercise,
      moveForward,
      patchDraft,
      selectedSession,
      shouldRestAfterCurrentStep,
    ],
  );

  const changeSession = (sessionId: string) => {
    setDraft(makeDraft(getSessionById(sessionId)));
  };

  const previewTraining = () => {
    patchDraft({ phase: 'preview' });
  };

  const beginTraining = useCallback(() => {
    const startedAt = new Date().toISOString();
    const nextDraft = makeDraft(selectedSession);

    setDraft({ ...nextDraft, phase: 'set', startedAt });
    void clearSessionEvents(selectedSession.sessionId)
      .catch(() => undefined)
      .finally(() => {
        void markSessionStarted(selectedSession.sessionId, startedAt).catch(
          () => undefined,
        );
      });
  }, [selectedSession]);

  const resume = () => {
    patchDraft({ phase: currentSet ? 'set' : 'today' });
  };

  const chooseDecision = (exerciseId: string, decision: string) => {
    setDraft((current) => ({
      ...current,
      decisions: { ...current.decisions, [exerciseId]: decision },
    }));
    void markSessionExerciseDecision(
      selectedSession.sessionId,
      exerciseId,
      decision,
    )
      .catch(() => undefined)
      .finally(refreshSessionHistory);
  };

  const clearAllLocalData = () => {
    const shouldClear = window.confirm(
      'Borrar todos los entrenamientos guardados en este dispositivo?',
    );

    if (!shouldClear) {
      return;
    }

    void clearAllSessionEvents()
      .catch(() => undefined)
      .finally(() => {
        window.localStorage.removeItem(storageKey);
        setDraft(makeDraft());
        void refreshSessionHistory();
      });
  };

  const exportWorkoutCsv = async (
    session: TrainingSession,
    records: StoredSetEvent[],
    decisions: Record<string, string>,
  ) => {
    const csv = buildWorkoutCsv(session, records, decisions);
    const fileName = getWorkoutCsvFileName(session);
    const file = new File([csv], fileName, { type: 'text/csv;charset=utf-8' });

    await shareOrDownloadFile(file, fileName);
  };

  const exportFullTrainingDataJson = async () => {
    const [events, metadata] = await Promise.all([
      loadAllSessionEvents(),
      loadSessionMetadata(),
    ]);
    const exportedAt = new Date().toISOString();
    const fullExport = buildFullTrainingDataExport({
      plan: trainingPlan,
      events,
      metadata,
      summaries: getSessionHistorySummaries(
        trainingPlan.sessions,
        events,
        metadata,
      ),
      exportedAt,
      app: {
        name: packageData.name,
        version: appVersion,
      },
      settings: {
        appearanceTheme,
        keepScreenAwake,
      },
      activeWorkout: {
        selectedSessionId: draft.selectedSessionId,
        phase: draft.phase as ExportPhase,
        exerciseIndex: draft.exerciseIndex,
        setIndex: draft.setIndex,
        ...(draft.startedAt ? { startedAt: draft.startedAt } : {}),
        ...(draft.finishedAt ? { finishedAt: draft.finishedAt } : {}),
      },
    });
    const fileName = getFullJsonExportFileName(trainingPlan.planId, exportedAt);
    const file = new File(
      [`${JSON.stringify(fullExport, null, 2)}\n`],
      fileName,
      {
        type: 'application/json;charset=utf-8',
      },
    );

    await shareOrDownloadFile(file, fileName);
    await Promise.all(
      fullExport.sessions.map((session) =>
        markSessionExported(session.sessionId, exportedAt),
      ),
    );
    await refreshSessionHistory();
  };

  const exportStatisticsCsv = async () => {
    const exportedAt = new Date().toISOString();
    const csv = buildStatisticsCsv({
      exportedAt,
      appVersion,
      stats: trainingStats,
      history: sessionHistory,
      exerciseProgressions,
      volumeSummary,
    });
    const fileName = getStatisticsCsvFileName(exportedAt);
    const file = new File([csv], fileName, {
      type: 'text/csv;charset=utf-8',
    });

    await shareOrDownloadFile(file, fileName);
  };

  const exportCsv = async () => {
    await exportWorkoutCsv(selectedSession, draft.records, draft.decisions);
    await markSessionExported(
      selectedSession.sessionId,
      new Date().toISOString(),
    );
    await refreshSessionHistory();
  };

  const exportHistorySession = async (sessionId: string) => {
    const session = getSessionById(sessionId);
    const records = await loadSessionEvents(session.sessionId);
    const metadata = await loadSessionMetadata();
    const sessionDecisions =
      metadata.find((item) => item.sessionId === session.sessionId)
        ?.decisions ?? {};
    await exportWorkoutCsv(
      session,
      records,
      getDecisionFallbacks(records, {
        ...sessionDecisions,
        ...draft.decisions,
      }),
    );
    await markSessionExported(session.sessionId, new Date().toISOString());
    await refreshSessionHistory();
  };

  const deleteHistorySession = (sessionId: string) => {
    const session = getSessionById(sessionId);
    const shouldDelete = window.confirm(
      `Borrar los datos locales de ${session.label}?`,
    );

    if (!shouldDelete) {
      return;
    }

    void clearSessionEvents(session.sessionId)
      .catch(() => undefined)
      .finally(() => {
        if (session.sessionId === draft.selectedSessionId) {
          setDraft((current) => ({ ...current, records: [] }));
        }
        void refreshSessionHistory();
      });
  };

  const openSettings = (returnPhase = draft.phase) => {
    setSettingsReturnPhase(returnPhase);
    setSettingsSection('index');
    patchDraft({ phase: 'settings' });
  };

  const returnToTodayAfterDone = () => {
    window.localStorage.removeItem(storageKey);
    setDraft(makeDraft());
  };

  useEffect(() => {
    const context =
      typeof document === 'undefined'
        ? undefined
        : (document as WebMcpDocument).modelContext;

    if (!context?.registerTool) {
      return;
    }

    const lifecycle = new AbortController();
    const register = (tool: WebMcpTool) => {
      try {
        void Promise.resolve(
          context.registerTool(tool, { signal: lifecycle.signal }),
        ).catch(() => undefined);
      } catch {
        // WebMCP is optional and not available in every browser context.
      }
    };

    register({
      name: 'get_training_state',
      title: 'Leer entrenamiento',
      description: 'Devuelve la sesión, fase y serie visibles en GymApp.',
      inputSchema: { type: 'object', additionalProperties: false },
      annotations: { readOnlyHint: true, untrustedContentHint: false },
      execute: () => ({
        phase: draft.phase,
        sessionId: selectedSession.sessionId,
        sessionLabel: selectedSession.sessionLabel,
        exercise: currentExercise?.name,
        setIndex: draft.setIndex + 1,
        attemptedSets,
        totalSets,
      }),
    });

    register({
      name: 'start_current_training_session',
      title: 'Empezar sesión',
      description:
        'Abre la pantalla de la primera serie de la sesión seleccionada.',
      inputSchema: { type: 'object', additionalProperties: false },
      annotations: { readOnlyHint: false, untrustedContentHint: false },
      execute: () => {
        beginTraining();
        return { phase: 'set', sessionId: selectedSession.sessionId };
      },
    });

    register({
      name: 'record_current_training_set',
      title: 'Registrar serie',
      description:
        'Registra o salta la serie visible usando los valores actuales.',
      inputSchema: {
        type: 'object',
        properties: {
          status: { enum: ['completed', 'skipped'] },
        },
        required: ['status'],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: false, untrustedContentHint: false },
      execute: (input) => {
        const status =
          typeof input === 'object' && input !== null && 'status' in input
            ? (input as { status?: unknown }).status
            : undefined;

        if (draft.phase !== 'feedback' || !currentSet) {
          throw new Error('No hay una serie activa para registrar.');
        }

        if (status !== 'completed' && status !== 'skipped') {
          throw new Error('status debe ser completed o skipped.');
        }

        void logCurrentSet(status);
        return {
          status,
          reps: draft.editedReps,
          weightKg: draft.editedWeight,
          exercise: currentExercise.name,
          setIndex: draft.setIndex + 1,
        };
      },
    });

    return () => lifecycle.abort();
  }, [
    attemptedSets,
    beginTraining,
    currentExercise,
    currentSet,
    draft,
    logCurrentSet,
    patchDraft,
    selectedSession,
    totalSets,
  ]);

  return (
    <main className="app-screen overflow-hidden bg-background text-foreground">
      <OrientationLockOverlay />
      <div className="app-screen app-shell mx-auto flex w-full max-w-[480px] flex-col overflow-hidden px-4 pb-[calc(1rem+env(safe-area-inset-bottom))] sm:py-4">
        {draft.phase !== 'settings' ? (
          <header className="mb-1">
            <p className="text-xs font-black uppercase text-muted-foreground">
              {draft.phase === 'preview'
                ? `Semana ${selectedSession.week} · ${selectedSession.weekFocusLabel} · Vista previa`
                : `Semana ${selectedSession.week} · ${selectedSession.weekFocusLabel}${
                    draft.phase !== 'today' ? ` · ${selectedSession.label}` : ''
                  }`}
            </p>
          </header>
        ) : null}

        {draft.phase !== 'today' &&
        draft.phase !== 'settings' &&
        draft.phase !== 'preview' ? (
          <section className="mb-2">
            <Progress value={progressValue} />
            <p className="mt-1 text-right text-xs font-black text-muted-foreground">
              {attemptedSets}/{totalSets}
            </p>
          </section>
        ) : null}

        {draft.phase === 'today' ? (
          <TodayScreen
            selectedSession={selectedSession}
            durationEstimate={selectedSessionDurationEstimate}
            weekSessions={weekSessions}
            completedSessionIds={completedSessionIds}
            hasStarted={hasStarted}
            onChangeSession={changeSession}
            onResume={resume}
            onStart={previewTraining}
            onSettings={() => openSettings('today')}
          />
        ) : null}

        {draft.phase === 'preview' ? (
          <PreviewScreen
            session={selectedSession}
            durationEstimate={selectedSessionDurationEstimate}
            onBack={() => patchDraft({ phase: 'today' })}
            onStart={beginTraining}
          />
        ) : null}

        {draft.phase === 'settings' ? (
          <SettingsScreen
            section={settingsSection}
            theme={appearanceTheme}
            keepScreenAwake={keepScreenAwake}
            wakeLockStatus={wakeLockStatus}
            offlineStatus={offlineStatus}
            offlineInfo={offlineInfo}
            selectedSessionLabel={selectedSession.label}
            upcomingSessions={upcomingSessions}
            sessionHistory={sessionHistory}
            exerciseProgressions={exerciseProgressions}
            volumeSummary={volumeSummary}
            trainingStats={trainingStats}
            isLoadingHistory={isLoadingHistory}
            onSectionChange={setSettingsSection}
            onThemeChange={setAppearanceTheme}
            onKeepScreenAwakeChange={(enabled) => {
              setKeepScreenAwake(enabled);
              if (enabled) {
                void requestScreenWakeLock();
              } else {
                releaseScreenWakeLock();
              }
            }}
            onCheckOffline={checkOffline}
            onUpdateOfflineVersion={updateOfflineVersion}
            onResetCurrent={() => {
              void resetWorkoutPosition(draft.selectedSessionId).finally(
                refreshSessionHistory,
              );
            }}
            onClearAllData={clearAllLocalData}
            onExportFullJson={() => {
              void exportFullTrainingDataJson().catch(() => {
                window.alert('No se pudo exportar el backup JSON.');
              });
            }}
            onExportStatisticsCsv={() => {
              void exportStatisticsCsv().catch(() => {
                window.alert('No se pudieron exportar las estadísticas CSV.');
              });
            }}
            onExportHistorySession={exportHistorySession}
            onDeleteHistorySession={deleteHistorySession}
            onBack={() => patchDraft({ phase: settingsReturnPhase })}
          />
        ) : null}

        {draft.phase === 'set' && currentSet ? (
          <SetScreen
            exerciseName={currentExercise.name}
            exerciseNotes={currentExercise.notes}
            setIndex={draft.setIndex}
            totalExerciseSets={currentExercise.sets.length}
            supersetPosition={currentStep?.supersetOrder}
            supersetSize={
              supersetMembers.length > 0 ? supersetMembers.length : undefined
            }
            supersetRound={
              currentStep?.supersetId ? currentStep.roundNumber : undefined
            }
            supersetRoundCount={supersetRoundCount}
            nextLinkedExerciseName={nextLinkedExercise?.name}
            setType={currentSet.type}
            reps={draft.editedReps}
            weight={draft.editedWeight}
            loadType={currentLoadType}
            equipment={currentEquipment}
            equipmentOptions={getExerciseEquipmentOptions(currentExercise)}
            durationSeconds={draft.editedDurationSeconds}
            timerRemaining={draft.setTimerRemaining}
            isTimerRunning={draft.isSetTimerRunning}
            restSeconds={currentSet.restSeconds}
            completedSetIndexes={draft.records
              .filter((record) => record.exerciseIndex === draft.exerciseIndex)
              .map((record) => record.setIndex)}
            onEdit={() => patchDraft({ phase: 'edit-set' })}
            onTimerToggle={() =>
              patchDraft(
                draft.isSetTimerRunning
                  ? {
                      isSetTimerRunning: false,
                      setTimerEndsAt: undefined,
                    }
                  : {
                      isSetTimerRunning: true,
                      setTimerRemaining:
                        draft.setTimerRemaining > 0
                          ? draft.setTimerRemaining
                          : draft.editedDurationSeconds,
                      setTimerEndsAt: getTimerEndsAt(
                        draft.setTimerRemaining > 0
                          ? draft.setTimerRemaining
                          : draft.editedDurationSeconds,
                      ),
                    },
              )
            }
            onTimerReset={() =>
              patchDraft({
                setTimerRemaining: draft.editedDurationSeconds,
                isSetTimerRunning: false,
                setTimerEndsAt: undefined,
              })
            }
            onContinue={() => patchDraft({ phase: 'feedback' })}
            onSkip={() => void logCurrentSet('skipped')}
            onBack={() => patchDraft({ phase: 'today' })}
            onEquipmentChange={(nextEquipment) => {
              if (!currentEquipment) {
                return;
              }

              patchDraft({
                equipmentByExercise: {
                  ...draft.equipmentByExercise,
                  [currentExercise.exerciseId]: nextEquipment,
                },
                editedWeight: convertWeightForEquipment(
                  draft.editedWeight,
                  currentEquipment,
                  nextEquipment,
                ),
                weightStep: normalizeWeightStep(
                  draft.weightStep,
                  inferEquipmentLoadType(nextEquipment) ??
                    inferLoadType(currentExercise),
                  nextEquipment,
                ),
              });
            }}
            isRegistering={isRegisteringSet}
            saveStatus={saveStatus}
          />
        ) : null}

        {draft.phase === 'edit-set' && currentSet ? (
          <SetEditScreen
            setType={currentSet.type}
            reps={draft.editedReps}
            weight={draft.editedWeight}
            durationSeconds={draft.editedDurationSeconds}
            loadType={currentLoadType}
            equipment={currentEquipment}
            weightStep={draft.weightStep}
            onCancel={() => patchDraft({ phase: 'set' })}
            onConfirm={({ reps, weight, durationSeconds, weightStep }) =>
              patchDraft({
                editedReps: reps,
                editedWeight: weight,
                editedDurationSeconds: durationSeconds,
                setTimerRemaining: durationSeconds,
                isSetTimerRunning: false,
                setTimerEndsAt: undefined,
                weightStep,
                phase: 'set',
              })
            }
          />
        ) : null}

        {draft.phase === 'feedback' && currentSet ? (
          <FeedbackScreen
            exerciseName={currentExercise.name}
            setType={currentSet.type}
            reps={draft.editedReps}
            weight={draft.editedWeight}
            durationSeconds={
              currentSet.type === 'timed'
                ? draft.editedDurationSeconds - draft.setTimerRemaining
                : undefined
            }
            rir={draft.editedRir}
            painKnee={draft.painKnee}
            painWrist={draft.painWrist}
            painShoulder={draft.painShoulder}
            painLowerBack={draft.painLowerBack}
            setNote={draft.setNote}
            onRirChange={(editedRir) => patchDraft({ editedRir })}
            onPainKneeChange={(painKnee) => patchDraft({ painKnee })}
            onPainWristChange={(painWrist) => patchDraft({ painWrist })}
            onPainShoulderChange={(painShoulder) =>
              patchDraft({ painShoulder })
            }
            onPainLowerBackChange={(painLowerBack) =>
              patchDraft({ painLowerBack })
            }
            onSetNoteChange={(setNote) => patchDraft({ setNote })}
            onBack={() => patchDraft({ phase: 'set' })}
            onRegister={() => void logCurrentSet('completed')}
            isRegistering={isRegisteringSet}
            saveStatus={saveStatus}
          />
        ) : null}

        {draft.phase === 'rest' ? (
          <RestScreen
            restRemaining={draft.restRemaining}
            restTotal={currentSet?.restSeconds ?? draft.restRemaining}
            nextLabel={getNextStepLabel(selectedSession, currentStep, nextStep)}
            nextSetPreview={getNextSetPreview(selectedSession, nextStep)}
            saveStatus={saveStatus}
            onAdjustRest={(updater) => {
              setDraft((current) => ({
                ...current,
                ...(() => {
                  const restRemaining = Math.max(
                    0,
                    typeof updater === 'function'
                      ? updater(current.restRemaining)
                      : updater,
                  );

                  return {
                    restRemaining,
                    restEndsAt:
                      restRemaining > 0
                        ? getTimerEndsAt(restRemaining)
                        : undefined,
                  };
                })(),
              }));
            }}
            onContinue={moveForward}
          />
        ) : null}

        {draft.phase === 'transition' ? (
          <TransitionScreen
            completedExercises={draft.transitionExerciseIds
              .map((exerciseId) =>
                selectedSession.exercises.find(
                  (exercise) => exercise.exerciseId === exerciseId,
                ),
              )
              .filter((exercise): exercise is Exercise => Boolean(exercise))}
            nextExercise={
              draft.transitionNextPhase === 'set'
                ? currentExercise
                : draft.transitionNextPhase === 'rest' && nextStep
                  ? selectedSession.exercises[nextStep.exerciseIndex]
                  : undefined
            }
            decisions={draft.decisions}
            onDecision={chooseDecision}
            onContinue={() => {
              const completedExercises = draft.transitionExerciseIds
                .map((exerciseId) =>
                  selectedSession.exercises.find(
                    (exercise) => exercise.exerciseId === exerciseId,
                  ),
                )
                .filter((exercise): exercise is Exercise => Boolean(exercise));
              const defaultDecisions = completedExercises.reduce<
                Record<string, string>
              >(
                (decisions, exercise) => ({
                  ...decisions,
                  [exercise.exerciseId]:
                    draft.decisions[exercise.exerciseId] ??
                    getDefaultExerciseDecision(exercise),
                }),
                {},
              );
              const nextDecisions = {
                ...draft.decisions,
                ...defaultDecisions,
              };

              completedExercises.forEach((exercise) => {
                if (draft.decisions[exercise.exerciseId] === undefined) {
                  void markSessionExerciseDecision(
                    selectedSession.sessionId,
                    exercise.exerciseId,
                    defaultDecisions[exercise.exerciseId],
                  ).catch(() => undefined);
                }
              });

              if (draft.transitionNextPhase === 'done') {
                setDraft((current) => ({
                  ...current,
                  decisions: nextDecisions,
                }));
                completeWorkout();
                return;
              }

              patchDraft({
                phase: draft.transitionNextPhase,
                decisions: nextDecisions,
                transitionExerciseIds: [],
                suppressTransitionOnce: draft.transitionNextPhase === 'rest',
                ...(draft.transitionNextPhase === 'rest'
                  ? { restEndsAt: getTimerEndsAt(draft.restRemaining) }
                  : {}),
              });
            }}
            saveStatus={saveStatus}
          />
        ) : null}

        {draft.phase === 'done' ? (
          <DoneScreen
            completedSets={completedSets}
            totalSets={totalSets}
            estimatedMinutes={Math.max(
              1,
              selectedSessionDurationEstimate.totalMinutes -
                selectedSessionDurationEstimate.mobilityMinutes,
            )}
            {...(workoutDurationMinutes !== undefined
              ? { durationMinutes: workoutDurationMinutes }
              : {})}
            onExport={exportCsv}
            onRestart={returnToTodayAfterDone}
          />
        ) : null}
      </div>
    </main>
  );
}

function OrientationLockOverlay() {
  return (
    <dialog
      className="orientation-lock fixed inset-0 z-50 hidden h-full max-h-none w-full max-w-none bg-background px-8 text-center text-foreground"
      open
      aria-modal="true"
      aria-label="Gira el iPhone"
    >
      <div className="mx-auto flex h-full max-w-sm flex-col items-center justify-center gap-4">
        <div className="rounded-[2rem] border bg-card p-5 shadow-sm">
          <RotateCcw className="mx-auto size-10 text-primary" />
          <p className="mt-4 text-2xl font-black tracking-normal">
            Gira el iPhone
          </p>
          <p className="mt-2 text-sm font-bold leading-snug text-muted-foreground">
            De momento la app está bloqueada en vertical.
          </p>
        </div>
      </div>
    </dialog>
  );
}

function TodayScreen({
  selectedSession,
  durationEstimate,
  weekSessions,
  completedSessionIds,
  hasStarted,
  onChangeSession,
  onResume,
  onStart,
  onSettings,
}: {
  selectedSession: TrainingSession;
  durationEstimate: SessionDurationEstimate;
  weekSessions: TrainingSession[];
  completedSessionIds: Set<string>;
  hasStarted: boolean;
  onChangeSession: (sessionId: string) => void;
  onResume: () => void;
  onStart: () => void;
  onSettings: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col gap-3">
      <div className="flex h-[280px] flex-col rounded-lg border bg-card p-4 shadow-sm">
        <p className="text-sm font-semibold leading-none text-muted-foreground">
          Hoy toca
        </p>
        <h2 className="mt-3 h-[92px] overflow-hidden text-[2rem] font-black leading-[1.08] tracking-normal [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {selectedSession.label}
        </h2>
        <p className="mt-2 h-12 overflow-hidden text-base leading-tight text-muted-foreground [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {selectedSession.focus}
        </p>
        <div className="mt-auto grid grid-cols-3 gap-2 text-center">
          <Metric label="Fecha" value={formatDate(selectedSession.date)} />
          <Metric
            label="Estimado"
            value={`${durationEstimate.totalMinutes}m`}
          />
          <Metric
            label="Bloques"
            value={`${selectedSession.exercises.length}`}
          />
        </div>
      </div>

      {hasStarted ? (
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          onClick={onResume}
        >
          Reanudar
          <ChevronRight className="size-6" />
        </Button>
      ) : null}

      <div className="grid gap-2">
        {weekSessions.map((session) => {
          const isSelected = session.sessionId === selectedSession.sessionId;
          const isComplete = completedSessionIds.has(session.sessionId);

          return (
            <button
              key={session.sessionId}
              className={`min-h-16 rounded-lg border px-3 py-2.5 text-left transition active:scale-[0.98] ${
                isSelected
                  ? 'border-primary bg-primary text-primary-foreground'
                  : isComplete
                    ? 'border-[var(--complete-border)] bg-[var(--complete)] text-[var(--complete-foreground)]'
                    : 'border-border bg-secondary text-secondary-foreground'
              }`}
              type="button"
              onClick={() => onChangeSession(session.sessionId)}
            >
              <span className="flex min-w-0 items-center justify-between gap-2 text-sm font-bold capitalize">
                <span className="truncate">{session.weekday}</span>
                {isComplete ? (
                  <span
                    className={`inline-flex shrink-0 items-center gap-1 rounded-full border px-2 py-0.5 text-[0.68rem] font-black normal-case ${
                      isSelected
                        ? 'border-primary-foreground/35 text-primary-foreground'
                        : 'border-[var(--complete-border)] text-[var(--complete-foreground)]'
                    }`}
                  >
                    <Check className="size-3" />
                    Hecho
                  </span>
                ) : null}
              </span>
              <span className="mt-1 block overflow-hidden text-lg font-black leading-tight [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
                {session.label}
              </span>
            </button>
          );
        })}
      </div>

      <div
        className="mt-auto grid gap-3"
        style={{ gridTemplateColumns: '56px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Configuración"
          className={`h-14 w-14 rounded-[1.75rem] p-0 ${actionStyles.back}`}
          style={{ width: '56px' }}
          variant="outline"
          onClick={onSettings}
        >
          <Settings className="size-6" />
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          variant="default"
          onClick={onStart}
        >
          Siguiente
          <ChevronRight className="size-6" />
        </Button>
      </div>
    </section>
  );
}

function PreviewScreen({
  session,
  durationEstimate,
  onBack,
  onStart,
}: {
  session: TrainingSession;
  durationEstimate: SessionDurationEstimate;
  onBack: () => void;
  onStart: () => void;
}) {
  const durationStatus = getDurationEstimateStatus(durationEstimate);

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden">
      <div className="shrink-0 rounded-lg border bg-card p-4 shadow-sm">
        <p className="text-sm font-semibold text-muted-foreground">
          Preparación
        </p>
        <h2 className="mt-1 text-[1.85rem] font-black leading-tight tracking-normal">
          {session.label}
        </h2>
        <div className="mt-3 grid grid-cols-3 gap-2 text-center">
          <Metric label="Fecha" value={formatDate(session.date)} />
          <Metric
            label="Estimado"
            value={`${durationEstimate.totalMinutes}m`}
          />
          <Metric label="Bloques" value={`${session.exercises.length}`} />
        </div>
        <div className="mt-3 grid grid-cols-3 gap-2 text-center">
          <Metric
            label="Movilidad"
            value={`${durationEstimate.mobilityMinutes}m`}
          />
          <Metric
            label="Trabajo"
            value={`${
              durationEstimate.executionMinutes + durationEstimate.restMinutes
            }m`}
          />
          <Metric
            label="Cambios"
            value={`${
              durationEstimate.changeoverMinutes +
              durationEstimate.feedbackMinutes
            }m`}
          />
        </div>
        <p
          className={`mt-3 rounded-lg px-3 py-2 text-center text-sm font-black ${
            durationEstimate.totalMinutes - durationEstimate.targetMinutes > 15
              ? 'bg-[var(--action-reset)] text-[var(--action-reset-foreground)]'
              : 'bg-secondary text-secondary-foreground'
          }`}
        >
          {durationStatus}
        </p>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto pr-1">
        <div className="grid gap-2 pb-1">
          {session.exercises.map((exercise, index) => (
            <ExercisePlanCard
              key={exercise.exerciseId}
              session={session}
              exercise={exercise}
              index={index}
            />
          ))}
        </div>
      </div>

      <div
        className="grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '56px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Ir a pantalla principal"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.back}`}
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
        >
          <House className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          onClick={onStart}
        >
          Empezar entrenamiento
          <ChevronRight className="size-6" />
        </Button>
      </div>
    </section>
  );
}

function PreviewMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex min-w-0 flex-col items-center justify-center rounded-md bg-secondary px-2 py-2.5">
      <p className="max-w-full truncate text-[0.62rem] font-black uppercase leading-none text-muted-foreground">
        {label}
      </p>
      <p className="mt-1 max-w-full truncate text-xl font-black leading-none tabular-nums">
        {value}
      </p>
    </div>
  );
}

function ExercisePlanCard({
  session,
  exercise,
  index,
}: {
  session: TrainingSession;
  exercise: Exercise;
  index: number;
}) {
  const metrics = getExercisePreviewMetrics(exercise);
  const supersetSize = exercise.supersetId
    ? getSupersetMembers(session, exercise.supersetId).length
    : 0;

  return (
    <div className="grid gap-3 rounded-lg border bg-card p-3 shadow-sm">
      <div className="flex min-w-0 items-center gap-3">
        <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-sm font-black text-secondary-foreground">
          {index + 1}
        </span>
        <div className="min-w-0">
          {exercise.supersetId ? (
            <p className="mb-1 text-[0.68rem] font-black uppercase leading-none text-primary">
              Superserie {exercise.supersetOrder}/{supersetSize}
            </p>
          ) : null}
          <p className="min-w-0 text-base font-black leading-tight">
            {exercise.name}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 text-center">
        <PreviewMetric label="series" value={metrics.sets} />
        <PreviewMetric label={metrics.workLabel} value={metrics.work} />
        <PreviewMetric label={metrics.loadLabel} value={metrics.load} />
      </div>
    </div>
  );
}

function UpcomingSessionsPanel({ sessions }: { sessions: TrainingSession[] }) {
  const [selectedSessionId, setSelectedSessionId] = useState(
    sessions[0]?.sessionId ?? '',
  );
  const selectedSession = sessions.find(
    (session) => session.sessionId === selectedSessionId,
  );

  if (sessions.length === 0) {
    return (
      <div className="mt-4 rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
        No hay entrenamientos futuros en el planning activo.
      </div>
    );
  }

  return (
    <div className="mt-4 grid gap-3">
      <div className="grid gap-2">
        {sessions.map((session) => {
          const isSelected = session.sessionId === selectedSession?.sessionId;
          const estimate = isSelected
            ? estimateSessionDuration(session)
            : undefined;

          return (
            <div key={session.sessionId} className="grid gap-2">
              <button
                className={`rounded-[1.4rem] border px-3 py-2.5 text-left transition active:scale-[0.98] ${
                  isSelected
                    ? 'border-primary bg-primary text-primary-foreground'
                    : 'border-border bg-secondary text-secondary-foreground'
                }`}
                type="button"
                aria-label={`Ver ${session.label} del ${formatDate(
                  session.date,
                )}`}
                onClick={() =>
                  setSelectedSessionId(isSelected ? '' : session.sessionId)
                }
              >
                <span className="flex min-w-0 items-center justify-between gap-3">
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-bold capitalize">
                      {session.weekday} · {formatDate(session.date)}
                    </span>
                    <span className="mt-0.5 block truncate text-base font-black leading-tight">
                      {session.label}
                    </span>
                  </span>
                  <span
                    className={`shrink-0 rounded-full border px-2.5 py-1 text-xs font-black ${
                      isSelected
                        ? 'border-primary-foreground/35 text-primary-foreground'
                        : 'border-border text-muted-foreground'
                    }`}
                  >
                    S{session.week}
                  </span>
                </span>
              </button>

              {isSelected ? (
                <div className="grid gap-2 rounded-[1.5rem] border bg-secondary p-2">
                  <div className="rounded-lg border bg-card p-3 shadow-sm">
                    <p className="text-sm font-bold text-muted-foreground">
                      Semana {session.week} · {session.weekFocusLabel}
                    </p>
                    <div className="mt-3 grid grid-cols-3 gap-2 text-center">
                      <Metric label="Fecha" value={formatDate(session.date)} />
                      <Metric
                        label="Estimado"
                        value={`${estimate?.totalMinutes ?? 0}m`}
                      />
                      <Metric
                        label="Bloques"
                        value={`${session.exercises.length}`}
                      />
                    </div>
                  </div>

                  {session.exercises.map((exercise, index) => (
                    <ExercisePlanCard
                      key={exercise.exerciseId}
                      session={session}
                      exercise={exercise}
                      index={index}
                    />
                  ))}
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function SettingsScreen({
  section,
  theme,
  keepScreenAwake,
  wakeLockStatus,
  offlineStatus,
  offlineInfo,
  selectedSessionLabel,
  upcomingSessions,
  sessionHistory,
  exerciseProgressions,
  volumeSummary,
  trainingStats,
  isLoadingHistory,
  onSectionChange,
  onThemeChange,
  onKeepScreenAwakeChange,
  onCheckOffline,
  onUpdateOfflineVersion,
  onResetCurrent,
  onClearAllData,
  onExportFullJson,
  onExportStatisticsCsv,
  onExportHistorySession,
  onDeleteHistorySession,
  onBack,
}: {
  section: SettingsSection;
  theme: AppearanceTheme;
  keepScreenAwake: boolean;
  wakeLockStatus: WakeLockStatus;
  offlineStatus: OfflineStatus;
  offlineInfo: OfflineInfo;
  selectedSessionLabel: string;
  upcomingSessions: TrainingSession[];
  sessionHistory: SessionHistorySummary[];
  exerciseProgressions: ExerciseProgressionSummary[];
  volumeSummary: VolumeSummary;
  trainingStats: TrainingStatsSummary;
  isLoadingHistory: boolean;
  onSectionChange: (section: SettingsSection) => void;
  onThemeChange: (theme: AppearanceTheme) => void;
  onKeepScreenAwakeChange: (enabled: boolean) => void;
  onCheckOffline: () => void;
  onUpdateOfflineVersion: () => void;
  onResetCurrent: () => void;
  onClearAllData: () => void;
  onExportFullJson: () => void;
  onExportStatisticsCsv: () => void;
  onExportHistorySession: (sessionId: string) => void;
  onDeleteHistorySession: (sessionId: string) => void;
  onBack: () => void;
}) {
  const sectionTitle = {
    index: 'Ajustes',
    appearance: 'Apariencia',
    training: 'Entrenamiento',
    installation: 'Instalación',
    upcoming: 'Próximos',
    'local-data': 'Datos locales',
    statistics: 'Estadísticas',
    history: 'Historial local',
  }[section];
  const sectionItems: {
    section: Exclude<SettingsSection, 'index'>;
    title: string;
    detail: string;
    icon: ReactNode;
  }[] = [
    {
      section: 'appearance',
      title: 'Apariencia',
      detail: 'Tema claro, oscuro o sistema',
      icon: <Palette className="size-5" />,
    },
    {
      section: 'training',
      title: 'Entrenamiento',
      detail: wakeLockStatusLabels[wakeLockStatus],
      icon: <Smartphone className="size-5" />,
    },
    {
      section: 'installation',
      title: 'Instalación',
      detail: offlineStatusLabels[offlineStatus],
      icon: <Download className="size-5" />,
    },
    {
      section: 'upcoming',
      title: 'Próximos',
      detail: upcomingSessions.length
        ? `${upcomingSessions.length} entrenamientos previstos`
        : 'Sin entrenamientos futuros',
      icon: <CalendarDays className="size-5" />,
    },
    {
      section: 'local-data',
      title: 'Datos locales',
      detail: selectedSessionLabel,
      icon: <Database className="size-5" />,
    },
    {
      section: 'statistics',
      title: 'Estadísticas',
      detail: sessionHistory.length
        ? `${trainingStats.weekCompletedSessions}/${trainingStats.weekTotalSessions} esta semana`
        : 'Sin datos todavía',
      icon: <BarChart3 className="size-5" />,
    },
    {
      section: 'history',
      title: 'Historial local',
      detail: sessionHistory.length
        ? `${sessionHistory.length} sesiones guardadas`
        : 'Sin sesiones guardadas',
      icon: <History className="size-5" />,
    },
  ];
  const goBack = section === 'index' ? onBack : () => onSectionChange('index');

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden">
      <div className="min-h-0 flex-1 overflow-y-auto rounded-lg border bg-card p-4 shadow-sm">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-[1.6rem] font-black leading-tight tracking-normal">
            {sectionTitle}
          </h2>
          <span className="shrink-0 rounded-full border bg-secondary px-3 py-1 text-xs font-black text-muted-foreground">
            v{appVersion}
          </span>
        </div>

        {section === 'index' ? (
          <div className="mt-4 grid gap-2">
            {sectionItems.map((item) => (
              <button
                key={item.section}
                className="flex h-16 items-center gap-3 rounded-[1.75rem] border bg-secondary px-4 text-left text-secondary-foreground transition active:scale-[0.98]"
                type="button"
                onClick={() => onSectionChange(item.section)}
              >
                <span className="grid size-10 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
                  {item.icon}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-base font-black leading-tight">
                    {item.title}
                  </span>
                  <span className="mt-0.5 block truncate text-xs font-bold leading-tight text-muted-foreground">
                    {item.detail}
                  </span>
                </span>
                <ChevronRight className="size-5 shrink-0 text-muted-foreground" />
              </button>
            ))}
          </div>
        ) : null}

        {section === 'appearance' ? (
          <div className="mt-4 grid gap-1.5">
            {appearanceThemes.map((option) => (
              <button
                key={option.value}
                className={`flex h-11 items-center justify-between rounded-[1.35rem] border px-4 text-left text-sm font-black transition active:scale-[0.98] ${
                  theme === option.value
                    ? 'border-primary bg-primary text-primary-foreground'
                    : 'border-border bg-secondary text-secondary-foreground'
                }`}
                type="button"
                onClick={() => onThemeChange(option.value)}
              >
                <span>{option.label}</span>
                <span
                  className={`size-4 rounded-full border-2 ${
                    theme === option.value
                      ? 'border-primary-foreground bg-primary-foreground'
                      : 'border-muted-foreground/45 bg-transparent'
                  }`}
                  aria-hidden="true"
                />
              </button>
            ))}
          </div>
        ) : null}

        {section === 'training' ? (
          <div className="mt-4 flex min-h-16 w-full items-center justify-between gap-4 rounded-[1.75rem] border bg-secondary px-5 py-3 text-left text-secondary-foreground">
            <span className="min-w-0">
              <span className="block text-base font-black leading-tight">
                Pantalla siempre encendida
              </span>
              <span className="mt-0.5 block text-xs font-bold leading-tight text-muted-foreground">
                {wakeLockStatusLabels[wakeLockStatus]}
              </span>
            </span>
            <Switch
              checked={keepScreenAwake}
              onCheckedChange={onKeepScreenAwakeChange}
              aria-label="Mantener pantalla encendida"
            />
          </div>
        ) : null}

        {section === 'installation' ? (
          <div className="mt-4 rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
            <div className="flex items-start justify-between gap-3">
              <span className="min-w-0">
                <span className="block text-base font-black leading-tight">
                  Uso sin conexión
                </span>
                <span className="mt-0.5 block text-xs font-bold leading-tight text-muted-foreground">
                  {offlineStatusLabels[offlineStatus]}
                </span>
              </span>
              <span className="shrink-0 rounded-full border bg-card px-2.5 py-1 text-xs font-black text-muted-foreground">
                {offlineInfo.swVersion
                  ? `sw ${offlineInfo.swVersion}`
                  : `v${appVersion}`}
              </span>
            </div>
            <div className="mt-3 grid grid-cols-[minmax(0,1fr)_112px] gap-2">
              <div className="min-w-0 rounded-[1.1rem] border bg-card px-3 py-2 text-xs font-bold text-muted-foreground">
                <span className="block truncate">
                  {offlineInfo.cacheName ?? 'Caché pendiente'}
                </span>
                <span className="mt-0.5 block">
                  {offlineInfo.cachedUrls !== undefined
                    ? `${offlineInfo.cachedUrls} recursos base`
                    : 'Carga una vez con conexión'}
                </span>
              </div>
              <Button
                className="h-full rounded-[1.1rem] text-sm font-black"
                variant="outline"
                onClick={
                  offlineStatus === 'update-available'
                    ? onUpdateOfflineVersion
                    : onCheckOffline
                }
              >
                {offlineStatus === 'update-available'
                  ? 'Actualizar'
                  : 'Comprobar'}
              </Button>
            </div>
          </div>
        ) : null}

        {section === 'upcoming' ? (
          <UpcomingSessionsPanel sessions={upcomingSessions} />
        ) : null}

        {section === 'local-data' ? (
          <div className="mt-4 grid gap-2">
            <Button
              className={`h-16 justify-start rounded-[1.75rem] px-5 text-left font-black ${actionStyles.reset}`}
              variant="secondary"
              onClick={onResetCurrent}
            >
              <RotateCcw className="size-5" />
              <span className="min-w-0">
                <span className="block text-base leading-tight">
                  Reiniciar entrenamiento
                </span>
                <span className="block truncate text-xs font-bold text-muted-foreground">
                  {selectedSessionLabel}
                </span>
              </span>
            </Button>
            <Button
              className="h-14 justify-start rounded-[1.75rem] px-5 text-left font-black"
              variant="secondary"
              onClick={onExportFullJson}
            >
              <Download className="size-5" />
              Exportar backup JSON
            </Button>
            <Button
              className={`h-14 justify-start rounded-[1.75rem] px-5 text-left font-black ${actionStyles.delete}`}
              variant="outline"
              onClick={onClearAllData}
            >
              <Trash2 className="size-5" />
              Borrar todo local
            </Button>
          </div>
        ) : null}

        {section === 'statistics' ? (
          <StatisticsPanel
            stats={trainingStats}
            history={sessionHistory}
            exerciseProgressions={exerciseProgressions}
            volumeSummary={volumeSummary}
            isLoadingHistory={isLoadingHistory}
            onExportStatisticsCsv={onExportStatisticsCsv}
          />
        ) : null}

        {section === 'history' ? (
          <div className="mt-4">
            <div className="grid gap-2">
              {isLoadingHistory ? (
                <div className="rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
                  Cargando sesiones...
                </div>
              ) : null}

              {!isLoadingHistory && sessionHistory.length === 0 ? (
                <div className="rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
                  Sin entrenamientos registrados en este dispositivo.
                </div>
              ) : null}

              {sessionHistory.map((summary) => (
                <HistorySessionCard
                  key={summary.sessionId}
                  summary={summary}
                  onDeleteHistorySession={onDeleteHistorySession}
                  onExportHistorySession={onExportHistorySession}
                />
              ))}
            </div>
            <p className="mt-2 text-xs font-bold leading-tight text-muted-foreground">
              Las sesiones exportadas se purgan automáticamente tras 30 días.
            </p>
          </div>
        ) : null}
      </div>

      <Button
        className={`h-14 rounded-[1.75rem] text-lg font-black ${actionStyles.back}`}
        variant="outline"
        onClick={goBack}
      >
        {section === 'index' ? 'Volver' : 'Ajustes'}
      </Button>
    </section>
  );
}

function getInsightToneClassName(tone: ExerciseProgressInsight['tone']) {
  return {
    neutral:
      'border-[var(--signal-maintain-border)] bg-[var(--signal-maintain)] text-[var(--signal-maintain-foreground)]',
    up: 'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)]',
    down: 'border-[var(--action-down-border)] bg-[var(--action-down)] text-[var(--action-down-foreground)]',
    warning:
      'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]',
  }[tone];
}

function getProgressionCardToneClassName(
  tone: ExerciseProgressInsight['tone'],
  isExpanded: boolean,
  recommendation: string,
) {
  if (isExpanded) {
    return 'border-primary bg-primary text-primary-foreground';
  }

  if (recommendation.toLowerCase().includes('candidato')) {
    return 'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]';
  }

  return {
    neutral:
      'border-[var(--signal-maintain-border)] bg-[var(--signal-maintain)] text-[var(--signal-maintain-foreground)]',
    up: 'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)]',
    down: 'border-[var(--action-down-border)] bg-[var(--action-down)] text-[var(--action-down-foreground)]',
    warning:
      'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]',
  }[tone];
}

function getProgressionRecommendationToneClassName(
  tone: ExerciseProgressInsight['tone'],
  recommendation: string,
) {
  if (recommendation.toLowerCase().includes('candidato')) {
    return 'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]';
  }

  return getInsightToneClassName(tone);
}

function StatisticsPanel({
  stats,
  history,
  exerciseProgressions,
  volumeSummary,
  isLoadingHistory,
  onExportStatisticsCsv,
}: {
  stats: TrainingStatsSummary;
  history: SessionHistorySummary[];
  exerciseProgressions: ExerciseProgressionSummary[];
  volumeSummary: VolumeSummary;
  isLoadingHistory: boolean;
  onExportStatisticsCsv: () => void;
}) {
  const [statisticsSection, setStatisticsSection] =
    useState<StatisticsSection>('summary');
  const [selectedWeekFilter, setSelectedWeekFilter] = useState('all');
  const [selectedExerciseFilter, setSelectedExerciseFilter] = useState('all');
  const [selectedTrainingBlockFilter, setSelectedTrainingBlockFilter] =
    useState('all');
  const [selectedMovementPatternFilter, setSelectedMovementPatternFilter] =
    useState('all');
  const [selectedMuscleFilter, setSelectedMuscleFilter] = useState('all');
  const [expandedExerciseId, setExpandedExerciseId] = useState(
    exerciseProgressions[0]?.exerciseId ?? '',
  );
  const weekOptions = useMemo(
    () =>
      Array.from(new Set(history.map((summary) => summary.weekNumber))).sort(
        (a, b) => b - a,
      ),
    [history],
  );
  const sessionWeekById = useMemo(
    () =>
      new Map(
        history.map((summary) => [summary.sessionId, summary.weekNumber]),
      ),
    [history],
  );
  const trainingBlockOptions = useMemo(
    () =>
      Array.from(
        new Set(
          exerciseProgressions
            .map((progression) => progression.trainingBlock)
            .filter((value): value is string => Boolean(value)),
        ),
      ).sort((a, b) => a.localeCompare(b)),
    [exerciseProgressions],
  );
  const movementPatternOptions = useMemo(
    () =>
      Array.from(
        new Set(
          exerciseProgressions
            .map((progression) => progression.movementPattern)
            .filter((value): value is string => Boolean(value)),
        ),
      ).sort((a, b) => a.localeCompare(b)),
    [exerciseProgressions],
  );
  const muscleOptions = useMemo(
    () =>
      Array.from(
        new Set(
          exerciseProgressions.flatMap((progression) => [
            ...progression.primaryMuscles,
            ...progression.secondaryMuscles,
          ]),
        ),
      ).sort((a, b) => a.localeCompare(b)),
    [exerciseProgressions],
  );
  const filteredHistory = useMemo(
    () =>
      history.filter(
        (summary) =>
          selectedWeekFilter === 'all' ||
          summary.weekNumber === Number(selectedWeekFilter),
      ),
    [history, selectedWeekFilter],
  );
  const filteredDurationSamples = useMemo(
    () =>
      filteredHistory.flatMap((summary) => {
        const actualMinutes = getDurationMinutes(
          summary.startedAt,
          summary.finishedAt,
        );

        if (!actualMinutes) {
          return [];
        }

        return [
          {
            sessionId: summary.sessionId,
            date: summary.sessionDate,
            label: summary.sessionLabel,
            actualMinutes,
            estimatedMinutes: summary.derivedEstimatedMinutes,
            deltaMinutes: actualMinutes - summary.derivedEstimatedMinutes,
          },
        ];
      }),
    [filteredHistory],
  );
  const filteredAverageDurationMinutes =
    filteredDurationSamples.length > 0
      ? Math.round(
          filteredDurationSamples.reduce(
            (total, sample) => total + sample.actualMinutes,
            0,
          ) / filteredDurationSamples.length,
        )
      : undefined;
  const filteredAverageDeltaMinutes =
    filteredDurationSamples.length > 0
      ? Math.round(
          filteredDurationSamples.reduce(
            (total, sample) => total + sample.deltaMinutes,
            0,
          ) / filteredDurationSamples.length,
        )
      : undefined;
  const durationChartData = filteredDurationSamples
    .slice(0, 6)
    .reverse()
    .map((sample) => ({
      ...sample,
      shortDate: formatChartDate(sample.date),
    }));
  const filteredExerciseProgressions = useMemo(
    () =>
      exerciseProgressions
        .filter(
          (progression) =>
            selectedExerciseFilter === 'all' ||
            progression.exerciseId === selectedExerciseFilter,
        )
        .filter(
          (progression) =>
            selectedTrainingBlockFilter === 'all' ||
            progression.trainingBlock === selectedTrainingBlockFilter,
        )
        .filter(
          (progression) =>
            selectedMovementPatternFilter === 'all' ||
            progression.movementPattern === selectedMovementPatternFilter,
        )
        .filter(
          (progression) =>
            selectedMuscleFilter === 'all' ||
            progression.primaryMuscles.includes(selectedMuscleFilter) ||
            progression.secondaryMuscles.includes(selectedMuscleFilter),
        )
        .map((progression) => ({
          ...progression,
          exposures:
            selectedWeekFilter === 'all'
              ? progression.exposures
              : progression.exposures.filter(
                  (exposure) =>
                    sessionWeekById.get(exposure.sessionId) ===
                    Number(selectedWeekFilter),
                ),
        }))
        .filter(
          (progression) =>
            selectedWeekFilter === 'all' || progression.exposures.length > 0,
        ),
    [
      exerciseProgressions,
      selectedTrainingBlockFilter,
      selectedExerciseFilter,
      selectedMovementPatternFilter,
      selectedMuscleFilter,
      selectedWeekFilter,
      sessionWeekById,
    ],
  );
  const filteredExerciseIds = new Set(
    filteredExerciseProgressions.map((progression) => progression.exerciseId),
  );
  const filteredVolumeByExercise = volumeSummary.byExercise.filter(
    (summary) =>
      (filteredExerciseIds.size === 0 ||
        filteredExerciseIds.has(summary.exerciseId)) &&
      (selectedTrainingBlockFilter === 'all' ||
        summary.trainingBlock === selectedTrainingBlockFilter) &&
      (selectedMovementPatternFilter === 'all' ||
        summary.movementPattern === selectedMovementPatternFilter) &&
      (selectedMuscleFilter === 'all' ||
        summary.primaryMuscles.includes(selectedMuscleFilter)),
  );
  const filteredVolumeByMuscle = Array.from(
    filteredVolumeByExercise
      .reduce((byMuscle, summary) => {
        summary.primaryMuscles.forEach((muscle) => {
          if (
            selectedMuscleFilter !== 'all' &&
            selectedMuscleFilter !== muscle
          ) {
            return;
          }

          const current = byMuscle.get(muscle) ?? {
            muscle,
            completedSets: 0,
            totalReps: 0,
            totalDurationSeconds: 0,
            totalLoadVolumeKg: 0,
          };

          current.completedSets += summary.completedSets;
          current.totalReps += summary.totalReps;
          current.totalDurationSeconds += summary.totalDurationSeconds;
          current.totalLoadVolumeKg += summary.totalLoadVolumeKg;
          byMuscle.set(muscle, current);
        });

        return byMuscle;
      }, new Map<string, VolumeSummary['byMuscle'][number]>())
      .values(),
  ).sort(
    (a, b) =>
      b.completedSets - a.completedSets ||
      b.totalLoadVolumeKg - a.totalLoadVolumeKg ||
      a.muscle.localeCompare(b.muscle),
  );
  const selectedProgression = filteredExerciseProgressions.find(
    (progression) => progression.exerciseId === expandedExerciseId,
  );
  const effectiveExpandedExerciseId = selectedProgression?.exerciseId ?? '';
  const adherenceValue =
    stats.weekTotalSessions > 0
      ? Math.round(
          (stats.weekCompletedSessions / stats.weekTotalSessions) * 100,
        )
      : 0;
  const visibleInsights = [
    ...stats.warningInsights,
    ...stats.upInsights,
    ...stats.downInsights,
  ].filter(
    (insight) =>
      selectedExerciseFilter === 'all' ||
      insight.exerciseId === selectedExerciseFilter,
  );
  const primarySignals = [
    {
      label: 'Revisar',
      value: String(
        visibleInsights.filter((insight) => insight.tone === 'warning').length,
      ),
      className:
        'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]',
    },
    {
      label: 'Subida',
      value: String(
        visibleInsights.filter((insight) => insight.tone === 'up').length,
      ),
      className:
        'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)]',
    },
    {
      label: 'Bajada',
      value: String(
        visibleInsights.filter((insight) => insight.tone === 'down').length,
      ),
      className:
        'border-[var(--action-down-border)] bg-[var(--action-down)] text-[var(--action-down-foreground)]',
    },
  ];
  const visibleSkippedSets =
    selectedExerciseFilter === 'all'
      ? stats.skippedSets
      : visibleInsights.reduce(
          (total, insight) => total + insight.skippedSets,
          0,
        );
  const visiblePainHits =
    selectedExerciseFilter === 'all'
      ? stats.painHits
      : visibleInsights.reduce((total, insight) => total + insight.painHits, 0);
  const filteredSignalProgressions = filteredExerciseProgressions.filter(
    (progression) => progression.tone !== 'neutral',
  );
  const maintainProgressions = filteredExerciseProgressions.filter(
    (progression) => progression.tone === 'neutral',
  );
  const statisticsSections: {
    section: StatisticsSection;
    title: string;
    detail: string;
    icon: ReactNode;
  }[] = [
    {
      section: 'summary',
      title: 'Resumen',
      detail: `${stats.weekCompletedSessions}/${stats.weekTotalSessions} esta semana`,
      icon: <BarChart3 className="size-5" />,
    },
    {
      section: 'duration',
      title: 'Duración',
      detail:
        filteredAverageDurationMinutes !== undefined
          ? `${formatDurationMinutes(filteredAverageDurationMinutes)} de media`
          : 'Sin sesiones cerradas',
      icon: <History className="size-5" />,
    },
    {
      section: 'volume',
      title: 'Volumen',
      detail: `${filteredVolumeByMuscle.length} grupos`,
      icon: <BarChart3 className="size-5" />,
    },
    {
      section: 'review',
      title: 'Revisión',
      detail: `${filteredSignalProgressions.length} señales activas`,
      icon: <ArrowUpRight className="size-5" />,
    },
    {
      section: 'progression',
      title: 'Progresión',
      detail: `${filteredExerciseProgressions.length} ejercicios`,
      icon: <Equal className="size-5" />,
    },
    {
      section: 'export',
      title: 'Exportar',
      detail: 'CSV de estadísticas',
      icon: <Download className="size-5" />,
    },
  ];
  const showFilters =
    statisticsSection === 'duration' ||
    statisticsSection === 'volume' ||
    statisticsSection === 'review' ||
    statisticsSection === 'progression';
  const showWeekFilter =
    statisticsSection === 'duration' ||
    statisticsSection === 'review' ||
    statisticsSection === 'progression';
  const showTaxonomyFilters =
    statisticsSection === 'volume' ||
    statisticsSection === 'review' ||
    statisticsSection === 'progression';

  if (isLoadingHistory) {
    return (
      <div className="mt-4 rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
        Calculando estadísticas locales...
      </div>
    );
  }

  if (stats.storedSessions === 0) {
    return (
      <div className="mt-4 rounded-[1.75rem] border bg-secondary p-4 text-secondary-foreground">
        <p className="text-base font-black leading-tight">
          Aún no hay sesiones registradas
        </p>
        <p className="mt-1 text-sm font-bold leading-tight text-muted-foreground">
          Cuando completes entrenamientos, aquí aparecerán adherencia, duración
          real y revisión del plan.
        </p>
      </div>
    );
  }

  return (
    <div className="mt-4 grid gap-3">
      <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
        <div className="grid gap-2">
          {statisticsSections.map((item) => (
            <button
              key={item.section}
              className={`flex min-h-14 items-center gap-3 rounded-[1.45rem] border px-3 text-left transition active:scale-[0.98] ${
                statisticsSection === item.section
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-border bg-card text-secondary-foreground'
              }`}
              type="button"
              onClick={() => setStatisticsSection(item.section)}
            >
              <span
                className={`grid size-9 shrink-0 place-items-center rounded-full ${
                  statisticsSection === item.section
                    ? 'bg-primary-foreground text-primary'
                    : 'bg-secondary text-muted-foreground'
                }`}
              >
                {item.icon}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-black leading-tight">
                  {item.title}
                </span>
                <span
                  className={`mt-0.5 block truncate text-xs font-bold leading-tight ${
                    statisticsSection === item.section
                      ? 'text-primary-foreground/75'
                      : 'text-muted-foreground'
                  }`}
                >
                  {item.detail}
                </span>
              </span>
              <ChevronRight className="size-4 shrink-0 opacity-70" />
            </button>
          ))}
        </div>
      </div>

      {showFilters ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <p className="text-sm font-black leading-tight">Filtros</p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {showWeekFilter ? (
              <label className="grid gap-1 text-xs font-black text-muted-foreground">
                Semana
                <NativeSelect
                  className="w-full"
                  value={selectedWeekFilter}
                  onChange={(event) =>
                    setSelectedWeekFilter(event.target.value)
                  }
                >
                  <NativeSelectOption value="all">Todas</NativeSelectOption>
                  {weekOptions.map((weekNumber) => (
                    <NativeSelectOption
                      key={weekNumber}
                      value={String(weekNumber)}
                    >
                      Semana {weekNumber}
                    </NativeSelectOption>
                  ))}
                </NativeSelect>
              </label>
            ) : null}
            <label className="grid gap-1 text-xs font-black text-muted-foreground">
              Ejercicio
              <NativeSelect
                className="w-full"
                value={selectedExerciseFilter}
                onChange={(event) => {
                  setSelectedExerciseFilter(event.target.value);
                  setExpandedExerciseId(
                    event.target.value === 'all' ? '' : event.target.value,
                  );
                }}
              >
                <NativeSelectOption value="all">Todos</NativeSelectOption>
                {exerciseProgressions.map((progression) => (
                  <NativeSelectOption
                    key={progression.exerciseId}
                    value={progression.exerciseId}
                  >
                    {progression.exerciseName}
                  </NativeSelectOption>
                ))}
              </NativeSelect>
            </label>
            {showTaxonomyFilters ? (
              <>
                <label className="grid gap-1 text-xs font-black text-muted-foreground">
                  Bloque
                  <NativeSelect
                    className="w-full"
                    value={selectedTrainingBlockFilter}
                    onChange={(event) =>
                      setSelectedTrainingBlockFilter(event.target.value)
                    }
                  >
                    <NativeSelectOption value="all">Todos</NativeSelectOption>
                    {trainingBlockOptions.map((option) => (
                      <NativeSelectOption key={option} value={option}>
                        {formatTaxonomyLabel(option)}
                      </NativeSelectOption>
                    ))}
                  </NativeSelect>
                </label>
                <label className="grid gap-1 text-xs font-black text-muted-foreground">
                  Patrón
                  <NativeSelect
                    className="w-full"
                    value={selectedMovementPatternFilter}
                    onChange={(event) =>
                      setSelectedMovementPatternFilter(event.target.value)
                    }
                  >
                    <NativeSelectOption value="all">Todos</NativeSelectOption>
                    {movementPatternOptions.map((option) => (
                      <NativeSelectOption key={option} value={option}>
                        {formatTaxonomyLabel(option)}
                      </NativeSelectOption>
                    ))}
                  </NativeSelect>
                </label>
                <label className="grid gap-1 text-xs font-black text-muted-foreground">
                  Músculo
                  <NativeSelect
                    className="w-full"
                    value={selectedMuscleFilter}
                    onChange={(event) =>
                      setSelectedMuscleFilter(event.target.value)
                    }
                  >
                    <NativeSelectOption value="all">Todos</NativeSelectOption>
                    {muscleOptions.map((option) => (
                      <NativeSelectOption key={option} value={option}>
                        {formatTaxonomyLabel(option)}
                      </NativeSelectOption>
                    ))}
                  </NativeSelect>
                </label>
              </>
            ) : null}
          </div>
        </div>
      ) : null}

      {statisticsSection === 'summary' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-sm font-bold leading-tight text-muted-foreground">
                Semana {stats.weekNumber}
              </p>
              <p className="mt-0.5 truncate text-base font-black leading-tight">
                {stats.weekFocusLabel}
              </p>
            </div>
            <span className="shrink-0 rounded-full border bg-card px-3 py-1 text-xs font-black text-muted-foreground">
              {adherenceValue}%
            </span>
          </div>
          <div className="mt-3 grid grid-cols-3 gap-2 text-center">
            <Metric
              label="Semana"
              value={`${stats.weekCompletedSessions}/${stats.weekTotalSessions}`}
            />
            <Metric label="Guardadas" value={String(stats.storedSessions)} />
            <Metric label="Completas" value={String(stats.completedSessions)} />
          </div>
        </div>
      ) : null}

      {statisticsSection === 'duration' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <p className="text-sm font-black leading-tight">Duración real</p>
          <div className="mt-3 grid grid-cols-2 gap-2 text-center">
            <Metric
              label="Media"
              value={
                filteredAverageDurationMinutes
                  ? formatDurationMinutes(filteredAverageDurationMinutes)
                  : '-'
              }
            />
            <Metric
              label="Diferencia"
              value={
                filteredAverageDeltaMinutes !== undefined
                  ? formatSignedMinutes(filteredAverageDeltaMinutes)
                  : '-'
              }
            />
          </div>
          <div className="mt-2 grid gap-1.5">
            <DurationChart data={durationChartData} />
            {filteredDurationSamples.slice(0, 3).map((sample) => (
              <div
                key={sample.sessionId}
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-[1rem] border bg-card px-3 py-2 text-xs font-bold"
              >
                <span className="truncate">{sample.label}</span>
                <span className="tabular-nums text-muted-foreground">
                  {formatDurationMinutes(sample.actualMinutes)} ·{' '}
                  {formatSignedMinutes(sample.deltaMinutes)}
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {statisticsSection === 'volume' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm font-black leading-tight">
              Volumen acumulado
            </p>
            <span className="shrink-0 rounded-full border bg-card px-2.5 py-1 text-xs font-black text-muted-foreground">
              {filteredVolumeByExercise.length} ejercicios
            </span>
          </div>
          <p className="mt-1 text-xs font-bold leading-tight text-muted-foreground">
            Calculado desde series completadas. La carga de mancuernas cuenta
            ambas manos; peso corporal y planchas suman reps o tiempo.
          </p>
          <div className="mt-3 grid gap-2">
            {filteredVolumeByMuscle.length === 0 ? (
              <div className="rounded-[1.1rem] border bg-card px-3 py-2 text-xs font-bold text-muted-foreground">
                Sin volumen para este filtro.
              </div>
            ) : null}
            {filteredVolumeByMuscle.slice(0, 8).map((summary) => (
              <VolumeRow
                key={summary.muscle}
                title={formatTaxonomyLabel(summary.muscle)}
                subtitle={`${summary.completedSets} series · ${summary.totalReps} reps`}
                value={formatVolumeValue(summary.totalLoadVolumeKg)}
              />
            ))}
          </div>
          <div className="mt-3 grid gap-2">
            <p className="text-xs font-black leading-tight text-muted-foreground">
              Por ejercicio
            </p>
            {filteredVolumeByExercise.slice(0, 8).map((summary) => (
              <VolumeRow
                key={summary.exerciseId}
                title={summary.exerciseName}
                subtitle={[
                  summary.primaryMuscles.map(formatTaxonomyLabel).join(', '),
                  `${summary.completedSets} series`,
                  summary.totalDurationSeconds > 0
                    ? `${summary.totalDurationSeconds}s`
                    : `${summary.totalReps} reps`,
                ]
                  .filter(Boolean)
                  .join(' · ')}
                value={formatVolumeValue(summary.totalLoadVolumeKg)}
              />
            ))}
          </div>
        </div>
      ) : null}

      {statisticsSection === 'review' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm font-black leading-tight">
              Revisión del plan
            </p>
            <span className="shrink-0 rounded-full border bg-card px-2.5 py-1 text-xs font-black text-muted-foreground">
              {filteredSignalProgressions.length} señales
            </span>
          </div>
          <p className="mt-1 text-xs font-bold leading-tight text-muted-foreground">
            Señales calculadas desde datos reales. La decisión manual aparece al
            abrir cada ejercicio. No modifican el plan automáticamente.
          </p>
          <div className="mt-3 grid grid-cols-3 gap-2 text-center">
            {primarySignals.map((signal) => (
              <div
                key={signal.label}
                className={`flex h-16 min-w-0 flex-col items-center justify-center rounded-[1.1rem] border px-2 ${signal.className}`}
              >
                <p className="text-xs font-bold leading-none opacity-80">
                  {signal.label}
                </p>
                <p className="mt-1 max-w-full text-center text-lg font-black leading-tight">
                  {signal.value}
                </p>
              </div>
            ))}
          </div>
          <div className="mt-2 grid grid-cols-2 gap-2 text-xs font-black">
            <div className="rounded-[1rem] border bg-card px-3 py-2">
              <span className="block text-muted-foreground">Saltadas</span>
              <span className="mt-0.5 block">{visibleSkippedSets} series</span>
            </div>
            <div className="rounded-[1rem] border bg-card px-3 py-2">
              <span className="block text-muted-foreground">Molestias</span>
              <span className="mt-0.5 block">{visiblePainHits} marcas</span>
            </div>
          </div>
          <div className="mt-3 grid gap-2">
            {filteredSignalProgressions.length === 0 ? (
              <div className="rounded-[1.1rem] border bg-card px-3 py-2 text-xs font-bold text-muted-foreground">
                No hay señales activas para este filtro.
              </div>
            ) : null}
            {filteredSignalProgressions.map((progression) => (
              <PlanSignalRow
                key={progression.exerciseId}
                progression={progression}
              />
            ))}
            {maintainProgressions.length > 0 ? (
              <div className="rounded-[1.1rem] border border-[var(--signal-maintain-border)] bg-[var(--signal-maintain)] px-3 py-2 text-xs font-black text-[var(--signal-maintain-foreground)]">
                {maintainProgressions.length} ejercicios sin señal de cambio.
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {statisticsSection === 'progression' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm font-black leading-tight">
              Progresión por ejercicio
            </p>
            <span className="shrink-0 rounded-full border bg-card px-2.5 py-1 text-xs font-black text-muted-foreground">
              {filteredExerciseProgressions.length}
            </span>
          </div>
          {filteredExerciseProgressions.length > 0 ? (
            <div className="mt-3 grid gap-2">
              {filteredExerciseProgressions.map((progression) => (
                <ExerciseProgressionCard
                  key={progression.exerciseId}
                  progression={progression}
                  isExpanded={
                    progression.exerciseId === effectiveExpandedExerciseId
                  }
                  onToggle={() =>
                    setExpandedExerciseId(
                      progression.exerciseId === effectiveExpandedExerciseId
                        ? ''
                        : progression.exerciseId,
                    )
                  }
                />
              ))}
            </div>
          ) : (
            <div className="mt-3 rounded-[1rem] border bg-card px-3 py-2 text-xs font-bold text-muted-foreground">
              Sin progresión para este filtro.
            </div>
          )}
        </div>
      ) : null}

      {statisticsSection === 'summary' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <p className="text-sm font-black leading-tight">Últimas sesiones</p>
          <div className="mt-2 grid gap-1.5">
            {filteredHistory.length === 0 ? (
              <div className="rounded-[1rem] border bg-card px-3 py-2 text-xs font-bold text-muted-foreground">
                Sin sesiones para este filtro.
              </div>
            ) : null}
            {filteredHistory.slice(0, 3).map((summary) => {
              const durationMinutes = getDurationMinutes(
                summary.startedAt,
                summary.finishedAt,
              );

              return (
                <div
                  key={summary.sessionId}
                  className="rounded-[1rem] border bg-card px-3 py-2 text-xs font-bold"
                >
                  <div className="flex min-w-0 items-center justify-between gap-3">
                    <span className="truncate">{summary.sessionLabel}</span>
                    <span className="shrink-0 text-muted-foreground">
                      {formatDate(summary.sessionDate)}
                    </span>
                  </div>
                  <div className="mt-1 flex min-w-0 items-center justify-between gap-3 text-muted-foreground">
                    <span>
                      {summary.attemptedSets}/{summary.totalSets} series
                    </span>
                    <span>
                      {durationMinutes
                        ? formatDurationMinutes(durationMinutes)
                        : 'sin cerrar'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ) : null}

      {statisticsSection === 'export' ? (
        <div className="min-w-0 overflow-hidden rounded-[1.75rem] border bg-secondary p-3 text-secondary-foreground">
          <p className="text-sm font-black leading-tight">Exportar datos</p>
          <p className="mt-1 text-xs font-bold leading-tight text-muted-foreground">
            Genera un CSV derivado con resumen, historial, señales y progresión.
            El backup completo sigue en Datos locales.
          </p>
          <Button
            className="mt-3 h-14 w-full rounded-[1.75rem] text-base font-black"
            onClick={onExportStatisticsCsv}
          >
            Exportar estadísticas CSV
            <Download className="size-5" />
          </Button>
        </div>
      ) : null}
    </div>
  );
}

type DurationChartPoint = {
  sessionId: string;
  date: string;
  shortDate: string;
  label: string;
  actualMinutes: number;
  estimatedMinutes: number;
  deltaMinutes: number;
};

function formatTaxonomyLabel(value: string) {
  return value
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function formatVolumeValue(value: number) {
  if (value <= 0) {
    return 'sin kg';
  }

  return `${Math.round(value).toLocaleString('es-ES')} kg`;
}

function VolumeRow({
  title,
  subtitle,
  value,
}: {
  title: string;
  subtitle: string;
  value: string;
}) {
  return (
    <div className="grid min-w-0 grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-[1.1rem] border bg-card px-3 py-2">
      <div className="min-w-0">
        <p className="truncate text-sm font-black leading-tight">{title}</p>
        <p className="mt-0.5 truncate text-xs font-bold leading-tight text-muted-foreground">
          {subtitle}
        </p>
      </div>
      <span className="shrink-0 rounded-full border bg-secondary px-2.5 py-1 text-xs font-black tabular-nums text-secondary-foreground">
        {value}
      </span>
    </div>
  );
}

function DurationChart({ data }: { data: DurationChartPoint[] }) {
  if (data.length < 2) {
    return (
      <div className="rounded-[1.2rem] border bg-card p-2">
        <div className="mb-1 flex items-center justify-between gap-3 px-1">
          <span className="text-xs font-black leading-tight">
            Real vs estimado
          </span>
          <span className="text-xs font-bold leading-tight text-muted-foreground">
            min
          </span>
        </div>
        <div className="grid h-40 place-items-center rounded-[1rem] border border-dashed bg-secondary/60 px-4 text-center text-xs font-bold leading-tight text-muted-foreground">
          {data.length === 1
            ? 'Hay una sesión cerrada. Falta otra para dibujar tendencia.'
            : 'Cierra al menos dos sesiones para ver la comparativa.'}
        </div>
      </div>
    );
  }

  const width = 320;
  const height = 148;
  const padding = { top: 14, right: 12, bottom: 26, left: 30 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const values = data.flatMap((point) => [
    point.actualMinutes,
    point.estimatedMinutes,
  ]);
  const minValue = Math.min(...values);
  const maxValue = Math.max(...values);
  const domainPadding = Math.max(5, Math.round((maxValue - minValue) * 0.25));
  const domainMin = Math.max(0, minValue - domainPadding);
  const domainMax = maxValue + domainPadding;
  const yRange = Math.max(1, domainMax - domainMin);
  const toX = (index: number) =>
    padding.left +
    (data.length === 1
      ? plotWidth / 2
      : (index / (data.length - 1)) * plotWidth);
  const toY = (value: number) =>
    padding.top + plotHeight - ((value - domainMin) / yRange) * plotHeight;
  const toPath = (key: 'actualMinutes' | 'estimatedMinutes') =>
    data
      .map((point, index) => {
        const command = index === 0 ? 'M' : 'L';
        return `${command} ${toX(index).toFixed(1)} ${toY(point[key]).toFixed(
          1,
        )}`;
      })
      .join(' ');
  const gridValues = [
    domainMax,
    Math.round((domainMax + domainMin) / 2),
    domainMin,
  ];

  return (
    <div className="rounded-[1.2rem] border bg-card p-2">
      <div className="mb-1 flex items-center justify-between gap-3 px-1">
        <span className="text-xs font-black leading-tight">
          Real vs estimado
        </span>
        <span className="text-xs font-bold leading-tight text-muted-foreground">
          min
        </span>
      </div>
      <svg
        className="h-40 w-full overflow-visible"
        viewBox={`0 0 ${width} ${height}`}
        aria-labelledby="duration-chart-title"
      >
        <title id="duration-chart-title">
          Duración real comparada con duración estimada
        </title>
        {gridValues.map((value) => {
          const y = toY(value);

          return (
            <g key={value}>
              <line
                x1={padding.left}
                x2={width - padding.right}
                y1={y}
                y2={y}
                className="stroke-border"
                strokeDasharray="3 4"
              />
              <text
                x={padding.left - 6}
                y={y + 3}
                textAnchor="end"
                className="fill-muted-foreground text-[9px] font-bold"
              >
                {value}
              </text>
            </g>
          );
        })}
        <path
          d={toPath('estimatedMinutes')}
          fill="none"
          className="stroke-[var(--chart-2)]"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray="5 5"
        />
        <path
          d={toPath('actualMinutes')}
          fill="none"
          className="stroke-[var(--chart-1)]"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {data.map((point, index) => (
          <g key={point.sessionId}>
            <circle
              cx={toX(index)}
              cy={toY(point.estimatedMinutes)}
              r="3"
              className="fill-card stroke-[var(--chart-2)]"
              strokeWidth="2"
            >
              <title>
                {point.label}: estimado {point.estimatedMinutes} min
              </title>
            </circle>
            <circle
              cx={toX(index)}
              cy={toY(point.actualMinutes)}
              r="3.5"
              className="fill-[var(--chart-1)]"
            >
              <title>
                {point.label}: real {point.actualMinutes} min,{' '}
                {formatSignedMinutes(point.deltaMinutes)}
              </title>
            </circle>
            <text
              x={toX(index)}
              y={height - 8}
              textAnchor="middle"
              className="fill-muted-foreground text-[9px] font-bold"
            >
              {point.shortDate}
            </text>
          </g>
        ))}
      </svg>
      <div
        className="mt-1 flex items-center justify-center gap-4 text-xs font-bold text-muted-foreground"
        aria-hidden="true"
      >
        <span className="inline-flex items-center gap-1.5">
          <span className="h-1 w-4 rounded-full bg-[var(--chart-1)]" />
          Real
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span
            className="h-1 w-4 rounded-full bg-[var(--chart-2)] opacity-75"
            style={{
              backgroundImage:
                'repeating-linear-gradient(90deg, transparent 0 4px, var(--card) 4px 7px)',
            }}
          />
          Estimado
        </span>
      </div>
    </div>
  );
}

function PlanSignalRow({
  progression,
}: {
  progression: ExerciseProgressionSummary;
}) {
  const nextLabel = progression.nextDate
    ? formatDate(progression.nextDate)
    : 'sin fecha';

  return (
    <div
      className={`min-w-0 overflow-hidden rounded-[1.1rem] border px-3 py-2 text-xs font-bold leading-tight ${getProgressionRecommendationToneClassName(
        progression.tone,
        progression.recommendation,
      )}`}
    >
      <div className="grid min-w-0 gap-0.5">
        <span className="min-w-0 truncate text-sm font-black">
          {progression.exerciseName}
        </span>
        <span className="min-w-0 truncate opacity-75">{nextLabel}</span>
      </div>
      <div className="mt-1 grid min-w-0 gap-0.5">
        <span className="min-w-0 truncate opacity-80">
          {progression.recommendation}
        </span>
        <span className="min-w-0 truncate opacity-75">
          {progression.lastDecision ?? 'sin decisión'}
        </span>
      </div>
    </div>
  );
}

function ExerciseProgressionCard({
  progression,
  isExpanded,
  onToggle,
}: {
  progression: ExerciseProgressionSummary;
  isExpanded: boolean;
  onToggle: () => void;
}) {
  const nextLabel = progression.nextDate
    ? `Próx. ${formatDate(progression.nextDate)}`
    : 'Sin próxima exposición';

  return (
    <div className="grid gap-2">
      <button
        className={`rounded-[1.4rem] border px-3 py-2.5 text-left transition active:scale-[0.98] ${getProgressionCardToneClassName(
          progression.tone,
          isExpanded,
          progression.recommendation,
        )}`}
        type="button"
        aria-label={`${isExpanded ? 'Cerrar' : 'Ver'} progresión de ${
          progression.exerciseName
        }`}
        onClick={onToggle}
      >
        <span className="grid min-w-0 gap-0.5">
          <span className="min-w-0">
            <span className="block truncate text-[0.95rem] font-black leading-tight">
              {progression.exerciseName}
            </span>
            <span
              className={`mt-0.5 block truncate text-xs font-bold leading-tight ${
                isExpanded ? 'text-primary-foreground/80' : 'opacity-75'
              }`}
            >
              {[nextLabel, progression.nextSessionLabel, progression.target]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </span>
        </span>
      </button>

      {isExpanded ? (
        <div className="grid gap-1.5 rounded-[1.5rem] border bg-secondary p-2">
          <ProgressionReviewSummary progression={progression} />
          <div className="grid gap-1.5">
            <div className="rounded-[1.1rem] border bg-card px-3 py-2 leading-tight text-secondary-foreground">
              <span className="block text-[0.65rem] font-black uppercase text-muted-foreground">
                Tu decisión
              </span>
              <span className="mt-0.5 block text-sm font-black">
                {progression.lastDecision ?? 'Sin decisión'}
              </span>
            </div>
            <div
              className={`rounded-[1.1rem] border px-3 py-2 leading-tight ${getProgressionRecommendationToneClassName(
                progression.tone,
                progression.recommendation,
              )}`}
            >
              <span className="block text-[0.65rem] font-black uppercase opacity-75">
                Señal de la app
              </span>
              <span className="mt-0.5 block text-sm font-black">
                {progression.recommendation}
              </span>
            </div>
          </div>
          {progression.exposures.slice(0, 4).map((exposure) => (
            <ExerciseProgressionExposureCard
              key={exposure.sessionId}
              exposure={exposure}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

function ProgressionReviewSummary({
  progression,
}: {
  progression: ExerciseProgressionSummary;
}) {
  const lastExposure = progression.exposures[0];

  if (!lastExposure) {
    return (
      <div className="rounded-[1.1rem] border bg-card px-3 py-2 text-xs font-bold leading-tight text-muted-foreground">
        Sin exposiciones registradas para este filtro.
      </div>
    );
  }

  const loadLabel =
    lastExposure.topLoadKg !== undefined
      ? `${formatCsvNumber(lastExposure.topLoadKg)} kg`
      : '-';
  const workLabel =
    lastExposure.totalDurationSeconds > 0
      ? formatClock(lastExposure.totalDurationSeconds)
      : `${lastExposure.totalReps} reps`;
  const equipmentLabel =
    formatEquipmentLabel(
      lastExposure.actualEquipment ?? lastExposure.plannedEquipment,
    ) ?? 'Material no registrado';

  return (
    <div className="rounded-[1.1rem] border bg-card px-3 py-2 leading-tight text-secondary-foreground">
      <span className="block text-[0.65rem] font-black uppercase text-muted-foreground">
        Último registro
      </span>
      <span className="mt-0.5 block text-sm font-black">
        {formatDate(lastExposure.sessionDate)} · {equipmentLabel}
      </span>
      <span className="mt-1 block text-xs font-bold text-muted-foreground">
        {loadLabel} · {workLabel} · {lastExposure.completedSets}/
        {lastExposure.plannedSets} series
      </span>
    </div>
  );
}

function ExerciseProgressionExposureCard({
  exposure,
}: {
  exposure: ExerciseProgressionSummary['exposures'][number];
}) {
  const loadLabel =
    exposure.topLoadKg !== undefined
      ? `${formatCsvNumber(exposure.topLoadKg)} kg`
      : '-';
  const workLabel =
    exposure.totalDurationSeconds > 0
      ? formatClock(exposure.totalDurationSeconds)
      : `${exposure.totalReps} reps`;
  const rirLabel =
    exposure.averageRir !== undefined
      ? `RIR ${formatDecimal(exposure.averageRir)}`
      : 'RIR -';
  const detailParts = [
    formatEquipmentLabel(exposure.actualEquipment ?? exposure.plannedEquipment),
    `${exposure.completedSets}/${exposure.plannedSets} series`,
    exposure.skippedSets > 0 ? `${exposure.skippedSets} saltadas` : undefined,
    exposure.painHits > 0 ? `${exposure.painHits} molestias` : undefined,
    exposure.decision,
  ].filter(Boolean);

  return (
    <div className="rounded-[1.2rem] border bg-card p-3 text-xs font-bold">
      <div className="flex min-w-0 items-center justify-between gap-3">
        <span className="truncate text-sm font-black">
          {formatDate(exposure.sessionDate)}
        </span>
        <span className="min-w-0 max-w-[11rem] truncate text-right text-muted-foreground">
          {exposure.sessionLabel}
        </span>
      </div>
      <div className="mt-2 grid grid-cols-3 gap-2 text-center">
        <Metric label="Peso" value={loadLabel} />
        <Metric label="Trabajo" value={workLabel} />
        <Metric label="Esfuerzo" value={rirLabel} />
      </div>
      <p className="mt-2 overflow-hidden leading-tight text-muted-foreground [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
        {detailParts.join(' · ')}
      </p>
    </div>
  );
}

function HistorySessionCard({
  summary,
  onExportHistorySession,
  onDeleteHistorySession,
}: {
  summary: SessionHistorySummary;
  onExportHistorySession: (sessionId: string) => void;
  onDeleteHistorySession: (sessionId: string) => void;
}) {
  const isComplete =
    Boolean(summary.finishedAt) || summary.attemptedSets >= summary.totalSets;
  const statusLabel = summary.exportedAt
    ? 'Exportado'
    : isComplete
      ? 'Completo'
      : 'En curso';
  const durationMinutes = getDurationMinutes(
    summary.startedAt,
    summary.finishedAt,
  );
  const detailParts = [
    formatDate(summary.sessionDate),
    `${summary.attemptedSets}/${summary.totalSets} series`,
    `est. ${summary.derivedEstimatedMinutes}m`,
    durationMinutes ? formatDurationMinutes(durationMinutes) : undefined,
  ].filter(Boolean);

  return (
    <div className="rounded-[1.4rem] border bg-secondary p-3 text-secondary-foreground">
      <div className="flex min-w-0 items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-sm font-black">{summary.sessionLabel}</p>
          <p className="mt-0.5 text-xs font-bold text-muted-foreground">
            {detailParts.join(' · ')}
          </p>
        </div>
        <span className="shrink-0 rounded-full border bg-card px-2.5 py-1 text-xs font-black text-muted-foreground">
          {statusLabel}
        </span>
      </div>
      <div className="mt-3 grid grid-cols-[minmax(0,1fr)_48px] gap-2">
        <Button
          className="h-11 rounded-[1.4rem] font-black"
          onClick={() => onExportHistorySession(summary.sessionId)}
        >
          Exportar CSV
          <Download className="size-4" />
        </Button>
        <Button
          aria-label={`Borrar ${summary.sessionLabel}`}
          className={`h-11 w-12 rounded-[1.4rem] p-0 ${actionStyles.delete}`}
          variant="outline"
          onClick={() => onDeleteHistorySession(summary.sessionId)}
        >
          <Trash2 className="size-4" />
        </Button>
      </div>
    </div>
  );
}

function SetScreen({
  exerciseName,
  exerciseNotes,
  setIndex,
  totalExerciseSets,
  supersetPosition,
  supersetSize,
  supersetRound,
  supersetRoundCount,
  nextLinkedExerciseName,
  completedSetIndexes,
  setType,
  reps,
  weight,
  loadType,
  equipment,
  equipmentOptions,
  durationSeconds,
  timerRemaining,
  isTimerRunning,
  restSeconds,
  onEdit,
  onTimerToggle,
  onTimerReset,
  onContinue,
  onSkip,
  onBack,
  onEquipmentChange,
  isRegistering,
  saveStatus,
}: {
  exerciseName: string;
  exerciseNotes: string;
  setIndex: number;
  totalExerciseSets: number;
  supersetPosition?: number | undefined;
  supersetSize?: number | undefined;
  supersetRound?: number | undefined;
  supersetRoundCount?: number | undefined;
  nextLinkedExerciseName?: string | undefined;
  completedSetIndexes: number[];
  setType: TrainingSet['type'];
  reps: number;
  weight: number;
  loadType: LoadType;
  equipment?: ExerciseEquipment;
  equipmentOptions: ExerciseEquipment[];
  durationSeconds: number;
  timerRemaining: number;
  isTimerRunning: boolean;
  restSeconds: number;
  onEdit: () => void;
  onTimerToggle: () => void;
  onTimerReset: () => void;
  onContinue: () => void;
  onSkip: () => void;
  onBack: () => void;
  onEquipmentChange: (equipment: ExerciseEquipment) => void;
  isRegistering: boolean;
  saveStatus: SaveStatus;
}) {
  const isTimed = setType === 'timed';
  const isSuperset =
    supersetPosition !== undefined &&
    supersetSize !== undefined &&
    supersetRound !== undefined &&
    supersetRoundCount !== undefined;

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
      <div className="flex shrink-0 items-center justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-1.5 text-sm font-semibold text-muted-foreground">
            <span>
              Serie {setIndex + 1} de {totalExerciseSets}
            </span>
            {isSuperset ? (
              <span className="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-black text-primary">
                Superserie {supersetPosition}/{supersetSize}
              </span>
            ) : null}
            <SaveStatusPill status={saveStatus} />
          </div>
          <h2 className="text-[1.65rem] font-black leading-tight tracking-normal">
            {exerciseName}
          </h2>
          {isSuperset ? (
            <p className="mt-1 truncate text-sm font-semibold text-muted-foreground">
              Ronda {supersetRound}/{supersetRoundCount}
              {nextLinkedExerciseName
                ? ` · Sigue: ${nextLinkedExerciseName}`
                : ' · Después, descanso'}
            </p>
          ) : null}
        </div>
        <div className="flex gap-1.5" aria-label="Progreso de series">
          {Array.from({ length: totalExerciseSets }).map((_, index) => {
            const filled = completedSetIndexes.includes(index);
            const active = index === setIndex;
            return (
              <span
                key={index}
                className={`size-4 rounded-full border-2 ${
                  filled
                    ? 'border-primary bg-primary'
                    : active
                      ? 'border-primary bg-transparent'
                      : 'border-muted-foreground/35 bg-transparent'
                }`}
              />
            );
          })}
        </div>
      </div>

      {!isTimed && equipment && equipmentOptions.length > 1 ? (
        <EquipmentSelector
          options={equipmentOptions}
          value={equipment}
          onChange={onEquipmentChange}
        />
      ) : null}

      {isTimed ? (
        <TimedSetPanel
          durationSeconds={durationSeconds}
          isRunning={isTimerRunning}
          remainingSeconds={timerRemaining}
          onReset={onTimerReset}
          onToggle={onTimerToggle}
        />
      ) : (
        <div className="grid min-h-0 flex-1 grid-rows-2 gap-2">
          <TappableNumber
            label="Reps"
            value={String(reps)}
            hint="Toca para ajustar"
            onClick={onEdit}
          />
          <TappableNumber
            label="Peso"
            value={formatWeight(weight)}
            hint={getPreviewLoadLabel(loadType, equipment)}
            onClick={onEdit}
          />
        </div>
      )}

      <div className="shrink-0 rounded-lg bg-secondary px-4 py-2.5 text-sm font-medium text-secondary-foreground">
        <span className="block overflow-hidden [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {exerciseNotes}
        </span>
        <span className="mt-1 block text-sm text-muted-foreground">
          Descanso propuesto: {restSeconds}s
        </span>
      </div>

      <div
        className="grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '64px minmax(0, 1fr) 64px' }}
      >
        <Button
          aria-label="Ir a pantalla principal"
          className={`h-16 w-16 shrink-0 rounded-[1.9rem] p-0 ${actionStyles.back}`}
          style={{ width: '64px' }}
          variant="outline"
          onClick={onBack}
        >
          <House className="size-5" />
        </Button>
        <Button
          className="h-16 rounded-[1.9rem] text-lg font-black"
          onClick={onContinue}
        >
          Continuar
          <ChevronRight className="size-6" />
        </Button>
        <Button
          aria-label="Saltar serie"
          className={`h-16 w-16 shrink-0 rounded-[1.9rem] p-0 ${actionStyles.skip}`}
          style={{ width: '64px' }}
          variant="outline"
          onClick={onSkip}
          disabled={isRegistering}
        >
          <SkipSetIcon className="size-6" />
        </Button>
      </div>
    </section>
  );
}

function TimedSetPanel({
  durationSeconds,
  remainingSeconds,
  isRunning,
  onToggle,
  onReset,
}: {
  durationSeconds: number;
  remainingSeconds: number;
  isRunning: boolean;
  onToggle: () => void;
  onReset: () => void;
}) {
  const isFinished = remainingSeconds === 0;

  return (
    <div
      className={`flex min-h-0 flex-1 flex-col items-center justify-center rounded-lg border p-4 shadow-sm transition-colors ${
        isFinished
          ? 'border-[var(--complete-border)] bg-[var(--complete)] text-[var(--complete-foreground)]'
          : 'bg-card'
      }`}
    >
      <p
        className={`text-base font-black ${
          isFinished
            ? 'text-[var(--complete-foreground)]'
            : 'text-muted-foreground'
        }`}
      >
        {isFinished ? 'Ejercicio terminado' : 'Tiempo'}
      </p>
      <CountdownCircle
        label="Tiempo de serie"
        remainingSeconds={remainingSeconds}
        totalSeconds={durationSeconds}
        sizeClassName="my-4 size-52"
        textClassName="text-[4.5rem]"
        isFinished={isFinished}
      />
      <div
        className="grid w-full gap-3"
        style={{ gridTemplateColumns: '56px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Reiniciar timer"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.reset}`}
          style={{ width: '56px' }}
          variant="secondary"
          onClick={onReset}
        >
          <RotateCcw className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          onClick={onToggle}
        >
          {isRunning ? (
            <>
              Pausar
              <Pause className="size-5" />
            </>
          ) : (
            <>
              {isFinished ? 'Repetir' : 'Iniciar'}
              <Play className="size-5" />
            </>
          )}
        </Button>
      </div>
    </div>
  );
}

function CountdownCircle({
  label,
  remainingSeconds,
  totalSeconds,
  sizeClassName,
  textClassName,
  isFinished = false,
}: {
  label: string;
  remainingSeconds: number;
  totalSeconds: number;
  sizeClassName: string;
  textClassName: string;
  isFinished?: boolean;
}) {
  const radius = 46;
  const circumference = 2 * Math.PI * radius;
  const progress =
    totalSeconds > 0
      ? Math.min(1, Math.max(0, remainingSeconds / totalSeconds))
      : 0;
  const dashOffset = circumference * (1 - progress);

  return (
    <div
      className={`relative grid place-items-center ${sizeClassName}`}
      aria-label={`${label}: ${formatClock(remainingSeconds)}`}
    >
      <svg
        className="absolute inset-0 size-full -rotate-90"
        viewBox="0 0 100 100"
        aria-hidden="true"
      >
        <circle
          className="stroke-border"
          cx="50"
          cy="50"
          r={radius}
          fill="none"
          strokeWidth="6"
        />
        <circle
          className={`transition-[stroke-dashoffset] duration-300 ease-linear ${
            isFinished ? 'stroke-[var(--complete-border)]' : 'stroke-primary'
          }`}
          cx="50"
          cy="50"
          r={radius}
          fill="none"
          strokeLinecap="round"
          strokeWidth="6"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
        />
      </svg>
      <span
        className={`${textClassName} z-10 font-black leading-none tabular-nums tracking-normal`}
      >
        {formatClock(remainingSeconds)}
      </span>
    </div>
  );
}

function SaveStatusPill({
  status,
  className = '',
}: {
  status: SaveStatus;
  className?: string;
}) {
  if (status === 'idle') {
    return null;
  }

  const isSaved = status === 'saved';

  return (
    <span
      className={`inline-flex h-7 items-center justify-center gap-1 rounded-full border px-2.5 text-xs font-black ${
        isSaved
          ? 'border-[var(--complete-border)] bg-[var(--complete)] text-[var(--complete-foreground)]'
          : 'border-primary bg-primary text-primary-foreground'
      } ${className}`}
    >
      {isSaved ? <Check className="size-3.5" /> : null}
      {isSaved ? 'Guardado' : 'Guardando'}
    </span>
  );
}

function RestScreen({
  restRemaining,
  restTotal,
  nextLabel,
  nextSetPreview,
  saveStatus,
  onAdjustRest,
  onContinue,
}: {
  restRemaining: number;
  restTotal: number;
  nextLabel: string;
  nextSetPreview?: NextSetPreview;
  saveStatus: SaveStatus;
  onAdjustRest: (value: number | ((current: number) => number)) => void;
  onContinue: () => void;
}) {
  const isFinished = restRemaining === 0;

  return (
    <section className="flex flex-1 flex-col justify-between gap-3 py-2">
      <div
        className={`rounded-lg border p-3 text-center shadow-sm transition-colors ${
          isFinished
            ? 'border-[var(--complete-border)] bg-[var(--complete)] text-[var(--complete-foreground)]'
            : 'border-transparent bg-transparent'
        }`}
      >
        <p
          className={`text-lg font-bold ${
            isFinished
              ? 'text-[var(--complete-foreground)]'
              : 'text-muted-foreground'
          }`}
        >
          {isFinished ? 'Descanso terminado' : 'Descanso'}
        </p>
        <CountdownCircle
          label="Descanso"
          remainingSeconds={restRemaining}
          totalSeconds={Math.max(restTotal, restRemaining)}
          sizeClassName="mx-auto mt-3 size-56"
          textClassName="text-[4.5rem]"
          isFinished={isFinished}
        />
        {!nextSetPreview ? (
          <p className="mt-3 text-lg font-bold">Siguiente: {nextLabel}</p>
        ) : null}
      </div>

      {nextSetPreview ? (
        <div className="rounded-lg border bg-card p-3">
          <div className="mb-2 flex items-center justify-between gap-3">
            <p className="text-sm font-black leading-none text-muted-foreground">
              {nextSetPreview.exerciseName}
            </p>
            <SaveStatusPill status={saveStatus} />
          </div>
          <div className="mt-2 grid grid-cols-3 gap-2">
            <PreviewMetric label="serie" value={nextSetPreview.series} />
            <PreviewMetric
              label={nextSetPreview.workLabel}
              value={nextSetPreview.work}
            />
            <PreviewMetric
              label={nextSetPreview.loadLabel}
              value={nextSetPreview.load}
            />
          </div>
        </div>
      ) : null}

      <div className="grid grid-cols-3 gap-2">
        <Button
          className={`h-16 rounded-[1.9rem] text-lg font-black ${actionStyles.rest}`}
          variant="secondary"
          onClick={() => onAdjustRest((value) => Math.max(0, value - 15))}
        >
          -15s
        </Button>
        <Button
          className="h-16 rounded-[1.9rem] text-lg font-black"
          onClick={onContinue}
        >
          Seguir
        </Button>
        <Button
          className={`h-16 rounded-[1.9rem] text-lg font-black ${actionStyles.rest}`}
          variant="secondary"
          onClick={() => onAdjustRest((value) => value + 15)}
        >
          +15s
        </Button>
      </div>
    </section>
  );
}

function FeedbackScreen({
  exerciseName,
  setType,
  reps,
  weight,
  durationSeconds,
  rir,
  painKnee,
  painWrist,
  painShoulder,
  painLowerBack,
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onPainShoulderChange,
  onPainLowerBackChange,
  onSetNoteChange,
  onBack,
  onRegister,
  isRegistering,
  saveStatus,
}: {
  exerciseName: string;
  setType: TrainingSet['type'];
  reps: number;
  weight: number;
  durationSeconds?: number;
  rir: number;
  painKnee: number;
  painWrist: number;
  painShoulder: number;
  painLowerBack: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onPainShoulderChange: (value: number) => void;
  onPainLowerBackChange: (value: number) => void;
  onSetNoteChange: (value: string) => void;
  onBack: () => void;
  onRegister: () => void;
  isRegistering: boolean;
  saveStatus: SaveStatus;
}) {
  const isTimed = setType === 'timed';

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
      <div>
        <p className="text-sm font-semibold text-muted-foreground">
          Feedback serie
        </p>
        <h2 className="text-[1.75rem] font-black leading-tight tracking-normal">
          {exerciseName}
        </h2>
      </div>

      {isTimed ? (
        <div className="rounded-lg border bg-card px-3 py-3 text-center">
          <p className="text-sm font-black text-muted-foreground">Tiempo</p>
          <p className="text-5xl font-black leading-none">
            {formatClock(durationSeconds ?? 0)}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-2 text-center">
          <div className="rounded-lg border bg-card px-3 py-2">
            <p className="text-sm font-black text-muted-foreground">Reps</p>
            <p className="text-[2rem] font-black leading-none">{reps}</p>
          </div>
          <div className="rounded-lg border bg-card px-3 py-2">
            <p className="text-sm font-black text-muted-foreground">Peso</p>
            <p className="text-[1.85rem] font-black leading-none">
              {formatWeight(weight)}
            </p>
          </div>
        </div>
      )}

      <SetFeedback
        showRir={!isTimed}
        rir={rir}
        painKnee={painKnee}
        painWrist={painWrist}
        painShoulder={painShoulder}
        painLowerBack={painLowerBack}
        setNote={setNote}
        onRirChange={onRirChange}
        onPainKneeChange={onPainKneeChange}
        onPainWristChange={onPainWristChange}
        onPainShoulderChange={onPainShoulderChange}
        onPainLowerBackChange={onPainLowerBackChange}
        onSetNoteChange={onSetNoteChange}
      />

      <SaveStatusPill status={saveStatus} className="justify-self-center" />

      <div
        className="mt-auto grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '64px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Volver a ajustar serie"
          className={`h-16 w-16 shrink-0 rounded-[1.9rem] p-0 ${actionStyles.back}`}
          style={{ width: '64px' }}
          variant="outline"
          onClick={onBack}
          disabled={isRegistering}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-16 rounded-[1.9rem] text-lg font-black"
          onClick={onRegister}
          disabled={isRegistering}
        >
          {isRegistering ? 'Guardando' : 'Registrar serie'}
          <Check className="size-6" />
        </Button>
      </div>
    </section>
  );
}

const noteOptions = ['OK', 'Pesado', 'Técnica', 'Molestia'];

function SetFeedback({
  showRir = true,
  rir,
  painKnee,
  painWrist,
  painShoulder,
  painLowerBack,
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onPainShoulderChange,
  onPainLowerBackChange,
  onSetNoteChange,
}: {
  showRir?: boolean;
  rir: number;
  painKnee: number;
  painWrist: number;
  painShoulder: number;
  painLowerBack: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onPainShoulderChange: (value: number) => void;
  onPainLowerBackChange: (value: number) => void;
  onSetNoteChange: (value: string) => void;
}) {
  return (
    <div className="grid shrink-0 gap-2 rounded-lg border bg-card p-2.5">
      {showRir ? (
        <div
          className="grid items-center gap-2"
          style={{ gridTemplateColumns: 'minmax(0, 1fr) 112px' }}
        >
          <span className="text-sm font-black text-muted-foreground">RIR</span>
          <div
            className="grid items-center gap-1"
            style={{ gridTemplateColumns: '44px minmax(0, 1fr) 44px' }}
          >
            <Button
              aria-label="Bajar RIR"
              className={`h-10 w-full rounded-md ${actionStyles.minus}`}
              variant="secondary"
              onClick={() => onRirChange(Math.max(0, rir - 1))}
            >
              <Minus className="size-4" />
            </Button>
            <span className="text-center text-xl font-black tabular-nums">
              {rir}
            </span>
            <Button
              aria-label="Subir RIR"
              className={`h-10 w-full rounded-md ${actionStyles.plus}`}
              variant="secondary"
              onClick={() => onRirChange(Math.min(5, rir + 1))}
            >
              <Plus className="size-4" />
            </Button>
          </div>
        </div>
      ) : null}

      <PainControl
        label="Rodilla"
        value={painKnee}
        onChange={onPainKneeChange}
      />
      <PainControl
        label="Muñeca"
        value={painWrist}
        onChange={onPainWristChange}
      />
      <PainControl
        label="Hombro"
        value={painShoulder}
        onChange={onPainShoulderChange}
      />
      <PainControl
        label="Lumbar"
        value={painLowerBack}
        onChange={onPainLowerBackChange}
      />

      <div className="grid grid-cols-4 gap-1.5">
        {noteOptions.map((option) => (
          <button
            key={option}
            className={`h-11 rounded-md border text-sm font-black ${
              setNote === option
                ? 'border-primary bg-primary text-primary-foreground'
                : 'border-border bg-secondary text-secondary-foreground'
            }`}
            type="button"
            onClick={() => onSetNoteChange(option)}
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}

function PainControl({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <div
      className="grid items-center gap-1.5"
      style={{ gridTemplateColumns: 'minmax(0, 1fr) repeat(4, 44px)' }}
    >
      <span className="text-sm font-black text-muted-foreground">{label}</span>
      {[0, 1, 2, 3].map((level) => (
        <button
          key={level}
          className={`h-10 rounded-md border text-sm font-black ${
            value === level
              ? 'border-primary bg-primary text-primary-foreground'
              : 'border-border bg-secondary text-secondary-foreground'
          }`}
          type="button"
          onClick={() => onChange(level)}
        >
          {level}
        </button>
      ))}
    </div>
  );
}

function TransitionScreen({
  completedExercises,
  nextExercise,
  decisions,
  onDecision,
  onContinue,
  saveStatus,
}: {
  completedExercises: Exercise[];
  nextExercise?: Exercise;
  decisions: Record<string, string>;
  onDecision: (exerciseId: string, value: string) => void;
  onContinue: () => void;
  saveStatus: SaveStatus;
}) {
  const isSuperset = completedExercises.length > 1;

  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="rounded-lg border bg-card p-4">
        <p className="text-sm font-semibold text-muted-foreground">
          {isSuperset ? 'Evaluar superserie' : 'Evaluar'}
        </p>
        <div className="mt-2 grid gap-4">
          {completedExercises.map((exercise) => {
            const decisionOptions = getExerciseDecisionOptions(exercise);

            return (
              <div key={exercise.exerciseId}>
                <h2 className="text-[1.55rem] font-black leading-tight tracking-normal">
                  {exercise.name}
                </h2>
                <div className="mt-2 grid grid-cols-2 gap-2">
                  {decisionOptions.map((option) => {
                    const selectedDecision =
                      decisions[exercise.exerciseId] ??
                      getDefaultExerciseDecision(exercise);
                    const shouldSpan =
                      decisionOptions.length % 2 !== 0 &&
                      option === decisionOptions.at(-1);
                    const visual = getDecisionVisual(
                      option,
                      selectedDecision === option,
                    );

                    return (
                      <button
                        key={option}
                        className={`flex h-12 items-center justify-center gap-1.5 rounded-lg border px-3 text-center text-sm font-black ${
                          shouldSpan ? 'col-span-2' : ''
                        } ${visual.className}`}
                        type="button"
                        onClick={() => onDecision(exercise.exerciseId, option)}
                      >
                        {visual.icon}
                        <span className="min-w-0 truncate">{option}</span>
                      </button>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {nextExercise ? (
        <div className="rounded-lg bg-secondary px-4 py-3">
          <p className="text-sm font-semibold text-muted-foreground">Después</p>
          <p className="text-2xl font-black tracking-normal">
            {nextExercise.name}
          </p>
          <p className="mt-1 text-sm font-medium text-muted-foreground">
            {nextExercise.notes}
          </p>
        </div>
      ) : null}

      <SaveStatusPill status={saveStatus} className="mx-auto" />

      <Button
        className="mt-auto h-16 rounded-[1.9rem] text-lg font-black"
        onClick={onContinue}
      >
        {nextExercise ? 'Continuar' : 'Cerrar entrenamiento'}
        <ChevronRight className="size-6" />
      </Button>
    </section>
  );
}

function DoneScreen({
  completedSets,
  totalSets,
  durationMinutes,
  estimatedMinutes,
  onExport,
  onRestart,
}: {
  completedSets: number;
  totalSets: number;
  durationMinutes?: number;
  estimatedMinutes: number;
  onExport: () => void;
  onRestart: () => void;
}) {
  const durationDeltaLabel =
    durationMinutes !== undefined
      ? getDurationDeltaLabel(durationMinutes, estimatedMinutes)
      : undefined;

  return (
    <section className="flex flex-1 flex-col justify-center gap-4 text-center">
      <div className="mx-auto flex size-20 items-center justify-center rounded-full bg-primary text-primary-foreground">
        <Check className="size-10" />
      </div>
      <div>
        <p className="text-lg font-bold text-muted-foreground">
          Entrenamiento cerrado
        </p>
        <h2 className="mt-2 text-5xl font-black tracking-normal">
          {completedSets}/{totalSets}
        </h2>
        <p className="mt-2 text-lg text-muted-foreground">series completadas</p>
      </div>
      {durationMinutes !== undefined ? (
        <div className="grid grid-cols-2 gap-2 text-center">
          <div className="rounded-lg border bg-card px-3 py-3">
            <p className="text-sm font-black text-muted-foreground">Tiempo</p>
            <p className="mt-1 text-3xl font-black leading-none">
              {formatDurationMinutes(durationMinutes)}
            </p>
          </div>
          <div className="rounded-lg border bg-card px-3 py-3">
            <p className="text-sm font-black text-muted-foreground">
              Est. entreno
            </p>
            <p className="mt-1 text-3xl font-black leading-none">
              {estimatedMinutes} min
            </p>
          </div>
          <div className="col-span-2 rounded-lg bg-secondary px-3 py-2 text-sm font-black text-secondary-foreground">
            {durationDeltaLabel}
          </div>
        </div>
      ) : null}
      <Button
        className="h-16 rounded-[1.9rem] text-lg font-black"
        onClick={onExport}
      >
        Guardar CSV
        <Download className="size-5" />
      </Button>
      <Button
        className={`h-16 rounded-[1.9rem] text-lg font-black ${actionStyles.back}`}
        variant="secondary"
        onClick={onRestart}
      >
        <House className="size-5" />
        Volver a hoy
      </Button>
    </section>
  );
}

function EquipmentSelector({
  options,
  value,
  onChange,
}: {
  options: ExerciseEquipment[];
  value: ExerciseEquipment;
  onChange: (value: ExerciseEquipment) => void;
}) {
  return (
    <div className="grid h-12 shrink-0 grid-flow-col auto-cols-fr gap-1 rounded-[1.4rem] border bg-secondary p-1">
      {options.map((option) => {
        const selected = option === value;

        return (
          <button
            key={option}
            className={`min-w-0 rounded-[1.1rem] px-2 text-sm font-black transition active:scale-[0.98] ${
              selected
                ? 'bg-card text-foreground shadow-sm'
                : 'text-muted-foreground'
            }`}
            type="button"
            onClick={() => onChange(option)}
          >
            <span className="block truncate">{equipmentLabels[option]}</span>
          </button>
        );
      })}
    </div>
  );
}

type SetEditValues = {
  reps: number;
  weight: number;
  durationSeconds: number;
  weightStep: WeightStep;
};

function SetEditScreen({
  setType,
  reps,
  weight,
  durationSeconds,
  loadType,
  equipment,
  weightStep,
  onCancel,
  onConfirm,
}: {
  setType: TrainingSet['type'];
  reps: number;
  weight: number;
  durationSeconds: number;
  loadType: LoadType;
  equipment?: ExerciseEquipment;
  weightStep: WeightStep;
  onCancel: () => void;
  onConfirm: (values: SetEditValues) => void;
}) {
  const isTimed = setType === 'timed';
  const [localReps, setLocalReps] = useState(reps);
  const [localWeight, setLocalWeight] = useState(weight);
  const [localDurationSeconds, setLocalDurationSeconds] =
    useState(durationSeconds);
  const [localWeightStep, setLocalWeightStep] = useState(
    normalizeWeightStep(weightStep, loadType, equipment),
  );
  const normalizedWeightStep = normalizeWeightStep(
    localWeightStep,
    loadType,
    equipment,
  );

  const adjustWeight = (direction: -1 | 1) => {
    setLocalWeight((currentWeight) =>
      getAdjustedWeight(
        loadType,
        equipment,
        currentWeight,
        normalizedWeightStep,
        direction,
      ),
    );
  };

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden py-1">
      <div className="shrink-0">
        <p className="text-sm font-black uppercase tracking-normal text-muted-foreground">
          Ajustar serie
        </p>
        <h2 className="mt-1 text-3xl font-black leading-tight tracking-normal">
          Cambios puntuales
        </h2>
      </div>

      <div className="grid min-h-0 flex-1 gap-3">
        {isTimed ? (
          <AdjustmentControl
            label="Tiempo"
            value={formatClock(localDurationSeconds)}
            onMinus={() =>
              setLocalDurationSeconds((value) => Math.max(5, value - 5))
            }
            onPlus={() => setLocalDurationSeconds((value) => value + 5)}
          />
        ) : (
          <AdjustmentControl
            label="Reps"
            value={String(localReps)}
            onMinus={() => setLocalReps((value) => Math.max(1, value - 1))}
            onPlus={() => setLocalReps((value) => value + 1)}
          />
        )}

        <div className="grid min-h-0 gap-2">
          <AdjustmentControl
            label="Peso"
            value={formatWeight(localWeight)}
            onMinus={() => adjustWeight(-1)}
            onPlus={() => adjustWeight(1)}
            disableMinus={loadType === 'bodyweight'}
            disablePlus={loadType === 'bodyweight'}
          />
          {loadType === 'bodyweight' || loadType === 'per_dumbbell' ? null : (
            <WeightStepControl
              loadType={loadType}
              equipment={equipment}
              value={normalizedWeightStep}
              onChange={setLocalWeightStep}
            />
          )}
        </div>
      </div>

      <div
        className="grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '64px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Cancelar ajuste"
          className={`h-16 w-16 rounded-[1.9rem] p-0 ${actionStyles.back}`}
          style={{ width: '64px' }}
          variant="outline"
          onClick={onCancel}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-16 rounded-[1.9rem] text-lg font-black"
          onClick={() =>
            onConfirm({
              reps: localReps,
              weight: localWeight,
              durationSeconds: localDurationSeconds,
              weightStep: normalizedWeightStep,
            })
          }
        >
          Confirmar
          <Check className="size-5" />
        </Button>
      </div>
    </section>
  );
}

function AdjustmentControl({
  label,
  value,
  onMinus,
  onPlus,
  disableMinus = false,
  disablePlus = false,
}: {
  label: string;
  value: string;
  onMinus: () => void;
  onPlus: () => void;
  disableMinus?: boolean;
  disablePlus?: boolean;
}) {
  return (
    <div className="grid min-h-0 grid-rows-[1fr_64px] gap-2 rounded-lg border bg-card p-2 shadow-sm">
      <div className="flex min-w-0 flex-col items-center justify-center">
        <p className="text-base font-black text-muted-foreground">{label}</p>
        <p className="max-w-full text-center text-[clamp(2.75rem,15vw,4.5rem)] font-black leading-none tracking-normal">
          {value}
        </p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <Button
          aria-label={`Bajar ${label}`}
          className={`h-16 w-full rounded-[1.75rem] ${actionStyles.minus}`}
          variant="secondary"
          onClick={onMinus}
          disabled={disableMinus}
        >
          <Minus className="size-8" />
        </Button>
        <Button
          aria-label={`Subir ${label}`}
          className={`h-16 w-full rounded-[1.75rem] ${actionStyles.plus}`}
          variant="secondary"
          onClick={onPlus}
          disabled={disablePlus}
        >
          <Plus className="size-8" />
        </Button>
      </div>
    </div>
  );
}

function TappableNumber({
  label,
  value,
  hint,
  onClick,
}: {
  label: string;
  value: string;
  hint: string;
  onClick: () => void;
}) {
  return (
    <button
      className="grid min-h-0 rounded-lg border bg-card p-3 text-center shadow-sm transition active:scale-[0.99]"
      type="button"
      onClick={onClick}
      aria-label={`Ajustar ${label}`}
    >
      <span className="text-base font-black text-muted-foreground">
        {label}
      </span>
      <span className="flex min-h-0 items-center justify-center text-[clamp(3rem,17vw,4.9rem)] font-black leading-none tracking-normal">
        {value}
      </span>
      <span className="text-sm font-black text-primary">{hint}</span>
    </button>
  );
}

function WeightStepControl({
  loadType,
  equipment,
  value,
  onChange,
}: {
  loadType: LoadType;
  equipment?: Exercise['equipment'];
  value: WeightStep;
  onChange: (value: WeightStep) => void;
}) {
  const options = getWeightStepOptions(loadType, equipment);
  const isFixed = options.length === 1;
  const label =
    equipment === 'plate_loaded_machine'
      ? 'disco'
      : loadType === 'total'
        ? 'disco por lado'
        : loadType === 'machine'
          ? 'salto'
          : loadType === 'bodyweight'
            ? 'fijo'
            : 'lastre';

  if (isFixed) {
    return (
      <div className="flex h-12 min-w-0 items-center justify-center rounded-[1.4rem] border border-border bg-secondary px-3 text-secondary-foreground">
        <span className="text-sm font-black text-muted-foreground">
          {label}
        </span>
        <span className="ml-2 text-base font-black leading-tight tabular-nums">
          {loadType === 'bodyweight' ? '0' : `${formatDecimal(value)} kg`}
        </span>
      </div>
    );
  }

  const selectedIndex = options.indexOf(value);
  const currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
  const nextValue = options[(currentIndex + 1) % options.length];

  return (
    <button
      className="flex h-12 min-w-0 items-center justify-center rounded-[1.4rem] border border-border bg-secondary px-3 text-secondary-foreground transition active:scale-[0.98]"
      type="button"
      onClick={() => onChange(nextValue)}
      aria-label={`Cambiar incremento de peso, actual ${formatDecimal(
        value,
      )} kg`}
    >
      <span className="text-sm font-black text-muted-foreground">{label}</span>
      <span className="ml-2 text-base font-black leading-tight tabular-nums">
        {formatDecimal(value)} kg
      </span>
    </button>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex h-16 min-w-0 flex-col items-center justify-center rounded-md bg-secondary px-2">
      <p className="text-xs font-bold leading-none text-muted-foreground">
        {label}
      </p>
      <p className="mt-1 max-w-full text-center text-sm font-black leading-tight">
        {value}
      </p>
    </div>
  );
}
