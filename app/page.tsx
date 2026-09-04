'use client';

import {
  Check,
  ChevronRight,
  Download,
  ArrowLeft,
  Minus,
  Plus,
  SkipForward,
} from 'lucide-react';
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
  targetReps: number;
  targetWeightKg: number;
  restSeconds: number;
  type: 'working';
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
  editedReps: session.exercises[0].sets[0].targetReps,
  editedWeight: session.exercises[0].sets[0].targetWeightKg,
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

const csvEscape = (value: string | number) => {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
};

export default function Home() {
  const [draft, setDraft] = useState<WorkoutDraft>(
    () => loadDraft() ?? makeDraft(),
  );
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
    window.localStorage.setItem(storageKey, JSON.stringify(draft));
  }, [draft]);

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
        editedReps: nextSet.targetReps,
        editedWeight: nextSet.targetWeightKg,
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
        id: crypto.randomUUID(),
        performedAt: new Date().toISOString(),
        planId: trainingPlan.planId,
        sessionId: selectedSession.sessionId,
        sessionDate: selectedSession.date,
        exerciseId: currentExercise.exerciseId,
        exerciseIndex: draft.exerciseIndex,
        setIndex: draft.setIndex,
        plannedReps: currentSet.targetReps,
        plannedWeightKg: currentSet.targetWeightKg,
        actualReps: draft.editedReps,
        actualWeightKg: draft.editedWeight,
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
      }));

      if (status === 'skipped') {
        moveForward();
        return;
      }

      patchDraft({ restRemaining: currentSet.restSeconds, phase: 'rest' });
    },
    [
      currentSet,
      draft.editedReps,
      draft.editedWeight,
      draft.editedRir,
      draft.exerciseIndex,
      draft.painKnee,
      draft.painOther,
      draft.painWrist,
      draft.setIndex,
      draft.setNote,
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
    <main className="h-dvh overflow-hidden bg-background text-foreground">
      <div className="mx-auto flex h-dvh w-full max-w-[480px] flex-col overflow-hidden px-4 py-3 sm:py-4">
        <header className="mb-2">
          <p className="text-xs font-black uppercase text-muted-foreground">
            Semana {selectedSession.week}
            {draft.phase !== 'today' ? ` · ${selectedSession.label}` : ''}
          </p>
        </header>

        {draft.phase !== 'today' ? (
          <section className="mb-3">
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
            reps={draft.editedReps}
            weight={draft.editedWeight}
            restSeconds={currentSet.restSeconds}
            completedSetIndexes={draft.records
              .filter((record) => record.exerciseIndex === draft.exerciseIndex)
              .map((record) => record.setIndex)}
            onRepsChange={(editedReps) => patchDraft({ editedReps })}
            onWeightChange={(editedWeight) => patchDraft({ editedWeight })}
            onContinue={() => patchDraft({ phase: 'feedback' })}
            onSkip={() => logCurrentSet('skipped')}
            onBack={() => patchDraft({ phase: 'today' })}
          />
        ) : null}

        {draft.phase === 'feedback' && currentSet ? (
          <FeedbackScreen
            exerciseName={currentExercise.name}
            reps={draft.editedReps}
            weight={draft.editedWeight}
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
      <div className="rounded-lg border bg-card p-4 shadow-sm">
        <p className="text-sm font-semibold text-muted-foreground">Hoy toca</p>
        <h2 className="mt-2 text-4xl font-black tracking-normal">
          {selectedSession.label}
        </h2>
        <p className="mt-2 text-lg text-muted-foreground">
          {selectedSession.focus}
        </p>
        <div className="mt-4 grid grid-cols-3 gap-2 text-center">
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
  reps,
  weight,
  restSeconds,
  onRepsChange,
  onWeightChange,
  onContinue,
  onSkip,
  onBack,
}: {
  exerciseName: string;
  exerciseNotes: string;
  setIndex: number;
  totalExerciseSets: number;
  completedSetIndexes: number[];
  reps: number;
  weight: number;
  restSeconds: number;
  onRepsChange: (value: number) => void;
  onWeightChange: (value: number) => void;
  onContinue: () => void;
  onSkip: () => void;
  onBack: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-muted-foreground">
            Serie {setIndex + 1} de {totalExerciseSets}
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-normal">
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

      <div className="grid flex-1 grid-rows-2 gap-3">
        <TactileNumber
          label="Reps"
          value={String(reps)}
          onMinus={() => onRepsChange(Math.max(1, reps - 1))}
          onPlus={() => onRepsChange(reps + 1)}
        />
        <TactileNumber
          label="Peso"
          value={formatWeight(weight)}
          onMinus={() => onWeightChange(Math.max(0, weight - 2.5))}
          onPlus={() => onWeightChange(weight + 2.5)}
        />
      </div>

      <div className="rounded-lg bg-secondary px-4 py-3 text-base font-medium text-secondary-foreground">
        {exerciseNotes}
        <span className="mt-1 block text-sm text-muted-foreground">
          Descanso propuesto: {restSeconds}s
        </span>
      </div>

      <div className="grid grid-cols-[auto_1fr_auto] gap-3">
        <Button
          aria-label="Volver"
          className="h-16 w-16 rounded-lg"
          size="icon"
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-16 rounded-lg text-xl font-black"
          onClick={onContinue}
        >
          Continuar
          <ChevronRight className="size-6" />
        </Button>
        <Button
          aria-label="Saltar serie"
          className="h-16 w-16 rounded-lg"
          size="icon"
          variant="outline"
          onClick={onSkip}
        >
          <SkipForward className="size-5" />
        </Button>
      </div>
    </section>
  );
}

function RestScreen({
  restRemaining,
  nextLabel,
  onAdjustRest,
  onContinue,
}: {
  restRemaining: number;
  nextLabel: string;
  onAdjustRest: (value: number | ((current: number) => number)) => void;
  onContinue: () => void;
}) {
  const minutes = Math.floor(restRemaining / 60);
  const seconds = String(restRemaining % 60).padStart(2, '0');

  return (
    <section className="flex flex-1 flex-col justify-between gap-5 py-2">
      <div className="text-center">
        <p className="text-lg font-bold text-muted-foreground">Descanso</p>
        <p className="mt-5 text-[7rem] font-black leading-none tabular-nums tracking-normal">
          {minutes}:{seconds}
        </p>
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
  reps,
  weight,
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
  reps: number;
  weight: number;
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
  return (
    <section className="flex flex-1 flex-col gap-3 overflow-hidden">
      <div>
        <p className="text-sm font-semibold text-muted-foreground">
          Feedback serie
        </p>
        <h2 className="text-3xl font-black leading-tight tracking-normal">
          {exerciseName}
        </h2>
      </div>

      <div className="grid grid-cols-2 gap-2 text-center">
        <div className="rounded-lg border bg-card px-3 py-4">
          <p className="text-sm font-black text-muted-foreground">Reps</p>
          <p className="text-5xl font-black leading-none">{reps}</p>
        </div>
        <div className="rounded-lg border bg-card px-3 py-4">
          <p className="text-sm font-black text-muted-foreground">Peso</p>
          <p className="text-4xl font-black leading-none">
            {formatWeight(weight)}
          </p>
        </div>
      </div>

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

      <div className="mt-auto grid grid-cols-[auto_1fr] gap-3">
        <Button
          aria-label="Volver a ajustar serie"
          className="h-16 w-16 rounded-lg"
          size="icon"
          variant="outline"
          onClick={onBack}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <Button
          className="h-16 rounded-lg text-xl font-black"
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
    <div className="grid gap-2 rounded-lg border bg-card p-3">
      <div className="grid grid-cols-[1fr_104px] items-center gap-2">
        <span className="text-sm font-black text-muted-foreground">RIR</span>
        <div className="grid grid-cols-[40px_1fr_40px] items-center gap-1">
          <Button
            aria-label="Bajar RIR"
            className="h-9 w-full rounded-md"
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
            className="h-9 w-full rounded-md"
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
            className={`h-10 rounded-md border text-sm font-black ${
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
    <div className="grid grid-cols-[1fr_repeat(4,40px)] items-center gap-1.5">
      <span className="text-sm font-black text-muted-foreground">{label}</span>
      {[0, 1, 2, 3].map((level) => (
        <button
          key={level}
          className={`h-9 rounded-md border text-sm font-black ${
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
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  onMinus: () => void;
  onPlus: () => void;
}) {
  return (
    <div className="grid grid-rows-[1fr_64px] gap-2 rounded-lg border bg-card p-2 shadow-sm">
      <div className="flex min-w-0 flex-col items-center justify-center">
        <p className="text-base font-black text-muted-foreground">{label}</p>
        <p className="max-w-full text-center text-[clamp(3rem,18vw,5.25rem)] font-black leading-none tracking-normal">
          {value}
        </p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <Button
          aria-label={`Bajar ${label}`}
          className="h-16 w-full rounded-lg"
          variant="secondary"
          onClick={onMinus}
        >
          <Minus className="size-8" />
        </Button>
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
