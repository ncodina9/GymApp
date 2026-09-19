export type SequenceSet = {
  restSeconds: number;
};

export type SequenceExercise = {
  exerciseId: string;
  name: string;
  baseExerciseName?: string;
  supersetId?: string;
  supersetOrder?: number;
  sets: SequenceSet[];
};

export type SequenceSession = {
  exercises: SequenceExercise[];
};

export type ExecutionStep = {
  exerciseIndex: number;
  setIndex: number;
  roundNumber: number;
  supersetId?: string;
  supersetOrder?: number;
  completesExercise: boolean;
  completesSuperset: boolean;
};

export type SequenceRecord = Pick<ExecutionStep, 'exerciseIndex' | 'setIndex'>;

export type PendingExecutionOption = {
  id: string;
  step: ExecutionStep;
  exerciseIndexes: number[];
  label: string;
  isSuperset: boolean;
};

export const getSupersetMembers = (
  session: SequenceSession,
  supersetId: string,
) =>
  session.exercises
    .map((exercise, exerciseIndex) => ({ exercise, exerciseIndex }))
    .filter((item) => item.exercise.supersetId === supersetId)
    .sort(
      (a, b) =>
        (a.exercise.supersetOrder ?? a.exerciseIndex) -
        (b.exercise.supersetOrder ?? b.exerciseIndex),
    );

export const getSupersetRoundCount = (
  session: SequenceSession,
  supersetId: string,
) =>
  Math.max(
    0,
    ...getSupersetMembers(session, supersetId).map(
      (member) => member.exercise.sets.length,
    ),
  );

export const buildExecutionSteps = (
  session: SequenceSession,
): ExecutionStep[] => {
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

export const getStepIndex = (
  steps: ExecutionStep[],
  exerciseIndex: number,
  setIndex: number,
) =>
  steps.findIndex(
    (step) =>
      step.exerciseIndex === exerciseIndex && step.setIndex === setIndex,
  );

const getStepKey = (step: Pick<ExecutionStep, 'exerciseIndex' | 'setIndex'>) =>
  `${step.exerciseIndex}:${step.setIndex}`;

const getAttemptedStepKeys = (records: SequenceRecord[]) =>
  new Set(records.map(getStepKey));

export const getNextPendingStep = ({
  steps,
  records,
  currentStepIndex,
}: {
  steps: ExecutionStep[];
  records: SequenceRecord[];
  currentStepIndex: number;
}) => {
  const attemptedStepKeys = getAttemptedStepKeys(records);
  const remainingSteps = steps.filter(
    (step, index) =>
      index !== currentStepIndex && !attemptedStepKeys.has(getStepKey(step)),
  );

  if (remainingSteps.length === 0) {
    return undefined;
  }

  const stepsAfterCurrent = steps.slice(Math.max(0, currentStepIndex + 1));
  const nextInPlan = stepsAfterCurrent.find(
    (step) => !attemptedStepKeys.has(getStepKey(step)),
  );

  return nextInPlan ?? remainingSteps[0];
};

export const getPendingExecutionOptions = ({
  session,
  steps,
  records,
  currentStepIndex,
}: {
  session: SequenceSession;
  steps: ExecutionStep[];
  records: SequenceRecord[];
  currentStepIndex: number;
}): PendingExecutionOption[] => {
  const attemptedStepKeys = getAttemptedStepKeys(records);
  const seenOptionIds = new Set<string>();

  return steps.reduce<PendingExecutionOption[]>((options, step) => {
    if (
      attemptedStepKeys.has(getStepKey(step)) ||
      steps.indexOf(step) === currentStepIndex
    ) {
      return options;
    }

    const optionId = step.supersetId
      ? `superset:${step.supersetId}`
      : `exercise:${step.exerciseIndex}`;

    if (seenOptionIds.has(optionId)) {
      return options;
    }

    seenOptionIds.add(optionId);

    if (step.supersetId) {
      const members = getSupersetMembers(session, step.supersetId);
      const memberNames = members.map(
        ({ exercise }) => exercise.baseExerciseName ?? exercise.name,
      );

      options.push({
        id: optionId,
        step,
        exerciseIndexes: members.map((member) => member.exerciseIndex),
        label: memberNames.join(' + '),
        isSuperset: true,
      });
      return options;
    }

    const exercise = session.exercises[step.exerciseIndex];
    options.push({
      id: optionId,
      step,
      exerciseIndexes: [step.exerciseIndex],
      label: exercise.baseExerciseName ?? exercise.name,
      isSuperset: false,
    });
    return options;
  }, []);
};

export const getCompletedExerciseIds = (
  session: SequenceSession,
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

export const getNextStepLabel = (
  session: SequenceSession,
  currentStep: ExecutionStep | undefined,
  nextStep: ExecutionStep | undefined,
) => {
  if (!nextStep) {
    return 'Cerrar entrenamiento';
  }

  const nextExercise = session.exercises[nextStep.exerciseIndex];
  const nextExerciseName = nextExercise.baseExerciseName ?? nextExercise.name;

  if (
    currentStep?.supersetId &&
    currentStep.supersetId === nextStep.supersetId
  ) {
    return `${nextExerciseName} · ronda ${nextStep.roundNumber}`;
  }

  if (currentStep?.exerciseIndex === nextStep.exerciseIndex) {
    return `Serie ${nextStep.setIndex + 1} de ${nextExerciseName}`;
  }

  return nextExerciseName;
};
