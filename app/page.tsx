'use client';

import {
  Check,
  ChevronRight,
  Download,
  ArrowLeft,
  Minus,
  Pause,
  Play,
  Plus,
  RotateCcw,
  Settings,
  SkipForward,
  Trash2,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Switch } from '@/components/ui/switch';
import planData from '@/data/trainingPlan.json';
import {
  clearSessionEvents,
  loadSessionEvents,
  saveSetEvent,
  type StoredSetEvent,
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
  restRemaining: number;
  records: StoredSetEvent[];
  decisions: Record<string, string>;
  transitionExerciseIds: string[];
  transitionNextPhase: 'set' | 'done';
  editedRir: number;
  painKnee: number;
  painWrist: number;
  painOther: number;
  setNote: string;
};

type WakeLockSentinel = {
  release: () => Promise<void>;
};

type WakeLockNavigator = Navigator & {
  wakeLock?: {
    request: (type: 'screen') => Promise<WakeLockSentinel>;
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

const trainingPlan = planData as TrainingPlan;
const storageKey = `gymapp:${trainingPlan.planId}:draft`;
const themeStorageKey = 'gymapp:appearance-theme';
const wakeLockStorageKey = 'gymapp:keep-screen-awake';

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
  back: 'border-[var(--action-back-border)] bg-[var(--action-back)] text-[var(--action-back-foreground)] hover:bg-[var(--action-back-hover)]',
  skip: 'border-[var(--action-skip-border)] bg-[var(--action-skip)] text-[var(--action-skip-foreground)] hover:bg-[var(--action-skip-hover)]',
  reset:
    'border-[var(--action-reset-border)] bg-[var(--action-reset)] text-[var(--action-reset-foreground)] hover:bg-[var(--action-reset-hover)]',
  delete:
    'border-[var(--action-delete-border)] bg-[var(--action-delete)] text-[var(--action-delete-foreground)] hover:bg-[var(--action-delete-hover)]',
  minus:
    'border-[var(--action-minus-border)] bg-[var(--action-minus)] text-[var(--action-minus-foreground)] hover:bg-[var(--action-minus-hover)]',
  plus: 'border-[var(--action-plus-border)] bg-[var(--action-plus)] text-[var(--action-plus-foreground)] hover:bg-[var(--action-plus-hover)]',
  rest: 'border-[var(--action-rest-border)] bg-[var(--action-rest)] text-[var(--action-rest-foreground)] hover:bg-[var(--action-rest-hover)]',
};

const registerServiceWorker = () => {
  if (
    typeof window === 'undefined' ||
    !('serviceWorker' in navigator) ||
    window.location.protocol === 'http:'
  ) {
    return;
  }

  const register = () => {
    void navigator.serviceWorker.register('/sw.js').catch(() => undefined);
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

const csvEscape = (value: string | number) => {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
};

const formatDecimal = (value: number) => {
  if (Number.isInteger(value)) {
    return String(value);
  }

  return Number(value.toFixed(2)).toString();
};

const formatCsvNumber = (value: number) => formatDecimal(value);

type LoadType =
  | 'total'
  | 'external'
  | 'per_dumbbell'
  | 'machine'
  | 'bodyweight';

const inferLoadType = (exercise: Exercise | undefined): LoadType => {
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

const formatCsvTarget = (target: string, loadType: LoadType) =>
  loadType === 'external'
    ? target.replace(/@\s*(\d+(?:[.,]\d+)?)\s*kg/i, '@ +$1 kg')
    : target;

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

type ExecutionStep = {
  exerciseIndex: number;
  setIndex: number;
  roundNumber: number;
  supersetId?: string;
  supersetOrder?: number;
  completesExercise: boolean;
  completesSuperset: boolean;
};

const getSupersetMembers = (session: TrainingSession, supersetId: string) =>
  session.exercises
    .map((exercise, exerciseIndex) => ({ exercise, exerciseIndex }))
    .filter((item) => item.exercise.supersetId === supersetId)
    .sort(
      (a, b) =>
        (a.exercise.supersetOrder ?? a.exerciseIndex) -
        (b.exercise.supersetOrder ?? b.exerciseIndex),
    );

const buildExecutionSteps = (session: TrainingSession): ExecutionStep[] => {
  const visitedSupersets = new Set<string>();
  const steps: ExecutionStep[] = [];

  session.exercises.forEach((exercise, exerciseIndex) => {
    if (!exercise.supersetId) {
      exercise.sets.forEach((_, setIndex) => {
        steps.push({
          exerciseIndex,
          setIndex,
          roundNumber: setIndex + 1,
          completesExercise: setIndex === exercise.sets.length - 1,
          completesSuperset: false,
        });
      });
      return;
    }

    if (visitedSupersets.has(exercise.supersetId)) {
      return;
    }

    visitedSupersets.add(exercise.supersetId);

    const members = getSupersetMembers(session, exercise.supersetId);
    const roundCount = Math.max(
      ...members.map((member) => member.exercise.sets.length),
    );

    Array.from({ length: roundCount }).forEach((_, setIndex) => {
      members.forEach((member, memberIndex) => {
        if (!member.exercise.sets[setIndex]) {
          return;
        }

        steps.push({
          exerciseIndex: member.exerciseIndex,
          setIndex,
          roundNumber: setIndex + 1,
          supersetId: exercise.supersetId,
          supersetOrder: member.exercise.supersetOrder,
          completesExercise: setIndex === member.exercise.sets.length - 1,
          completesSuperset:
            setIndex === roundCount - 1 && memberIndex === members.length - 1,
        });
      });
    });
  });

  return steps;
};

const getStepIndex = (
  steps: ExecutionStep[],
  exerciseIndex: number,
  setIndex: number,
) =>
  steps.findIndex(
    (step) =>
      step.exerciseIndex === exerciseIndex && step.setIndex === setIndex,
  );

const getCompletedExerciseIds = (
  session: TrainingSession,
  step: ExecutionStep | undefined,
) => {
  if (!step) {
    return [];
  }

  if (step.supersetId && step.completesSuperset) {
    return getSupersetMembers(session, step.supersetId).map(
      (member) => member.exercise.exerciseId,
    );
  }

  if (step.supersetId || !step.completesExercise) {
    return [];
  }

  return [session.exercises[step.exerciseIndex].exerciseId];
};

const getNextStepLabel = (
  session: TrainingSession,
  currentStep: ExecutionStep | undefined,
  nextStep: ExecutionStep | undefined,
) => {
  if (!nextStep) {
    return 'Cerrar entrenamiento';
  }

  const nextExercise = session.exercises[nextStep.exerciseIndex];

  if (
    currentStep?.supersetId &&
    currentStep.supersetId === nextStep.supersetId
  ) {
    return `${nextExercise.name} · ronda ${nextStep.roundNumber}`;
  }

  if (currentStep?.exerciseIndex === nextStep.exerciseIndex) {
    return `Serie ${nextStep.setIndex + 1} de ${nextExercise.name}`;
  }

  return nextExercise.name;
};

export default function Home() {
  const [draft, setDraft] = useState<WorkoutDraft>(() => makeDraft());
  const [hasLoadedDraft, setHasLoadedDraft] = useState(false);
  const [appearanceTheme, setAppearanceTheme] =
    useState<AppearanceTheme>('system');
  const [keepScreenAwake, setKeepScreenAwake] = useState(false);
  const [settingsReturnPhase, setSettingsReturnPhase] =
    useState<Phase>('today');
  const selectedSession =
    trainingPlan.sessions.find(
      (session) => session.sessionId === draft.selectedSessionId,
    ) ?? fallbackSession;
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
  const totalSets = executionSteps.length;
  const completedSets = draft.records.filter(
    (record) => record.status === 'completed',
  ).length;
  const attemptedSets = draft.records.length;
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
    registerServiceWorker();
  }, []);

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
    if (!hasLoadedDraft) {
      return;
    }

    window.localStorage.setItem(wakeLockStorageKey, String(keepScreenAwake));
  }, [hasLoadedDraft, keepScreenAwake]);

  useEffect(() => {
    if (!keepScreenAwake || typeof navigator === 'undefined') {
      return;
    }

    const wakeLock = (navigator as WakeLockNavigator).wakeLock;

    if (!wakeLock) {
      return;
    }

    let released = false;
    let lock: WakeLockSentinel | null = null;

    const requestWakeLock = async () => {
      if (released || document.visibilityState !== 'visible') {
        return;
      }

      try {
        lock = await wakeLock.request('screen');
      } catch {
        lock = null;
      }
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        void requestWakeLock();
      }
    };

    void requestWakeLock();
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      released = true;
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      void lock?.release().catch(() => undefined);
    };
  }, [keepScreenAwake]);

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
      void clearSessionEvents(nextSession.sessionId).catch(() => undefined);
      setDraft(makeDraft(nextSession));
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

  const moveForward = useCallback(() => {
    if (!currentExercise || !currentStep) {
      return;
    }

    const completedExerciseIds = getCompletedExerciseIds(
      selectedSession,
      currentStep,
    );

    if (!nextStep) {
      patchDraft(
        completedExerciseIds.length > 0
          ? {
              phase: 'transition',
              transitionExerciseIds: completedExerciseIds,
              transitionNextPhase: 'done',
            }
          : { phase: 'done' },
      );
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
    (status: 'completed' | 'skipped') => {
      if (!currentSet) {
        return;
      }

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

      void saveSetEvent(nextRecord).catch(() => undefined);

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
        return;
      }

      patchDraft({ restRemaining: currentSet.restSeconds, phase: 'rest' });
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
    resetWorkoutPosition(sessionId);
  };

  const previewTraining = () => {
    patchDraft({ phase: 'preview' });
  };

  const beginTraining = () => {
    resetWorkoutPosition(draft.selectedSessionId);
    patchDraft({ phase: 'set' });
  };

  const resume = () => {
    patchDraft({ phase: currentSet ? 'set' : 'today' });
  };

  const chooseDecision = (exerciseId: string, decision: string) => {
    setDraft((current) => ({
      ...current,
      decisions: { ...current.decisions, [exerciseId]: decision },
    }));
  };

  const clearAllLocalData = () => {
    const shouldClear = window.confirm(
      'Borrar todos los entrenamientos guardados en este dispositivo?',
    );

    if (!shouldClear) {
      return;
    }

    void Promise.all(
      trainingPlan.sessions.map((session) =>
        clearSessionEvents(session.sessionId),
      ),
    )
      .catch(() => undefined)
      .finally(() => {
        window.localStorage.removeItem(storageKey);
        setDraft(makeDraft());
      });
  };

  const exportCsv = async () => {
    const csv = buildWorkoutCsv(
      selectedSession,
      draft.records,
      draft.decisions,
    );
    const fileName = `${selectedSession.date}-${selectedSession.label
      .toLowerCase()
      .replaceAll(' ', '-')}.csv`;
    const file = new File([csv], fileName, { type: 'text/csv;charset=utf-8' });

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

  const openSettings = (returnPhase = draft.phase) => {
    setSettingsReturnPhase(returnPhase);
    patchDraft({ phase: 'settings' });
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
        patchDraft({ phase: 'set' });
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

        logCurrentSet(status);
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
      <div className="app-screen mx-auto flex w-full max-w-[480px] flex-col overflow-hidden px-4 pt-3 pb-[calc(1rem+env(safe-area-inset-bottom))] sm:py-4">
        <header className="mb-1">
          <p className="text-xs font-black uppercase text-muted-foreground">
            {draft.phase === 'settings'
              ? 'Ajustes'
              : draft.phase === 'preview'
                ? `Semana ${selectedSession.week} · Vista previa`
                : `Semana ${selectedSession.week}${
                    draft.phase !== 'today' ? ` · ${selectedSession.label}` : ''
                  }`}
          </p>
        </header>

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
            onBack={() => patchDraft({ phase: 'today' })}
            onStart={beginTraining}
          />
        ) : null}

        {draft.phase === 'settings' ? (
          <SettingsScreen
            theme={appearanceTheme}
            keepScreenAwake={keepScreenAwake}
            selectedSessionLabel={selectedSession.label}
            onThemeChange={setAppearanceTheme}
            onKeepScreenAwakeChange={setKeepScreenAwake}
            onResetCurrent={() => resetWorkoutPosition(draft.selectedSessionId)}
            onClearAllData={clearAllLocalData}
            onBack={() => patchDraft({ phase: settingsReturnPhase })}
          />
        ) : null}

        {draft.phase === 'set' && currentSet ? (
          <SetScreen
            exerciseName={currentExercise.name}
            exerciseNotes={currentExercise.notes}
            setIndex={draft.setIndex}
            totalExerciseSets={currentExercise.sets.length}
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
            onSkip={() => logCurrentSet('skipped')}
            onBack={() => patchDraft({ phase: 'today' })}
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
            onRegister={() => logCurrentSet('completed')}
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
            onContinue={() =>
              patchDraft({
                phase: draft.transitionNextPhase,
                transitionExerciseIds: [],
              })
            }
          />
        ) : null}

        {draft.phase === 'done' ? (
          <DoneScreen
            completedSets={completedSets}
            totalSets={totalSets}
            onExport={exportCsv}
            onRestart={() => resetWorkoutPosition()}
          />
        ) : null}
      </div>
    </main>
  );
}

function TodayScreen({
  selectedSession,
  weekSessions,
  hasStarted,
  onChangeSession,
  onResume,
  onStart,
  onSettings,
}: {
  selectedSession: TrainingSession;
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
        <h2 className="mt-3 h-[78px] overflow-hidden text-[2rem] font-black leading-[1.08] tracking-normal [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {selectedSession.label}
        </h2>
        <p className="mt-3 h-11 overflow-hidden text-base leading-tight text-muted-foreground [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {selectedSession.focus}
        </p>
        <div className="mt-auto grid grid-cols-3 gap-2 text-center">
          <Metric label="Fecha" value={formatDate(selectedSession.date)} />
          <Metric
            label="Tiempo"
            value={`${selectedSession.estimatedMinutes}m`}
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
  onBack,
  onStart,
}: {
  session: TrainingSession;
  onBack: () => void;
  onStart: () => void;
}) {
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
          <Metric label="Tiempo" value={`${session.estimatedMinutes}m`} />
          <Metric label="Bloques" value={`${session.exercises.length}`} />
        </div>
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
          aria-label="Volver"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.back}`}
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
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
  theme,
  keepScreenAwake,
  selectedSessionLabel,
  onThemeChange,
  onKeepScreenAwakeChange,
  onResetCurrent,
  onClearAllData,
  onBack,
}: {
  theme: AppearanceTheme;
  keepScreenAwake: boolean;
  selectedSessionLabel: string;
  onThemeChange: (theme: AppearanceTheme) => void;
  onKeepScreenAwakeChange: (enabled: boolean) => void;
  onResetCurrent: () => void;
  onClearAllData: () => void;
  onBack: () => void;
}) {
  return (
    <section className="flex min-h-0 flex-1 flex-col gap-4 overflow-hidden">
      <div className="min-h-0 flex-1 rounded-lg border bg-card p-4 shadow-sm">
        <p className="text-sm font-semibold text-muted-foreground">Ajustes</p>
        <h2 className="mt-1 text-[2rem] font-black leading-tight tracking-normal">
          Apariencia
        </h2>

        <div className="mt-4 grid gap-2">
          {appearanceThemes.map((option) => (
            <button
              key={option.value}
              className={`flex h-16 items-center justify-between rounded-[1.75rem] border px-5 text-left text-lg font-black transition active:scale-[0.98] ${
                theme === option.value
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-border bg-secondary text-secondary-foreground'
              }`}
              type="button"
              onClick={() => onThemeChange(option.value)}
            >
              <span>{option.label}</span>
              <span
                className={`size-6 rounded-full border-2 ${
                  theme === option.value
                    ? 'border-primary-foreground bg-primary-foreground'
                    : 'border-muted-foreground/45 bg-transparent'
                }`}
                aria-hidden="true"
              />
            </button>
          ))}
        </div>

        <div className="mt-5">
          <p className="text-sm font-semibold text-muted-foreground">
            Entrenamiento
          </p>
          <div className="mt-2 flex min-h-16 w-full items-center justify-between gap-4 rounded-[1.75rem] border bg-secondary px-5 py-3 text-left text-secondary-foreground">
            <span className="min-w-0">
              <span className="block text-base font-black leading-tight">
                Pantalla siempre encendida
              </span>
              <span className="mt-0.5 block text-xs font-bold leading-tight text-muted-foreground">
                Evita el bloqueo si el iPhone lo permite.
              </span>
            </span>
            <Switch
              checked={keepScreenAwake}
              onCheckedChange={onKeepScreenAwakeChange}
              aria-label="Mantener pantalla encendida"
            />
          </div>
        </div>

        <div className="mt-5">
          <p className="text-sm font-semibold text-muted-foreground">
            Datos locales
          </p>
          <div className="mt-2 grid gap-2">
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
              className={`h-14 justify-start rounded-[1.75rem] px-5 text-left font-black ${actionStyles.delete}`}
              variant="outline"
              onClick={onClearAllData}
            >
              <Trash2 className="size-5" />
              Borrar todo local
            </Button>
          </div>
        </div>
      </div>

      <Button
        className={`h-14 rounded-[1.75rem] text-lg font-black ${actionStyles.back}`}
        variant="outline"
        onClick={onBack}
      >
        Volver
      </Button>
    </section>
  );
}

function SetScreen({
  exerciseName,
  exerciseNotes,
  setIndex,
  totalExerciseSets,
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
}: {
  exerciseName: string;
  exerciseNotes: string;
  setIndex: number;
  totalExerciseSets: number;
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
}) {
  const isTimed = setType === 'timed';
  const normalizedWeightStep = normalizeWeightStep(weightStep, loadType);

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
      <div className="flex shrink-0 items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-muted-foreground">
            Serie {setIndex + 1} de {totalExerciseSets}
          </p>
          <h2 className="text-[1.65rem] font-black leading-tight tracking-normal">
            {exerciseName}
          </h2>
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
          aria-label="Volver"
          className={`h-14 w-14 shrink-0 rounded-[1.75rem] p-0 ${actionStyles.back}`}
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
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
        >
          <SkipForward className="size-5" />
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
    <div className="flex min-h-0 flex-1 flex-col items-center justify-center rounded-lg border bg-card p-4 shadow-sm">
      <p className="text-base font-black text-muted-foreground">Tiempo</p>
      <CountdownCircle
        label="Tiempo de serie"
        remainingSeconds={remainingSeconds}
        totalSeconds={durationSeconds}
        sizeClassName="my-4 size-52"
        textClassName="text-[4.5rem]"
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
}: {
  label: string;
  remainingSeconds: number;
  totalSeconds: number;
  sizeClassName: string;
  textClassName: string;
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
          className="stroke-primary transition-[stroke-dashoffset] duration-300 ease-linear"
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
  return (
    <section className="flex flex-1 flex-col justify-between gap-5 py-2">
      <div className="text-center">
        <p className="text-lg font-bold text-muted-foreground">Descanso</p>
        <CountdownCircle
          label="Descanso"
          remainingSeconds={restRemaining}
          totalSeconds={Math.max(restTotal, restRemaining)}
          sizeClassName="mx-auto mt-5 size-64"
          textClassName="text-[5rem]"
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
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-[1.75rem] text-lg font-black"
          onClick={onRegister}
        >
          Registrar serie
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
  onExport,
  onRestart,
}: {
  completedSets: number;
  totalSets: number;
  onExport: () => void;
  onRestart: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col justify-center gap-5 text-center">
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

function buildWorkoutCsv(
  session: TrainingSession,
  records: StoredSetEvent[],
  decisions: Record<string, string>,
) {
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
      formatCsvTarget(exercise?.target ?? '', loadType),
      record.setIndex + 1,
      record.status === 'completed' ? 'done' : 'skipped',
      isSkipped || isUnknownMachineLoad
        ? ''
        : formatCsvNumber(record.actualWeightKg),
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
}
