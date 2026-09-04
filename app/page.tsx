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
  SkipForward,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import planData from '@/data/trainingPlan.json';
import {
  clearSessionEvents,
  loadSessionEvents,
  saveSetEvent,
  type StoredSetEvent,
} from '@/lib/workoutStorage';

type Phase = 'today' | 'set' | 'feedback' | 'rest' | 'transition' | 'done';

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
  weightStep: 1 | 0.5;
  setTimerRemaining: number;
  isSetTimerRunning: boolean;
  restRemaining: number;
  records: StoredSetEvent[];
  decisions: Record<string, string>;
  editedRir: number;
  painKnee: number;
  painWrist: number;
  painOther: number;
  setNote: string;
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

const trainingPlan = planData as TrainingPlan;
const storageKey = `gymapp:${trainingPlan.planId}:draft`;

const fallbackSession = trainingPlan.sessions[0];

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
  editedRir: 2,
  painKnee: 0,
  painWrist: 0,
  painOther: 0,
  setNote: '',
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
    editedRir: draft.editedRir ?? 2,
    editedDurationSeconds: draft.editedDurationSeconds ?? 0,
    weightStep: draft.weightStep ?? 1,
    setTimerRemaining: draft.setTimerRemaining ?? 0,
    isSetTimerRunning: draft.isSetTimerRunning ?? false,
    painKnee: draft.painKnee ?? 0,
    painWrist: draft.painWrist ?? 0,
    painOther: draft.painOther ?? 0,
    setNote: draft.setNote ?? '',
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

const formatWeight = (weight: number) =>
  `${Number.isInteger(weight) ? weight : weight.toFixed(1)} kg`;

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

export default function Home() {
  const [draft, setDraft] = useState<WorkoutDraft>(() => makeDraft());
  const [hasLoadedDraft, setHasLoadedDraft] = useState(false);
  const selectedSession =
    trainingPlan.sessions.find(
      (session) => session.sessionId === draft.selectedSessionId,
    ) ?? fallbackSession;
  const currentExercise = selectedSession.exercises[draft.exerciseIndex];
  const currentSet = currentExercise?.sets[draft.setIndex];
  const totalSets = selectedSession.exercises.reduce(
    (sum, exercise) => sum + exercise.sets.length,
    0,
  );
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
      setHasLoadedDraft(true);
    }, 0);

    return () => window.clearTimeout(timeout);
  }, []);

  useEffect(() => {
    if (!hasLoadedDraft) {
      return;
    }

    window.localStorage.setItem(storageKey, JSON.stringify(draft));
  }, [draft, hasLoadedDraft]);

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
    if (!currentExercise) {
      return;
    }

    if (draft.setIndex + 1 < currentExercise.sets.length) {
      const nextSetIndex = draft.setIndex + 1;
      applyPlannedTargets(draft.exerciseIndex, nextSetIndex);
      patchDraft({ setIndex: nextSetIndex, phase: 'set' });
      return;
    }

    if (draft.exerciseIndex + 1 < selectedSession.exercises.length) {
      const nextExerciseIndex = draft.exerciseIndex + 1;
      applyPlannedTargets(nextExerciseIndex, 0);
      patchDraft({
        exerciseIndex: nextExerciseIndex,
        setIndex: 0,
        phase: 'transition',
      });
      return;
    }

    patchDraft({ phase: 'done' });
  }, [
    applyPlannedTargets,
    currentExercise,
    draft.exerciseIndex,
    draft.setIndex,
    patchDraft,
    selectedSession.exercises.length,
  ]);

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
        setNote: '',
        isSetTimerRunning: false,
      }));

      if (status === 'skipped') {
        moveForward();
        return;
      }

      patchDraft({ restRemaining: currentSet.restSeconds, phase: 'rest' });
    },
    [
      currentSet,
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
    ],
  );

  const changeSession = (sessionId: string) => {
    resetWorkoutPosition(sessionId);
  };

  const startNew = () => {
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
      description: 'Devuelve la sesion, fase y serie visibles en GymApp.',
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
      title: 'Empezar sesion',
      description:
        'Abre la pantalla de la primera serie de la sesion seleccionada.',
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
      <div className="app-screen mx-auto flex w-full max-w-[480px] flex-col overflow-hidden px-4 py-2 sm:py-4">
        <header className="mb-1">
          <p className="text-xs font-black uppercase text-muted-foreground">
            Semana {selectedSession.week}
            {draft.phase !== 'today' ? ` · ${selectedSession.label}` : ''}
          </p>
        </header>

        {draft.phase !== 'today' ? (
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
            onStart={startNew}
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
            painOther={draft.painOther}
            setNote={draft.setNote}
            onRirChange={(editedRir) => patchDraft({ editedRir })}
            onPainKneeChange={(painKnee) => patchDraft({ painKnee })}
            onPainWristChange={(painWrist) => patchDraft({ painWrist })}
            onPainOtherChange={(painOther) => patchDraft({ painOther })}
            onSetNoteChange={(setNote) => patchDraft({ setNote })}
            onBack={() => patchDraft({ phase: 'set' })}
            onRegister={() => logCurrentSet('completed')}
          />
        ) : null}

        {draft.phase === 'rest' ? (
          <RestScreen
            restRemaining={draft.restRemaining}
            restTotal={currentSet?.restSeconds ?? draft.restRemaining}
            nextLabel={
              draft.setIndex + 1 < currentExercise.sets.length
                ? `Serie ${draft.setIndex + 2} de ${currentExercise.name}`
                : draft.exerciseIndex + 1 < selectedSession.exercises.length
                  ? selectedSession.exercises[draft.exerciseIndex + 1].name
                  : 'Cerrar entrenamiento'
            }
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
            completedExercise={
              selectedSession.exercises[draft.exerciseIndex - 1]
            }
            nextExercise={currentExercise}
            decision={
              draft.decisions[
                selectedSession.exercises[draft.exerciseIndex - 1].exerciseId
              ] ?? null
            }
            onDecision={chooseDecision}
            onContinue={() => patchDraft({ phase: 'set' })}
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
}: {
  selectedSession: TrainingSession;
  weekSessions: TrainingSession[];
  hasStarted: boolean;
  onChangeSession: (sessionId: string) => void;
  onResume: () => void;
  onStart: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="flex h-[232px] flex-col rounded-lg border bg-card p-4 shadow-sm">
        <p className="text-sm font-semibold leading-none text-muted-foreground">
          Hoy toca
        </p>
        <h2 className="mt-2 h-[70px] overflow-hidden text-[2rem] font-black leading-[1.08] tracking-normal [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
          {selectedSession.label}
        </h2>
        <p className="mt-2 h-10 overflow-hidden text-base leading-tight text-muted-foreground [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:2]">
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
          className="h-16 rounded-lg text-xl font-black"
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
            className={`min-h-24 rounded-lg border p-3 text-left transition active:scale-[0.98] ${
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
            <span className="mt-1 block text-xl font-black leading-tight">
              {session.label}
            </span>
          </button>
        ))}
      </div>

      <Button
        className="mt-auto h-16 rounded-lg text-xl font-black"
        variant={hasStarted ? 'secondary' : 'default'}
        onClick={onStart}
      >
        {hasStarted ? 'Empezar de cero' : 'Empezar'}
        <ChevronRight className="size-6" />
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
  durationSeconds: number;
  timerRemaining: number;
  isTimerRunning: boolean;
  weightStep: 1 | 0.5;
  restSeconds: number;
  onRepsChange: (value: number) => void;
  onWeightChange: (value: number) => void;
  onWeightStepChange: (value: 1 | 0.5) => void;
  onTimerToggle: () => void;
  onTimerReset: () => void;
  onContinue: () => void;
  onSkip: () => void;
  onBack: () => void;
}) {
  const isTimed = setType === 'timed';

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
            onMinus={() => onRepsChange(Math.max(1, reps - 1))}
            onPlus={() => onRepsChange(reps + 1)}
          />
          <TactileNumber
            label="Peso"
            value={formatWeight(weight)}
            centerControl={
              <WeightStepToggle
                value={weightStep}
                onToggle={() => onWeightStepChange(weightStep === 1 ? 0.5 : 1)}
              />
            }
            onMinus={() => onWeightChange(Math.max(0, weight - weightStep))}
            onPlus={() => onWeightChange(weight + weightStep)}
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
          className="h-14 w-14 shrink-0 rounded-lg p-0"
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-lg text-lg font-black"
          onClick={onContinue}
        >
          Continuar
          <ChevronRight className="size-6" />
        </Button>
        <Button
          aria-label="Saltar serie"
          className="h-14 w-14 shrink-0 rounded-lg p-0"
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
          className="h-14 w-14 shrink-0 rounded-lg p-0"
          style={{ width: '56px' }}
          variant="secondary"
          onClick={onReset}
        >
          <RotateCcw className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-lg text-lg font-black"
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
          className="h-14 rounded-lg text-lg font-black"
          variant="secondary"
          onClick={() => onAdjustRest((value) => Math.max(0, value - 15))}
        >
          -15s
        </Button>
        <Button
          className="h-14 rounded-lg text-lg font-black"
          variant="secondary"
          onClick={() => onAdjustRest((value) => value + 15)}
        >
          +15s
        </Button>
        <Button
          className="h-14 rounded-lg text-lg font-black"
          onClick={onContinue}
        >
          Seguir
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
  painOther,
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onPainOtherChange,
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
  painOther: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onPainOtherChange: (value: number) => void;
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
        painOther={painOther}
        setNote={setNote}
        onRirChange={onRirChange}
        onPainKneeChange={onPainKneeChange}
        onPainWristChange={onPainWristChange}
        onPainOtherChange={onPainOtherChange}
        onSetNoteChange={onSetNoteChange}
      />

      <div
        className="mt-auto grid shrink-0 gap-3"
        style={{ gridTemplateColumns: '56px minmax(0, 1fr)' }}
      >
        <Button
          aria-label="Volver a ajustar serie"
          className="h-14 w-14 shrink-0 rounded-lg p-0"
          style={{ width: '56px' }}
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-14 rounded-lg text-lg font-black"
          onClick={onRegister}
        >
          Registrar serie
          <Check className="size-6" />
        </Button>
      </div>
    </section>
  );
}

const noteOptions = ['OK', 'Pesado', 'Tecnica', 'Molestia'];

function SetFeedback({
  rir,
  painKnee,
  painWrist,
  painOther,
  setNote,
  onRirChange,
  onPainKneeChange,
  onPainWristChange,
  onPainOtherChange,
  onSetNoteChange,
}: {
  rir: number;
  painKnee: number;
  painWrist: number;
  painOther: number;
  setNote: string;
  onRirChange: (value: number) => void;
  onPainKneeChange: (value: number) => void;
  onPainWristChange: (value: number) => void;
  onPainOtherChange: (value: number) => void;
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
            className="h-10 w-full rounded-md"
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
            className="h-10 w-full rounded-md"
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
        label="Muneca"
        value={painWrist}
        onChange={onPainWristChange}
      />
      <PainControl
        label="Otro"
        value={painOther}
        onChange={onPainOtherChange}
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
            onClick={() => onSetNoteChange(setNote === option ? '' : option)}
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
  completedExercise,
  nextExercise,
  decision,
  onDecision,
  onContinue,
}: {
  completedExercise: Exercise;
  nextExercise: Exercise;
  decision: string | null;
  onDecision: (exerciseId: string, value: string) => void;
  onContinue: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="rounded-lg border bg-card p-4">
        <p className="text-sm font-semibold text-muted-foreground">Evaluar</p>
        <h2 className="mt-1 text-4xl font-black tracking-normal">
          {completedExercise.name}
        </h2>
        <div className="mt-4 grid gap-2">
          {completedExercise.decisionOptions.map((option) => (
            <button
              key={option}
              className={`h-14 rounded-lg border px-4 text-left text-lg font-black ${
                decision === option
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-border bg-secondary text-secondary-foreground'
              }`}
              type="button"
              onClick={() => onDecision(completedExercise.exerciseId, option)}
            >
              {option}
            </button>
          ))}
        </div>
      </div>

      <div className="rounded-lg bg-secondary px-4 py-3">
        <p className="text-sm font-semibold text-muted-foreground">Despues</p>
        <p className="text-2xl font-black tracking-normal">
          {nextExercise.name}
        </p>
        <p className="mt-1 text-sm font-medium text-muted-foreground">
          {nextExercise.notes}
        </p>
      </div>

      <Button
        className="mt-auto h-16 rounded-lg text-xl font-black"
        onClick={onContinue}
      >
        Siguiente ejercicio
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
      <Button className="h-14 rounded-lg text-lg font-black" onClick={onExport}>
        Guardar CSV
        <Download className="size-5" />
      </Button>
      <Button
        className="h-14 rounded-lg text-lg font-black"
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
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  centerControl?: ReactNode;
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
          className="h-16 w-full rounded-lg"
          variant="secondary"
          onClick={onMinus}
        >
          <Minus className="size-8" />
        </Button>
        {centerControl}
        <Button
          aria-label={`Subir ${label}`}
          className="h-16 w-full rounded-lg"
          variant="secondary"
          onClick={onPlus}
        >
          <Plus className="size-8" />
        </Button>
      </div>
    </div>
  );
}

function WeightStepToggle({
  value,
  onToggle,
}: {
  value: 1 | 0.5;
  onToggle: () => void;
}) {
  return (
    <button
      className="flex h-16 min-w-0 flex-col items-center justify-center rounded-lg border border-border bg-secondary px-1 text-secondary-foreground transition active:scale-[0.98]"
      type="button"
      onClick={onToggle}
      aria-label={`Cambiar incremento de peso, actual ${value} kg`}
    >
      <span className="text-[0.68rem] font-black leading-none text-muted-foreground">
        kg
      </span>
      <span className="text-base font-black leading-tight tabular-nums">
        {value}
      </span>
    </button>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md bg-secondary px-2 py-3">
      <p className="text-xs font-bold text-muted-foreground">{label}</p>
      <p className="mt-1 text-base font-black">{value}</p>
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
    'actual',
    'top_load_kg',
    'total_reps',
    'rir_last',
    'pain_knee',
    'pain_wrist',
    'pain_other',
    'next_decision',
    'notes',
  ];

  const rows = session.exercises.map((exercise) => {
    const exerciseRecords = records.filter(
      (record) => record.exerciseId === exercise.exerciseId,
    );
    const completed = exerciseRecords.filter(
      (record) => record.status === 'completed',
    );
    const actual = exerciseRecords
      .map((record) =>
        record.status === 'skipped'
          ? 'skipped'
          : record.actualDurationSeconds !== undefined
            ? `${record.actualDurationSeconds}s`
            : `${record.actualWeightKg}x${record.actualReps}`,
      )
      .join(';');
    const topLoad = completed.reduce(
      (max, record) => Math.max(max, record.actualWeightKg),
      0,
    );
    const totalReps = completed.reduce(
      (sum, record) => sum + record.actualReps,
      0,
    );
    const lastCompleted = completed.at(-1);
    const painKnee = Math.max(
      0,
      ...exerciseRecords.map((record) => record.painKnee),
    );
    const painWrist = Math.max(
      0,
      ...exerciseRecords.map((record) => record.painWrist),
    );
    const painOther = Math.max(
      0,
      ...exerciseRecords.map((record) => record.painOther),
    );
    const setNotes = exerciseRecords
      .map((record) => record.note)
      .filter(Boolean)
      .join('; ');

    return [
      session.date,
      session.week,
      session.sessionLabel,
      exercise.name,
      exercise.type,
      exercise.target,
      actual,
      topLoad,
      totalReps,
      lastCompleted?.rirLast ?? '',
      painKnee,
      painWrist,
      painOther || '',
      decisions[exercise.exerciseId] ?? '',
      [exercise.notes, setNotes].filter(Boolean).join(' | '),
    ];
  });

  return [headers, ...rows]
    .map((row) => row.map((value) => csvEscape(value)).join(','))
    .join('\n');
}
