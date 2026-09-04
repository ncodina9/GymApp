'use client';

import {
  Check,
  ChevronRight,
  Minus,
  Plus,
  RotateCcw,
  SkipForward,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { weekSessions } from '@/data/mockPlan';

type Phase = 'today' | 'set' | 'rest' | 'transition' | 'done';

type RecordedSet = {
  exerciseIndex: number;
  setIndex: number;
  reps: number;
  weightKg: number;
  status: 'completed' | 'skipped';
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

const formatDate = (date: string) =>
  new Intl.DateTimeFormat('es-ES', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${date}T12:00:00`));

const formatWeight = (weight: number) =>
  weight === 0
    ? 'Peso corporal'
    : `${Number.isInteger(weight) ? weight : weight.toFixed(1)} kg`;

export default function Home() {
  const [phase, setPhase] = useState<Phase>('today');
  const [selectedSessionId, setSelectedSessionId] = useState(
    weekSessions[0].sessionId,
  );
  const [exerciseIndex, setExerciseIndex] = useState(0);
  const [setIndex, setSetIndex] = useState(0);
  const [editedReps, setEditedReps] = useState(
    weekSessions[0].exercises[0].sets[0].targetReps,
  );
  const [editedWeight, setEditedWeight] = useState(
    weekSessions[0].exercises[0].sets[0].targetWeightKg,
  );
  const [restRemaining, setRestRemaining] = useState(0);
  const [records, setRecords] = useState<RecordedSet[]>([]);
  const [decision, setDecision] = useState<string | null>(null);

  const selectedSession = useMemo(
    () =>
      weekSessions.find((session) => session.sessionId === selectedSessionId) ??
      weekSessions[0],
    [selectedSessionId],
  );
  const currentExercise = selectedSession.exercises[exerciseIndex];
  const currentSet = currentExercise?.sets[setIndex];
  const totalSets = selectedSession.exercises.reduce(
    (sum, exercise) => sum + exercise.sets.length,
    0,
  );
  const completedSets = records.filter(
    (record) => record.status === 'completed',
  ).length;
  const attemptedSets = records.length;
  const progressValue = Math.round((attemptedSets / totalSets) * 100);

  useEffect(() => {
    if (phase !== 'rest' || restRemaining <= 0) {
      return;
    }

    const timer = window.setInterval(() => {
      setRestRemaining((seconds) => Math.max(0, seconds - 1));
    }, 1000);

    return () => window.clearInterval(timer);
  }, [phase, restRemaining]);

  const resetWorkoutPosition = (sessionId = selectedSessionId) => {
    const nextSession =
      weekSessions.find((session) => session.sessionId === sessionId) ??
      weekSessions[0];
    setSelectedSessionId(nextSession.sessionId);
    setExerciseIndex(0);
    setSetIndex(0);
    setRecords([]);
    setDecision(null);
    setRestRemaining(0);
    setEditedReps(nextSession.exercises[0].sets[0].targetReps);
    setEditedWeight(nextSession.exercises[0].sets[0].targetWeightKg);
    setPhase('today');
  };

  const applyPlannedTargets = useCallback(
    (nextExerciseIndex: number, nextSetIndex: number) => {
      const nextSet =
        selectedSession.exercises[nextExerciseIndex].sets[nextSetIndex];
      setEditedReps(nextSet.targetReps);
      setEditedWeight(nextSet.targetWeightKg);
    },
    [selectedSession],
  );

  const moveForward = useCallback(() => {
    setDecision(null);

    if (setIndex + 1 < currentExercise.sets.length) {
      const nextSetIndex = setIndex + 1;
      applyPlannedTargets(exerciseIndex, nextSetIndex);
      setSetIndex(nextSetIndex);
      setPhase('set');
      return;
    }

    if (exerciseIndex + 1 < selectedSession.exercises.length) {
      const nextExerciseIndex = exerciseIndex + 1;
      applyPlannedTargets(nextExerciseIndex, 0);
      setExerciseIndex(nextExerciseIndex);
      setSetIndex(0);
      setPhase('transition');
      return;
    }

    setPhase('done');
  }, [
    applyPlannedTargets,
    currentExercise,
    exerciseIndex,
    selectedSession.exercises,
    setIndex,
  ]);

  const logCurrentSet = useCallback(
    (status: 'completed' | 'skipped') => {
      if (!currentSet) {
        return;
      }

      setRecords((current) => [
        ...current,
        {
          exerciseIndex,
          setIndex,
          reps: editedReps,
          weightKg: editedWeight,
          status,
        },
      ]);

      if (status === 'skipped') {
        moveForward();
        return;
      }

      setRestRemaining(currentSet.restSeconds);
      setPhase('rest');
    },
    [
      currentSet,
      editedReps,
      editedWeight,
      exerciseIndex,
      moveForward,
      setIndex,
    ],
  );

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
        phase,
        sessionId: selectedSession.sessionId,
        sessionLabel: selectedSession.label,
        exercise: currentExercise?.name,
        setIndex: setIndex + 1,
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
        setPhase('set');
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

        if (phase !== 'set' || !currentSet) {
          throw new Error('No hay una serie activa para registrar.');
        }

        if (status !== 'completed' && status !== 'skipped') {
          throw new Error('status debe ser completed o skipped.');
        }

        logCurrentSet(status);
        return {
          status,
          reps: editedReps,
          weightKg: editedWeight,
          exercise: currentExercise.name,
          setIndex: setIndex + 1,
        };
      },
    });

    return () => lifecycle.abort();
  }, [
    attemptedSets,
    currentExercise,
    currentSet,
    editedReps,
    editedWeight,
    logCurrentSet,
    phase,
    selectedSession,
    setIndex,
    totalSets,
  ]);

  const changeSession = (sessionId: string) => {
    resetWorkoutPosition(sessionId);
  };

  return (
    <main className="min-h-dvh bg-background text-foreground">
      <div className="mx-auto flex min-h-dvh w-full max-w-[480px] flex-col px-4 py-4 sm:py-6">
        <header className="mb-4 flex items-center justify-between gap-3">
          <div>
            <p className="text-sm font-semibold text-muted-foreground">
              Semana {selectedSession.week}
            </p>
            <h1 className="text-2xl font-bold tracking-normal">GymApp</h1>
          </div>
          <Button
            aria-label="Reiniciar entrenamiento"
            className="size-11 rounded-full"
            size="icon"
            variant="secondary"
            onClick={() => resetWorkoutPosition()}
          >
            <RotateCcw className="size-5" />
          </Button>
        </header>

        {phase !== 'today' ? (
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

        {phase === 'today' ? (
          <TodayScreen
            selectedSessionId={selectedSessionId}
            onChangeSession={changeSession}
            onStart={() => setPhase('set')}
          />
        ) : null}

        {phase === 'set' && currentSet ? (
          <SetScreen
            exerciseName={currentExercise.name}
            exerciseNotes={currentExercise.notes}
            setIndex={setIndex}
            totalExerciseSets={currentExercise.sets.length}
            reps={editedReps}
            weight={editedWeight}
            restSeconds={currentSet.restSeconds}
            completedSetIndexes={records
              .filter((record) => record.exerciseIndex === exerciseIndex)
              .map((record) => record.setIndex)}
            onRepsChange={setEditedReps}
            onWeightChange={setEditedWeight}
            onComplete={() => logCurrentSet('completed')}
            onSkip={() => logCurrentSet('skipped')}
          />
        ) : null}

        {phase === 'rest' ? (
          <RestScreen
            restRemaining={restRemaining}
            nextLabel={
              setIndex + 1 < currentExercise.sets.length
                ? `Serie ${setIndex + 2} de ${currentExercise.name}`
                : exerciseIndex + 1 < selectedSession.exercises.length
                  ? selectedSession.exercises[exerciseIndex + 1].name
                  : 'Cerrar entrenamiento'
            }
            onAdjustRest={setRestRemaining}
            onContinue={moveForward}
          />
        ) : null}

        {phase === 'transition' ? (
          <TransitionScreen
            completedExercise={selectedSession.exercises[exerciseIndex - 1]}
            nextExercise={currentExercise}
            decision={decision}
            onDecision={setDecision}
            onContinue={() => setPhase('set')}
          />
        ) : null}

        {phase === 'done' ? (
          <DoneScreen
            completedSets={completedSets}
            totalSets={totalSets}
            onRestart={() => resetWorkoutPosition()}
          />
        ) : null}
      </div>
    </main>
  );
}

function TodayScreen({
  selectedSessionId,
  onChangeSession,
  onStart,
}: {
  selectedSessionId: string;
  onChangeSession: (sessionId: string) => void;
  onStart: () => void;
}) {
  const selectedSession =
    weekSessions.find((session) => session.sessionId === selectedSessionId) ??
    weekSessions[0];

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

      <div className="grid grid-cols-2 gap-2">
        {weekSessions.map((session) => (
          <button
            key={session.sessionId}
            className={`min-h-24 rounded-lg border p-3 text-left transition active:scale-[0.98] ${
              session.sessionId === selectedSessionId
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
        onClick={onStart}
      >
        Empezar
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
  completedExercise: { name: string };
  nextExercise: { name: string; notes: string; decisionOptions: string[] };
  decision: string | null;
  onDecision: (value: string) => void;
  onContinue: () => void;
}) {
  return (
    <section className="flex flex-1 flex-col gap-4">
      <div>
        <p className="text-sm font-semibold text-muted-foreground">
          Completado
        </p>
        <h2 className="text-3xl font-black tracking-normal">
          {completedExercise.name}
        </h2>
      </div>
      <div className="rounded-lg border bg-card p-4">
        <p className="text-sm font-semibold text-muted-foreground">Ahora</p>
        <h3 className="mt-1 text-4xl font-black tracking-normal">
          {nextExercise.name}
        </h3>
        <p className="mt-3 text-lg text-muted-foreground">
          {nextExercise.notes}
        </p>
      </div>
      <div className="grid gap-2">
        {nextExercise.decisionOptions.map((option) => (
          <button
            key={option}
            className={`h-14 rounded-lg border px-4 text-left text-lg font-black ${
              decision === option
                ? 'border-primary bg-primary text-primary-foreground'
                : 'border-border bg-secondary text-secondary-foreground'
            }`}
            type="button"
            onClick={() => onDecision(option)}
          >
            {option}
          </button>
        ))}
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
  onRestart,
}: {
  completedSets: number;
  totalSets: number;
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
        className="h-14 rounded-lg text-lg font-black"
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
    <div className="grid grid-cols-[64px_1fr_64px] items-stretch gap-2 rounded-lg border bg-card p-2 shadow-sm">
      <Button
        aria-label={`Bajar ${label}`}
        className="h-full rounded-lg"
        size="icon"
        variant="secondary"
        onClick={onMinus}
      >
        <Minus className="size-7" />
      </Button>
      <div className="flex min-w-0 flex-col items-center justify-center">
        <p className="text-base font-black text-muted-foreground">{label}</p>
        <p className="max-w-full text-center text-[clamp(3rem,18vw,5.25rem)] font-black leading-none tracking-normal">
          {value}
        </p>
      </div>
      <Button
        aria-label={`Subir ${label}`}
        className="h-full rounded-lg"
        size="icon"
        variant="secondary"
        onClick={onPlus}
      >
        <Plus className="size-7" />
      </Button>
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
