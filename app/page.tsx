'use client';

import {
  Check,
  ChevronRight,
  Database,
  Download,
  ArrowLeft,
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
  TrendingUp,
  Trash2,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Switch } from '@/components/ui/switch';
import planData from '@/data/trainingPlan.json';
import packageData from '@/package.json';
import {
  buildFullTrainingDataExport,
  buildWorkoutCsv,
  formatExportTarget,
  getFullJsonExportFileName,
  getWorkoutCsvFileName,
  inferLoadType,
  type ExportPhase,
  type LoadType,
} from '@/lib/sessionExport';
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
  type StoredSessionMetadata,
} from '@/lib/workoutStorage';

type Phase =
  | 'today'
  | 'preview'
  | 'set'
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
  | 'local-data'
  | 'progression'
  | 'history';
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
  supersetId?: string;
  supersetOrder?: number;
  phase: string;
  notes: string;
  target: string;
  decisionOptions: string[];
  sets: TrainingSet[];
};

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

type SessionHistorySummary = {
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

type ExerciseProgressInsight = {
  exerciseId: string;
  exerciseName: string;
  lastDate: string;
  nextDate?: string;
  nextSessionLabel?: string;
  target: string;
  lastLoadKg?: number;
  lastReps?: number;
  lastDurationSeconds?: number;
  lastRir?: number;
  lastDecision?: string;
  completedSets: number;
  attemptedSets: number;
  plannedSets: number;
  skippedSets: number;
  painHits: number;
  recommendation: string;
  tone: 'neutral' | 'up' | 'down' | 'warning';
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
  restRemaining: number;
  records: StoredSetEvent[];
  decisions: Record<string, string>;
  startedAt?: string;
  finishedAt?: string;
  transitionExerciseIds: string[];
  transitionNextPhase: 'set' | 'done';
  editedRir: number;
  painKnee: number;
  painWrist: number;
  painOther: number;
  setNote: string;
};

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

type SessionDurationEstimate = {
  totalMinutes: number;
  mobilityMinutes: number;
  executionMinutes: number;
  restMinutes: number;
  changeoverMinutes: number;
  feedbackMinutes: number;
  targetMinutes: number;
};

const trainingPlan = planData as TrainingPlan;
const appVersion = packageData.version;
const storageKey = `gymapp:${trainingPlan.planId}:draft`;
const themeStorageKey = 'gymapp:appearance-theme';
const wakeLockStorageKey = 'gymapp:keep-screen-awake';
const exportedSessionRetentionDays = 30;
const warmupMobilityMinutes = 9;
const feedbackSecondsPerSet = 8;
const exerciseChangeSeconds = 45;
const supersetTransitionSeconds = 15;

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

const getRecommendedSession = () => {
  const today = new Date();
  const todayIso = today.toISOString().slice(0, 10);

  return (
    trainingPlan.sessions.find((session) => session.date === todayIso) ??
    trainingPlan.sessions.find((session) => session.date >= todayIso) ??
    fallbackSession
  );
};

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
  transitionExerciseIds: [],
  transitionNextPhase: 'set',
  editedRir: 2,
  painKnee: 0,
  painWrist: 0,
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
    trainingPlan.sessions.find(
      (candidate) => candidate.sessionId === draft.selectedSessionId,
    ) ?? fallbackSession;

  return {
    ...makeDraft(session),
    ...draft,
    records: Array.isArray(draft.records)
      ? draft.records.filter(isStoredSetEvent)
      : [],
    decisions: draft.decisions ?? {},
    ...(draft.startedAt ? { startedAt: draft.startedAt } : {}),
    ...(draft.finishedAt ? { finishedAt: draft.finishedAt } : {}),
    transitionExerciseIds: draft.transitionExerciseIds ?? [],
    transitionNextPhase: draft.transitionNextPhase ?? 'set',
    editedRir: draft.editedRir ?? 2,
    editedDurationSeconds: draft.editedDurationSeconds ?? 0,
    weightStep: isWeightStep(draft.weightStep) ? draft.weightStep : 1,
    setTimerRemaining: draft.setTimerRemaining ?? 0,
    isSetTimerRunning: draft.isSetTimerRunning ?? false,
    painKnee: draft.painKnee ?? 0,
    painWrist: draft.painWrist ?? 0,
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

const formatWeight = (weight: number) => `${formatDecimal(weight)} kg`;

const formatClock = (totalSeconds: number) => {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = String(safeSeconds % 60).padStart(2, '0');

  return `${minutes}:${seconds}`;
};

const getDurationMinutes = (startedAt?: string, finishedAt?: string) => {
  if (!startedAt || !finishedAt) {
    return undefined;
  }

  const startedTime = new Date(startedAt).getTime();
  const finishedTime = new Date(finishedAt).getTime();

  if (!Number.isFinite(startedTime) || !Number.isFinite(finishedTime)) {
    return undefined;
  }

  const elapsedMs = finishedTime - startedTime;

  if (elapsedMs < 0) {
    return undefined;
  }

  return Math.max(1, Math.round(elapsedMs / 60000));
};

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

const getSetExecutionSeconds = (set: TrainingSet) => {
  if (set.type === 'timed') {
    return set.targetDurationSeconds ?? 60;
  }

  return Math.max(20, (set.targetReps ?? 8) * 4);
};

const estimateSessionDuration = (
  session: TrainingSession,
): SessionDurationEstimate => {
  const steps = buildExecutionSteps(session);
  let executionSeconds = 0;
  let restSeconds = 0;
  let changeoverSeconds = 0;
  const feedbackSeconds = steps.length * feedbackSecondsPerSet;

  steps.forEach((step, index) => {
    const currentSet =
      session.exercises[step.exerciseIndex].sets[step.setIndex];
    const nextStep = steps[index + 1];
    executionSeconds += getSetExecutionSeconds(currentSet);

    if (!nextStep) {
      return;
    }

    const isSameSupersetRound =
      step.supersetId !== undefined &&
      step.supersetId === nextStep.supersetId &&
      step.roundNumber === nextStep.roundNumber;

    if (!isSameSupersetRound) {
      restSeconds += currentSet.restSeconds;
    }

    if (step.exerciseIndex !== nextStep.exerciseIndex) {
      changeoverSeconds += isSameSupersetRound
        ? supersetTransitionSeconds
        : exerciseChangeSeconds;
    }
  });

  const mobilitySeconds = warmupMobilityMinutes * 60;
  const totalSeconds =
    mobilitySeconds +
    executionSeconds +
    restSeconds +
    changeoverSeconds +
    feedbackSeconds;

  return {
    totalMinutes: Math.round(totalSeconds / 60),
    mobilityMinutes: warmupMobilityMinutes,
    executionMinutes: Math.round(executionSeconds / 60),
    restMinutes: Math.round(restSeconds / 60),
    changeoverMinutes: Math.round(changeoverSeconds / 60),
    feedbackMinutes: Math.round(feedbackSeconds / 60),
    targetMinutes: session.estimatedMinutes,
  };
};

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

const getTodayIso = () => new Date().toISOString().slice(0, 10);

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

const getSessionHistorySummaries = (
  sessions: TrainingSession[],
  events: StoredSetEvent[],
  metadata: StoredSessionMetadata[],
): SessionHistorySummary[] => {
  const eventsBySession = new Map<string, StoredSetEvent[]>();
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );

  events.forEach((event) => {
    const sessionEvents = eventsBySession.get(event.sessionId) ?? [];
    sessionEvents.push(event);
    eventsBySession.set(event.sessionId, sessionEvents);
  });

  return sessions
    .flatMap((session) => {
      const sessionEvents = eventsBySession.get(session.sessionId) ?? [];

      if (sessionEvents.length === 0) {
        return [];
      }

      const sortedEvents = [...sessionEvents].sort((a, b) =>
        a.performedAt.localeCompare(b.performedAt),
      );
      const sessionMetadata = metadataBySession.get(session.sessionId);

      return [
        {
          sessionId: session.sessionId,
          sessionDate: session.date,
          sessionLabel: session.label,
          estimatedMinutes: session.estimatedMinutes,
          derivedEstimatedMinutes:
            estimateSessionDuration(session).totalMinutes,
          attemptedSets: sortedEvents.length,
          completedSets: sortedEvents.filter(
            (event) => event.status === 'completed',
          ).length,
          totalSets: buildExecutionSteps(session).length,
          ...(sessionMetadata?.schemaVersion
            ? { schemaVersion: sessionMetadata.schemaVersion }
            : {}),
          ...(sessionMetadata?.startedAt
            ? { startedAt: sessionMetadata.startedAt }
            : {}),
          ...(sessionMetadata?.finishedAt
            ? { finishedAt: sessionMetadata.finishedAt }
            : {}),
          ...(sessionMetadata?.exportedAt
            ? { exportedAt: sessionMetadata.exportedAt }
            : {}),
          firstPerformedAt: sortedEvents[0].performedAt,
          lastPerformedAt: sortedEvents[sortedEvents.length - 1].performedAt,
        },
      ];
    })
    .sort((a, b) => b.lastPerformedAt.localeCompare(a.lastPerformedAt));
};

const getExerciseProgressInsights = (
  sessions: TrainingSession[],
  events: StoredSetEvent[],
  metadata: StoredSessionMetadata[],
): ExerciseProgressInsight[] => {
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );
  const eventsByExercise = new Map<string, StoredSetEvent[]>();

  events.forEach((event) => {
    const exerciseEvents = eventsByExercise.get(event.exerciseId) ?? [];
    exerciseEvents.push(event);
    eventsByExercise.set(event.exerciseId, exerciseEvents);
  });

  const todayIso = getTodayIso();

  return Array.from(eventsByExercise.entries())
    .map(([exerciseId, exerciseEvents]) => {
      const sortedEvents = [...exerciseEvents].sort((a, b) =>
        a.performedAt.localeCompare(b.performedAt),
      );
      const lastEvent = sortedEvents[sortedEvents.length - 1];
      const lastSession =
        sessions.find((session) => session.sessionId === lastEvent.sessionId) ??
        sessions.find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const lastExercise = lastSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const nextSession = sessions
        .filter((session) => session.date >= todayIso)
        .find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const nextExercise = nextSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const completedEvents = sortedEvents.filter(
        (event) => event.status === 'completed',
      );
      const skippedSets = sortedEvents.filter(
        (event) => event.status === 'skipped',
      ).length;
      const recentEvents = sortedEvents.slice(-12);
      const painHits = recentEvents.filter(
        (event) =>
          event.painKnee > 0 || event.painWrist > 0 || event.painOther > 0,
      ).length;
      const sessionEvents = sortedEvents.filter(
        (event) => event.sessionId === lastEvent.sessionId,
      );
      const completedSets = sessionEvents.filter(
        (event) => event.status === 'completed',
      ).length;
      const attemptedSets = sessionEvents.length;
      const plannedSets = lastExercise?.sets.length ?? attemptedSets;
      const lastCompletedEvent = completedEvents.at(-1);
      const lastDecision = metadataBySession.get(lastEvent.sessionId)
        ?.decisions?.[exerciseId];
      const decisionText = lastDecision?.toLowerCase() ?? '';
      const avgRecentRir =
        completedEvents.length > 0
          ? completedEvents
              .slice(-Math.min(3, completedEvents.length))
              .reduce((total, event) => total + event.rirLast, 0) /
            Math.min(3, completedEvents.length)
          : 0;

      let tone: ExerciseProgressInsight['tone'] = 'neutral';
      let recommendation = 'Mantener y observar';

      if (painHits >= 2 || decisionText.includes('molestia')) {
        tone = 'warning';
        recommendation = 'Revisar técnica o carga';
      } else if (decisionText.includes('bajar')) {
        tone = 'down';
        recommendation = lastDecision ?? 'Bajar carga';
      } else if (decisionText.includes('subir')) {
        tone = 'up';
        recommendation = lastDecision ?? 'Subir carga';
      } else if (skippedSets >= 2 || completedSets < plannedSets) {
        tone = 'warning';
        recommendation = 'Mantener hasta completar series';
      } else if (avgRecentRir >= 2.5 && completedSets >= plannedSets) {
        tone = 'up';
        recommendation = 'Candidato a subir';
      }

      return {
        exerciseId,
        exerciseName: nextExercise?.name ?? lastExercise?.name ?? exerciseId,
        lastDate: lastEvent.sessionDate,
        ...(nextSession
          ? {
              nextDate: nextSession.date,
              nextSessionLabel: nextSession.label,
            }
          : {}),
        target: formatExportTarget(
          nextExercise?.target ?? lastExercise?.target ?? '',
          inferLoadType(nextExercise ?? lastExercise),
        ),
        ...(lastCompletedEvent
          ? {
              lastLoadKg: lastCompletedEvent.actualWeightKg,
              ...(lastCompletedEvent.actualDurationSeconds !== undefined
                ? {
                    lastDurationSeconds:
                      lastCompletedEvent.actualDurationSeconds,
                  }
                : { lastReps: lastCompletedEvent.actualReps }),
              lastRir: lastCompletedEvent.rirLast,
            }
          : {}),
        ...(lastDecision ? { lastDecision } : {}),
        completedSets,
        attemptedSets,
        plannedSets,
        skippedSets,
        painHits,
        recommendation,
        tone,
      };
    })
    .sort((a, b) => {
      const toneOrder = { warning: 0, up: 1, down: 2, neutral: 3 };
      return (
        toneOrder[a.tone] - toneOrder[b.tone] ||
        (a.nextDate ?? '9999-12-31').localeCompare(b.nextDate ?? '9999-12-31')
      );
    })
    .slice(0, 8);
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

const barbellLoadsKg = Array.from(
  new Set(
    buildSidePlateLoads().map(
      (sideLoad) => Math.round((barbellWeightKg + sideLoad * 2) * 2) / 2,
    ),
  ),
).sort((a, b) => a - b);
const externalLoadsKg = buildPlateCombinationLoads();

const isWeightStep = (value: unknown): value is WeightStep =>
  value === 0.5 ||
  value === 1 ||
  value === 1.25 ||
  value === 2.5 ||
  value === 5;

const getWeightStepOptions = (loadType: LoadType): WeightStep[] => {
  if (loadType === 'total' || loadType === 'external') {
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
): WeightStep => {
  const options = getWeightStepOptions(loadType);
  return options.includes(value) ? value : options[0];
};

const getAvailableLoadsForType = (loadType: LoadType) => {
  if (loadType === 'per_dumbbell') {
    return dumbbellLoadsKg;
  }

  if (loadType === 'machine') {
    return cableLoadsKg;
  }

  if (loadType === 'total') {
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
  currentWeight: number,
  step: WeightStep,
  direction: -1 | 1,
) => {
  if (loadType === 'bodyweight') {
    return 0;
  }

  const normalizedStep = normalizeWeightStep(step, loadType);
  const target =
    currentWeight + getWeightDelta(loadType, normalizedStep) * direction;
  const loads = getAvailableLoadsForType(loadType);

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

const getPreviewLoadLabel = (loadType: LoadType) => {
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
      loadLabel: getPreviewLoadLabel(loadType),
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
    loadLabel: getPreviewLoadLabel(loadType),
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
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [isRegisteringSet, setIsRegisteringSet] = useState(false);
  const isRegisteringSetRef = useRef(false);
  const wakeLockRef = useRef<WakeLockSentinel | null>(null);
  const keepScreenAwakeRef = useRef(false);
  const selectedSession =
    trainingPlan.sessions.find(
      (session) => session.sessionId === draft.selectedSessionId,
    ) ?? fallbackSession;
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
    draft.phase === 'feedback' ||
    draft.phase === 'rest' ||
    draft.phase === 'transition';

  const weekSessions = useMemo(
    () =>
      trainingPlan.sessions.filter(
        (session) => session.week === selectedSession.week,
      ),
    [selectedSession.week],
  );

  const refreshSessionHistory = useCallback(async () => {
    setIsLoadingHistory(true);

    try {
      await purgeExportedSessionsOlderThan(exportedSessionRetentionDays);
      const events = await loadAllSessionEvents();
      const metadata = await loadSessionMetadata();
      setSessionHistory(
        getSessionHistorySummaries(trainingPlan.sessions, events, metadata),
      );
      setExerciseInsights(
        getExerciseProgressInsights(trainingPlan.sessions, events, metadata),
      );
    } catch {
      setSessionHistory([]);
      setExerciseInsights([]);
    } finally {
      setIsLoadingHistory(false);
    }
  }, []);

  useEffect(() => {
    keepScreenAwakeRef.current = keepScreenAwake;
  }, [keepScreenAwake]);

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
      window.localStorage.setItem(themeStorageKey, appearanceTheme);
    };

    applyTheme();

    if (appearanceTheme !== 'system') {
      return;
    }

    const media = window.matchMedia('(prefers-color-scheme: dark)');
    media.addEventListener('change', applyTheme);

    return () => media.removeEventListener('change', applyTheme);
  }, [appearanceTheme]);

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

    const timer = window.setInterval(() => {
      setDraft((current) => ({
        ...current,
        restRemaining: Math.max(0, current.restRemaining - 1),
      }));
    }, 1000);

    return () => window.clearInterval(timer);
  }, [draft.phase, draft.restRemaining]);

  useEffect(() => {
    if (
      draft.phase !== 'set' ||
      !draft.isSetTimerRunning ||
      draft.setTimerRemaining <= 0
    ) {
      return;
    }

    const timer = window.setInterval(() => {
      setDraft((current) => {
        const nextRemaining = Math.max(0, current.setTimerRemaining - 1);

        return {
          ...current,
          setTimerRemaining: nextRemaining,
          isSetTimerRunning: nextRemaining > 0,
        };
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, [draft.phase, draft.isSetTimerRunning, draft.setTimerRemaining]);

  const patchDraft = useCallback((patch: Partial<WorkoutDraft>) => {
    setDraft((current) => ({ ...current, ...patch }));
  }, []);

  const resetWorkoutPosition = useCallback(
    (sessionId = draft.selectedSessionId) => {
      const nextSession =
        trainingPlan.sessions.find(
          (session) => session.sessionId === sessionId,
        ) ?? fallbackSession;
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
      const nextSet =
        selectedSession.exercises[nextExerciseIndex].sets[nextSetIndex];
      patchDraft({
        editedReps: nextSet.targetReps ?? 0,
        editedWeight: nextSet.targetWeightKg,
        editedDurationSeconds: nextSet.targetDurationSeconds ?? 0,
        setTimerRemaining: nextSet.targetDurationSeconds ?? 0,
        isSetTimerRunning: false,
      });
    },
    [patchDraft, selectedSession],
  );

  const completeWorkout = useCallback(() => {
    const finishedAt = new Date().toISOString();
    patchDraft({
      phase: 'done',
      finishedAt,
      transitionExerciseIds: [],
      transitionNextPhase: 'set',
    });
    void markSessionFinished(selectedSession.sessionId, finishedAt).catch(
      () => undefined,
    );
  }, [patchDraft, selectedSession.sessionId]);

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
    patchDraft({
      exerciseIndex: nextStep.exerciseIndex,
      setIndex: nextStep.setIndex,
      phase: completedExerciseIds.length > 0 ? 'transition' : 'set',
      transitionExerciseIds: completedExerciseIds,
      transitionNextPhase: 'set',
    });
  }, [
    applyPlannedTargets,
    currentExercise,
    currentStep,
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
        actualReps: draft.editedReps,
        actualWeightKg: draft.editedWeight,
        actualDurationSeconds:
          currentSet.type === 'timed'
            ? draft.editedDurationSeconds - draft.setTimerRemaining
            : undefined,
        restSecondsPlanned: currentSet.restSeconds,
        restSecondsActual: currentSet.restSeconds,
        status,
        rirLast: draft.editedRir,
        painKnee: draft.painKnee,
        painWrist: draft.painWrist,
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
        return;
      }

      setDraft((current) => ({
        ...current,
        records: [...current.records, nextRecord],
        editedRir: 2,
        painKnee: 0,
        painWrist: 0,
        painOther: 0,
        setNote: 'OK',
        isSetTimerRunning: false,
      }));

      if (!shouldRestAfterCurrentStep || status === 'skipped') {
        moveForward();
        isRegisteringSetRef.current = false;
        setIsRegisteringSet(false);
        return;
      }

      patchDraft({ restRemaining: currentSet.restSeconds, phase: 'rest' });
      isRegisteringSetRef.current = false;
      setIsRegisteringSet(false);
    },
    [
      currentSet,
      currentStep,
      draft.editedDurationSeconds,
      draft.editedReps,
      draft.editedWeight,
      draft.editedRir,
      draft.exerciseIndex,
      draft.painKnee,
      draft.painOther,
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
    void resetWorkoutPosition(sessionId);
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

  const exportCsv = async () => {
    await exportWorkoutCsv(selectedSession, draft.records, draft.decisions);
    await markSessionExported(
      selectedSession.sessionId,
      new Date().toISOString(),
    );
    await refreshSessionHistory();
  };

  const exportHistorySession = async (sessionId: string) => {
    const session =
      trainingPlan.sessions.find((item) => item.sessionId === sessionId) ??
      fallbackSession;
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
    const session =
      trainingPlan.sessions.find((item) => item.sessionId === sessionId) ??
      fallbackSession;
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
      <div className="app-screen mx-auto flex w-full max-w-[480px] flex-col overflow-hidden px-4 pt-3 pb-[calc(1rem+env(safe-area-inset-bottom))] sm:py-4">
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
            sessionHistory={sessionHistory}
            exerciseInsights={exerciseInsights}
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
            loadType={inferLoadType(currentExercise)}
            durationSeconds={draft.editedDurationSeconds}
            timerRemaining={draft.setTimerRemaining}
            isTimerRunning={draft.isSetTimerRunning}
            weightStep={draft.weightStep}
            restSeconds={currentSet.restSeconds}
            completedSetIndexes={draft.records
              .filter((record) => record.exerciseIndex === draft.exerciseIndex)
              .map((record) => record.setIndex)}
            onRepsChange={(editedReps) => patchDraft({ editedReps })}
            onWeightChange={(editedWeight) => patchDraft({ editedWeight })}
            onWeightStepChange={(weightStep) => patchDraft({ weightStep })}
            onTimerToggle={() =>
              patchDraft({
                isSetTimerRunning: !draft.isSetTimerRunning,
                setTimerRemaining:
                  draft.setTimerRemaining > 0
                    ? draft.setTimerRemaining
                    : draft.editedDurationSeconds,
              })
            }
            onTimerReset={() =>
              patchDraft({
                setTimerRemaining: draft.editedDurationSeconds,
                isSetTimerRunning: false,
              })
            }
            onContinue={() => patchDraft({ phase: 'feedback' })}
            onSkip={() => void logCurrentSet('skipped')}
            onBack={() => patchDraft({ phase: 'today' })}
            isRegistering={isRegisteringSet}
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
            setNote={draft.setNote}
            onRirChange={(editedRir) => patchDraft({ editedRir })}
            onPainKneeChange={(painKnee) => patchDraft({ painKnee })}
            onPainWristChange={(painWrist) => patchDraft({ painWrist })}
            onSetNoteChange={(setNote) => patchDraft({ setNote })}
            onBack={() => patchDraft({ phase: 'set' })}
            onRegister={() => void logCurrentSet('completed')}
            isRegistering={isRegisteringSet}
          />
        ) : null}

        {draft.phase === 'rest' ? (
          <RestScreen
            restRemaining={draft.restRemaining}
            restTotal={currentSet?.restSeconds ?? draft.restRemaining}
            nextLabel={getNextStepLabel(selectedSession, currentStep, nextStep)}
            onAdjustRest={(updater) => {
              setDraft((current) => ({
                ...current,
                restRemaining:
                  typeof updater === 'function'
                    ? updater(current.restRemaining)
                    : updater,
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
              draft.transitionNextPhase === 'set' ? currentExercise : undefined
            }
            decisions={draft.decisions}
            onDecision={chooseDecision}
            onContinue={() => {
              if (draft.transitionNextPhase === 'done') {
                completeWorkout();
                return;
              }

              patchDraft({
                phase: draft.transitionNextPhase,
                transitionExerciseIds: [],
              });
            }}
          />
        ) : null}

        {draft.phase === 'done' ? (
          <DoneScreen
            completedSets={completedSets}
            totalSets={totalSets}
            estimatedMinutes={selectedSessionDurationEstimate.totalMinutes}
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
  hasStarted,
  onChangeSession,
  onResume,
  onStart,
  onSettings,
}: {
  selectedSession: TrainingSession;
  durationEstimate: SessionDurationEstimate;
  weekSessions: TrainingSession[];
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

      <div className="grid grid-cols-2 gap-2">
        {weekSessions.map((session) => (
          <button
            key={session.sessionId}
            className={`min-h-20 rounded-lg border p-3 text-left transition active:scale-[0.98] ${
              session.sessionId === selectedSession.sessionId
                ? 'border-primary bg-primary text-primary-foreground'
                : 'border-border bg-secondary text-secondary-foreground'
            }`}
            type="button"
            onClick={() => onChangeSession(session.sessionId)}
          >
            <span className="block text-sm font-bold capitalize">
              {session.weekday}
            </span>
            <span className="mt-1 block overflow-hidden text-lg font-black leading-tight [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
              {session.label}
            </span>
          </button>
        ))}
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
          {session.exercises.map((exercise, index) => {
            const metrics = getExercisePreviewMetrics(exercise);
            const supersetSize = exercise.supersetId
              ? getSupersetMembers(session, exercise.supersetId).length
              : 0;

            return (
              <div
                key={exercise.exerciseId}
                className="grid gap-3 rounded-lg border bg-card p-3 shadow-sm"
              >
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
                  <PreviewMetric
                    label={metrics.workLabel}
                    value={metrics.work}
                  />
                  <PreviewMetric
                    label={metrics.loadLabel}
                    value={metrics.load}
                  />
                </div>
              </div>
            );
          })}
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

function SettingsScreen({
  section,
  theme,
  keepScreenAwake,
  wakeLockStatus,
  offlineStatus,
  offlineInfo,
  selectedSessionLabel,
  sessionHistory,
  exerciseInsights,
  isLoadingHistory,
  onSectionChange,
  onThemeChange,
  onKeepScreenAwakeChange,
  onCheckOffline,
  onUpdateOfflineVersion,
  onResetCurrent,
  onClearAllData,
  onExportFullJson,
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
  sessionHistory: SessionHistorySummary[];
  exerciseInsights: ExerciseProgressInsight[];
  isLoadingHistory: boolean;
  onSectionChange: (section: SettingsSection) => void;
  onThemeChange: (theme: AppearanceTheme) => void;
  onKeepScreenAwakeChange: (enabled: boolean) => void;
  onCheckOffline: () => void;
  onUpdateOfflineVersion: () => void;
  onResetCurrent: () => void;
  onClearAllData: () => void;
  onExportFullJson: () => void;
  onExportHistorySession: (sessionId: string) => void;
  onDeleteHistorySession: (sessionId: string) => void;
  onBack: () => void;
}) {
  const sectionTitle = {
    index: 'Ajustes',
    appearance: 'Apariencia',
    training: 'Entrenamiento',
    installation: 'Instalación',
    'local-data': 'Datos locales',
    progression: 'Progresión',
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
      section: 'local-data',
      title: 'Datos locales',
      detail: selectedSessionLabel,
      icon: <Database className="size-5" />,
    },
    {
      section: 'progression',
      title: 'Progresión',
      detail: exerciseInsights.length
        ? `${exerciseInsights.length} señales disponibles`
        : 'Sin señales todavía',
      icon: <TrendingUp className="size-5" />,
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

        {section === 'progression' ? (
          <div className="mt-4 grid gap-2">
            {isLoadingHistory ? (
              <div className="rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
                Revisando registros...
              </div>
            ) : null}

            {!isLoadingHistory && exerciseInsights.length === 0 ? (
              <div className="rounded-[1.4rem] border bg-secondary px-4 py-3 text-sm font-bold text-muted-foreground">
                Aún no hay series suficientes para recomendar ajustes.
              </div>
            ) : null}

            {exerciseInsights.map((insight) => (
              <ExerciseInsightCard key={insight.exerciseId} insight={insight} />
            ))}
          </div>
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

function ExerciseInsightCard({
  insight,
}: {
  insight: ExerciseProgressInsight;
}) {
  const toneClassName = {
    neutral: 'border-border bg-secondary text-secondary-foreground',
    up: 'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)]',
    down: 'border-[var(--action-minus-border)] bg-[var(--action-minus)] text-[var(--action-minus-foreground)]',
    warning:
      'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)]',
  }[insight.tone];
  const detailParts = [
    insight.nextDate ? `Próx. ${formatDate(insight.nextDate)}` : undefined,
    insight.nextSessionLabel,
    insight.target,
  ].filter(Boolean);
  const lastParts = [
    `${insight.completedSets}/${insight.plannedSets} series`,
    insight.lastLoadKg !== undefined
      ? `${formatCsvNumber(insight.lastLoadKg)} kg`
      : undefined,
    insight.lastReps !== undefined ? `${insight.lastReps} reps` : undefined,
    insight.lastDurationSeconds !== undefined
      ? formatClock(insight.lastDurationSeconds)
      : undefined,
    insight.lastRir !== undefined ? `RIR ${insight.lastRir}` : undefined,
  ].filter(Boolean);
  const alertParts = [
    insight.skippedSets > 0 ? `${insight.skippedSets} saltadas` : undefined,
    insight.painHits > 0 ? `${insight.painHits} molestias` : undefined,
  ].filter(Boolean);

  return (
    <div className="min-w-0 overflow-hidden rounded-[1.4rem] border bg-secondary p-3 text-secondary-foreground">
      <div className="grid min-w-0 gap-2">
        <div className="min-w-0">
          <p className="truncate text-sm font-black">{insight.exerciseName}</p>
          <p className="mt-0.5 overflow-hidden text-xs font-bold leading-tight text-muted-foreground [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
            {detailParts.join(' · ')}
          </p>
        </div>
        <span
          className={`min-w-0 justify-self-start truncate rounded-full border px-2.5 py-1 text-xs font-black ${toneClassName}`}
        >
          {insight.recommendation}
        </span>
      </div>
      <div className="mt-3 grid min-w-0 grid-cols-2 gap-2 text-xs font-black">
        <div className="min-w-0 rounded-[1rem] border bg-card px-3 py-2">
          <span className="block text-muted-foreground">Última</span>
          <span className="mt-0.5 block truncate">
            {formatDate(insight.lastDate)}
          </span>
        </div>
        <div className="min-w-0 rounded-[1rem] border bg-card px-3 py-2">
          <span className="block text-muted-foreground">Registro</span>
          <span className="mt-0.5 block truncate">{lastParts.join(' · ')}</span>
        </div>
      </div>
      {insight.lastDecision || alertParts.length > 0 ? (
        <p className="mt-2 text-xs font-bold leading-tight text-muted-foreground">
          {[insight.lastDecision, ...alertParts].filter(Boolean).join(' · ')}
        </p>
      ) : null}
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
  durationSeconds,
  timerRemaining,
  isTimerRunning,
  weightStep,
  restSeconds,
  onRepsChange,
  onWeightChange,
  onWeightStepChange,
  onTimerToggle,
  onTimerReset,
  onContinue,
  onSkip,
  onBack,
  isRegistering,
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
  durationSeconds: number;
  timerRemaining: number;
  isTimerRunning: boolean;
  weightStep: WeightStep;
  restSeconds: number;
  onRepsChange: (value: number) => void;
  onWeightChange: (value: number) => void;
  onWeightStepChange: (value: WeightStep) => void;
  onTimerToggle: () => void;
  onTimerReset: () => void;
  onContinue: () => void;
  onSkip: () => void;
  onBack: () => void;
  isRegistering: boolean;
}) {
  const isTimed = setType === 'timed';
  const normalizedWeightStep = normalizeWeightStep(weightStep, loadType);
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
          <TactileNumber
            label="Reps"
            value={String(reps)}
            minusClassName={actionStyles.minus}
            plusClassName={actionStyles.plus}
            onMinus={() => onRepsChange(Math.max(1, reps - 1))}
            onPlus={() => onRepsChange(reps + 1)}
          />
          <TactileNumber
            label="Peso"
            value={formatWeight(weight)}
            minusClassName={actionStyles.minus}
            plusClassName={actionStyles.plus}
            centerControl={
              loadType === 'per_dumbbell' ? undefined : (
                <WeightStepControl
                  loadType={loadType}
                  value={normalizedWeightStep}
                  onChange={onWeightStepChange}
                />
              )
            }
            onMinus={() =>
              onWeightChange(
                getAdjustedWeight(loadType, weight, normalizedWeightStep, -1),
              )
            }
            onPlus={() =>
              onWeightChange(
                getAdjustedWeight(loadType, weight, normalizedWeightStep, 1),
              )
            }
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
        style={{ gridTemplateColumns: '56px minmax(0, 1fr) 56px' }}
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
          onClick={onContinue}
        >
          Continuar
          <ChevronRight className="size-6" />
        </Button>
        <Button
          aria-label="Saltar serie"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.skip}`}
          style={{ width: '56px' }}
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

function RestScreen({
  restRemaining,
  restTotal,
  nextLabel,
  onAdjustRest,
  onContinue,
}: {
  restRemaining: number;
  restTotal: number;
  nextLabel: string;
  onAdjustRest: (value: number | ((current: number) => number)) => void;
  onContinue: () => void;
}) {
  const isFinished = restRemaining === 0;

  return (
    <section className="flex flex-1 flex-col justify-between gap-5 py-2">
      <div
        className={`rounded-lg border p-4 text-center shadow-sm transition-colors ${
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
          sizeClassName="mx-auto mt-5 size-64"
          textClassName="text-[5rem]"
          isFinished={isFinished}
        />
        <p className="mt-4 text-xl font-bold">Siguiente: {nextLabel}</p>
      </div>

      <div className="grid grid-cols-3 gap-2">
        <Button
          className={`h-14 rounded-[1.75rem] text-lg font-black ${actionStyles.rest}`}
          variant="secondary"
          onClick={() => onAdjustRest((value) => Math.max(0, value - 15))}
        >
          -15s
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          onClick={onContinue}
        >
          Seguir
        </Button>
        <Button
          className={`h-14 rounded-[1.75rem] text-lg font-black ${actionStyles.rest}`}
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
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onSetNoteChange,
  onBack,
  onRegister,
  isRegistering,
}: {
  exerciseName: string;
  setType: TrainingSet['type'];
  reps: number;
  weight: number;
  durationSeconds?: number;
  rir: number;
  painKnee: number;
  painWrist: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onSetNoteChange: (value: string) => void;
  onBack: () => void;
  onRegister: () => void;
  isRegistering: boolean;
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
        rir={rir}
        painKnee={painKnee}
        painWrist={painWrist}
        setNote={setNote}
        onRirChange={onRirChange}
        onPainKneeChange={onPainKneeChange}
        onPainWristChange={onPainWristChange}
        onSetNoteChange={onSetNoteChange}
      />

      <div
        className="mt-auto grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '56px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Volver a ajustar serie"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.back}`}
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
          disabled={isRegistering}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
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
  rir,
  painKnee,
  painWrist,
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onSetNoteChange,
}: {
  rir: number;
  painKnee: number;
  painWrist: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onSetNoteChange: (value: string) => void;
}) {
  return (
    <div className="grid shrink-0 gap-2 rounded-lg border bg-card p-2.5">
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
}: {
  completedExercises: Exercise[];
  nextExercise?: Exercise;
  decisions: Record<string, string>;
  onDecision: (exerciseId: string, value: string) => void;
  onContinue: () => void;
}) {
  const isSuperset = completedExercises.length > 1;

  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="rounded-lg border bg-card p-4">
        <p className="text-sm font-semibold text-muted-foreground">
          {isSuperset ? 'Evaluar superserie' : 'Evaluar'}
        </p>
        <div className="mt-2 grid gap-4">
          {completedExercises.map((exercise) => (
            <div key={exercise.exerciseId}>
              <h2 className="text-[1.55rem] font-black leading-tight tracking-normal">
                {exercise.name}
              </h2>
              <div className="mt-2 grid gap-2">
                {exercise.decisionOptions.map((option) => (
                  <button
                    key={option}
                    className={`h-12 rounded-lg border px-4 text-left text-base font-black ${
                      decisions[exercise.exerciseId] === option
                        ? 'border-primary bg-primary text-primary-foreground'
                        : 'border-border bg-secondary text-secondary-foreground'
                    }`}
                    type="button"
                    onClick={() => onDecision(exercise.exerciseId, option)}
                  >
                    {option}
                  </button>
                ))}
              </div>
            </div>
          ))}
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

      <Button
        className="mt-auto h-14 rounded-[1.75rem] text-lg font-black"
        onClick={onContinue}
      >
        {nextExercise ? 'Siguiente ejercicio' : 'Cerrar entrenamiento'}
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
            <p className="text-sm font-black text-muted-foreground">Estimado</p>
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
        className="h-14 rounded-[1.75rem] text-lg font-black"
        onClick={onExport}
      >
        Guardar CSV
        <Download className="size-5" />
      </Button>
      <Button
        className={`h-14 rounded-[1.75rem] text-lg font-black ${actionStyles.back}`}
        variant="secondary"
        onClick={onRestart}
      >
        <House className="size-5" />
        Volver a hoy
      </Button>
    </section>
  );
}

function TactileNumber({
  label,
  value,
  centerControl,
  minusClassName,
  plusClassName,
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  centerControl?: ReactNode;
  minusClassName?: string;
  plusClassName?: string;
  onMinus: () => void;
  onPlus: () => void;
}) {
  return (
    <div className="grid min-h-0 grid-rows-[1fr_64px] gap-2 rounded-lg border bg-card p-2 shadow-sm">
      <div className="flex min-w-0 flex-col items-center justify-center">
        <div className="grid min-h-8 w-full grid-cols-[1fr_auto_1fr] items-center">
          <span aria-hidden="true" />
          <p className="text-base font-black text-muted-foreground">{label}</p>
          <span aria-hidden="true" />
        </div>
        <p className="max-w-full text-center text-[clamp(2.75rem,16vw,4.75rem)] font-black leading-none tracking-normal">
          {value}
        </p>
      </div>
      <div
        className="grid gap-2"
        style={{
          gridTemplateColumns: centerControl
            ? 'minmax(0, 2fr) minmax(0, 1fr) minmax(0, 2fr)'
            : 'repeat(2, minmax(0, 1fr))',
        }}
      >
        <Button
          aria-label={`Bajar ${label}`}
          className={`h-16 w-full rounded-[1.75rem] ${minusClassName ?? ''}`}
          variant="secondary"
          onClick={onMinus}
        >
          <Minus className="size-8" />
        </Button>
        {centerControl}
        <Button
          aria-label={`Subir ${label}`}
          className={`h-16 w-full rounded-[1.75rem] ${plusClassName ?? ''}`}
          variant="secondary"
          onClick={onPlus}
        >
          <Plus className="size-8" />
        </Button>
      </div>
    </div>
  );
}

function WeightStepControl({
  loadType,
  value,
  onChange,
}: {
  loadType: LoadType;
  value: WeightStep;
  onChange: (value: WeightStep) => void;
}) {
  const options = getWeightStepOptions(loadType);
  const isFixed = options.length === 1;
  const label =
    loadType === 'total'
      ? 'lado'
      : loadType === 'machine'
        ? 'kg'
        : loadType === 'bodyweight'
          ? 'fijo'
          : 'kg';

  if (isFixed) {
    return (
      <div className="flex h-16 min-w-0 flex-col items-center justify-center rounded-[1.75rem] border border-border bg-secondary px-1 text-secondary-foreground">
        <span className="text-[0.68rem] font-black leading-none text-muted-foreground">
          {label}
        </span>
        <span className="text-base font-black leading-tight tabular-nums">
          {loadType === 'bodyweight' ? '0' : formatDecimal(value)}
        </span>
      </div>
    );
  }

  const selectedIndex = options.indexOf(value);
  const currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
  const nextValue = options[(currentIndex + 1) % options.length];

  return (
    <button
      className="flex h-16 min-w-0 flex-col items-center justify-center rounded-[1.75rem] border border-border bg-secondary px-1 text-secondary-foreground transition active:scale-[0.98]"
      type="button"
      onClick={() => onChange(nextValue)}
      aria-label={`Cambiar incremento de peso, actual ${formatDecimal(
        value,
      )} ${label}`}
    >
      <span className="text-[0.68rem] font-black leading-none text-muted-foreground">
        {label}
      </span>
      <span className="text-base font-black leading-tight tabular-nums">
        {formatDecimal(value)}
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
