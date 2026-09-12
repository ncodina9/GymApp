import {
  getStepIndex,
  getSupersetMembers,
  getSupersetRoundCount,
  type ExecutionStep,
  type SequenceSession,
} from '@/lib/workoutSequence';

export type WorkoutProgressRecord = {
  status: 'completed' | 'skipped';
  exerciseIndex: number;
  setIndex: number;
};

export type WorkoutProgressPosition = {
  phase: string;
  exerciseIndex: number;
  setIndex: number;
};

export type WorkoutProgressSummary = {
  currentStepIndex: number;
  currentStep?: ExecutionStep;
  nextStep?: ExecutionStep;
  supersetMembers: ReturnType<typeof getSupersetMembers>;
  supersetRoundCount?: number;
  nextLinkedStep?: ExecutionStep;
  totalSets: number;
  completedSets: number;
  attemptedSets: number;
  progressValue: number;
  hasStarted: boolean;
  completedSetIndexes: number[];
};

const activeProgressPhases = new Set([
  'edit-set',
  'feedback',
  'rest',
  'transition',
]);

export const getWorkoutProgressSummary = ({
  session,
  steps,
  records,
  position,
}: {
  session: SequenceSession;
  steps: ExecutionStep[];
  records: WorkoutProgressRecord[];
  position: WorkoutProgressPosition;
}): WorkoutProgressSummary => {
  const currentStepIndex = getStepIndex(
    steps,
    position.exerciseIndex,
    position.setIndex,
  );
  const currentStep =
    currentStepIndex >= 0 ? steps[currentStepIndex] : undefined;
  const nextStep =
    currentStepIndex >= 0 ? steps[currentStepIndex + 1] : undefined;
  const supersetMembers =
    currentStep?.supersetId !== undefined
      ? getSupersetMembers(session, currentStep.supersetId)
      : [];
  const supersetRoundCount =
    currentStep?.supersetId !== undefined
      ? getSupersetRoundCount(session, currentStep.supersetId)
      : undefined;
  const nextLinkedStep =
    currentStep?.supersetId !== undefined &&
    nextStep?.supersetId === currentStep.supersetId &&
    nextStep.roundNumber === currentStep.roundNumber
      ? nextStep
      : undefined;
  const totalSets = steps.length;
  const completedSets = records.filter(
    (record) => record.status === 'completed',
  ).length;
  const attemptedSets = records.length;
  const progressValue =
    totalSets > 0 ? Math.round((attemptedSets / totalSets) * 100) : 0;
  const hasStarted =
    records.length > 0 ||
    position.exerciseIndex > 0 ||
    position.setIndex > 0 ||
    activeProgressPhases.has(position.phase);
  const completedSetIndexes = records
    .filter((record) => record.exerciseIndex === position.exerciseIndex)
    .map((record) => record.setIndex);

  return {
    currentStepIndex,
    ...(currentStep ? { currentStep } : {}),
    ...(nextStep ? { nextStep } : {}),
    supersetMembers,
    ...(supersetRoundCount !== undefined ? { supersetRoundCount } : {}),
    ...(nextLinkedStep ? { nextLinkedStep } : {}),
    totalSets,
    completedSets,
    attemptedSets,
    progressValue,
    hasStarted,
    completedSetIndexes,
  };
};
