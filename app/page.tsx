'use client';

import {
  Check,
  ChevronRight,
  Download,
  Minus,
  Plus,
  RotateCcw,
  SkipForward,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import planData from '@/data/trainingPlan.json';

type Phase = 'today' | 'set' | 'rest' | 'transition' | 'done';

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

type RecordedSet = {
  exerciseIndex: number;
  setIndex: number;
  reps: number;
  weightKg: number;
  status: 'completed' | 'skipped';
};

type WorkoutDraft = {
  phase: Phase;
  selectedSessionId: string;
  exerciseIndex: number;
  setIndex: number;
  editedReps: number;
  editedWeight: number;
  restRemaining: number;
  records: RecordedSet[];
  decisions: Record<string, string>;
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
});

const loadDraft = (): WorkoutDraft | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(storageKey);
    return raw ? (JSON.parse(raw) as WorkoutDraft) : null;
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

      const nextRecord: RecordedSet = {
        exerciseIndex: draft.exerciseIndex,
        setIndex: draft.setIndex,
        reps: draft.editedReps,
        weightKg: draft.editedWeight,
        status,
      };

      setDraft((current) => ({
        ...current,
        records: [...current.records, nextRecord],
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
      draft.exerciseIndex,
      draft.setIndex,
      moveForward,
      patchDraft,
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

        if (draft.phase !== 'set' || !currentSet) {
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
    <main className="min-h-dvh bg-background text-foreground">
      <div className="mx-auto flex min-h-dvh w-full max-w-[480px] flex-col px-4 py-4 sm:py-6">
        <header className="mb-3">
          <p className="text-sm font-semibold text-muted-foreground">
            Semana {selectedSession.week}
          </p>
          <h1 className="text-2xl font-bold tracking-normal">GymApp</h1>
        </header>

        {draft.phase !== 'today' ? (
          <section className="mb-4">
            <div className="mb-2 flex items-center justify-between text-sm font-semibold text-muted-foreground">
              <span>{selectedSession.label}</span>
              <span>
                {attemptedSets}/{totalSets}
              </span>
            </div>
            <Progress value={progressValue} />
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
            onComplete={() => logCurrentSet('completed')}
            onSkip={() => logCurrentSet('skipped')}
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

        {draft.phase !== 'today' ? (
          <footer className="mt-4 grid grid-cols-[1fr_auto] gap-2">
            <Button
              className="h-12 rounded-lg text-base font-black"
              variant="secondary"
              onClick={() => patchDraft({ phase: 'today' })}
            >
              Volver
            </Button>
            <Button
              aria-label="Reiniciar entrenamiento"
              className="h-12 w-12 rounded-lg"
              size="icon"
              variant="outline"
              onClick={() => resetWorkoutPosition()}
            >
              <RotateCcw className="size-5" />
            </Button>
          </footer>
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
  onComplete,
  onSkip,
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
  onComplete: () => void;
  onSkip: () => void;
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

      <div className="grid grid-cols-[1fr_auto] gap-3">
        <Button
          className="h-16 rounded-lg text-xl font-black"
          onClick={onComplete}
        >
          Registrar serie
          <Check className="size-6" />
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
          className="h-16 rounded-lg"
          size="icon"
          variant="secondary"
          onClick={onMinus}
        >
          <Minus className="size-8" />
        </Button>
        <Button
          aria-label={`Subir ${label}`}
          className="h-16 rounded-lg"
          size="icon"
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
  records: RecordedSet[],
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

  const rows = session.exercises.map((exercise, exerciseIndex) => {
    const exerciseRecords = records.filter(
      (record) => record.exerciseIndex === exerciseIndex,
    );
    const completed = exerciseRecords.filter(
      (record) => record.status === 'completed',
    );
    const actual = exerciseRecords
      .map((record) =>
        record.status === 'skipped'
          ? 'skipped'
          : `${record.weightKg}x${record.reps}`,
      )
      .join(';');
    const topLoad = completed.reduce(
      (max, record) => Math.max(max, record.weightKg),
      0,
    );
    const totalReps = completed.reduce((sum, record) => sum + record.reps, 0);

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
      '',
      0,
      0,
      '',
      decisions[exercise.exerciseId] ?? '',
      exercise.notes,
    ];
  });

  return [headers, ...rows]
    .map((row) => row.map((value) => csvEscape(value)).join(','))
    .join('\n');
}
