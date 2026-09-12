import {
  getCompletedExerciseIds,
  type ExecutionStep,
  type SequenceSession,
} from '@/lib/workoutSequence';

export type WorkoutNavigationPhase = 'set' | 'rest' | 'transition';
export type WorkoutTransitionNextPhase = 'set' | 'rest' | 'done';
export type SetLogStatus = 'completed' | 'skipped';

export type WorkoutTransitionPatch = {
  phase: WorkoutNavigationPhase;
  transitionExerciseIds: string[];
  transitionNextPhase: WorkoutTransitionNextPhase;
  suppressTransitionOnce: boolean;
  exerciseIndex?: number;
  setIndex?: number;
  restRemaining?: number;
  restEndsAt?: undefined;
};

export type WorkoutTransition =
  | { action: 'complete' }
  | {
      action: 'patch';
      patch: WorkoutTransitionPatch;
      restTimer: 'none' | 'start-now' | 'start-after-transition';
    };

export const shouldRestAfterStep = (
  currentStep: ExecutionStep | undefined,
  nextStep: ExecutionStep | undefined,
) =>
  currentStep !== undefined &&
  nextStep !== undefined &&
  (!currentStep.supersetId ||
    currentStep.supersetId !== nextStep.supersetId ||
    nextStep.roundNumber !== currentStep.roundNumber);

export const getAdvanceWorkoutTransition = ({
  session,
  currentStep,
  nextStep,
  suppressTransitionOnce,
}: {
  session: SequenceSession;
  currentStep: ExecutionStep | undefined;
  nextStep: ExecutionStep | undefined;
  suppressTransitionOnce: boolean;
}): WorkoutTransition => {
  const completedExerciseIds = getCompletedExerciseIds(session, currentStep);

  if (!nextStep) {
    if (completedExerciseIds.length > 0) {
      return {
        action: 'patch',
        restTimer: 'none',
        patch: {
          phase: 'transition',
          transitionExerciseIds: completedExerciseIds,
          transitionNextPhase: 'done',
          suppressTransitionOnce: false,
        },
      };
    }

    return { action: 'complete' };
  }

  const shouldShowTransition =
    completedExerciseIds.length > 0 && !suppressTransitionOnce;

  return {
    action: 'patch',
    restTimer: 'none',
    patch: {
      exerciseIndex: nextStep.exerciseIndex,
      setIndex: nextStep.setIndex,
      phase: shouldShowTransition ? 'transition' : 'set',
      transitionExerciseIds: shouldShowTransition ? completedExerciseIds : [],
      transitionNextPhase: 'set',
      suppressTransitionOnce: false,
      restEndsAt: undefined,
    },
  };
};

export const getPostSetWorkoutTransition = ({
  session,
  currentStep,
  nextStep,
  status,
  restSeconds,
  suppressTransitionOnce,
}: {
  session: SequenceSession;
  currentStep: ExecutionStep | undefined;
  nextStep: ExecutionStep | undefined;
  status: SetLogStatus;
  restSeconds: number;
  suppressTransitionOnce: boolean;
}): WorkoutTransition => {
  if (status === 'skipped' || !shouldRestAfterStep(currentStep, nextStep)) {
    return getAdvanceWorkoutTransition({
      session,
      currentStep,
      nextStep,
      suppressTransitionOnce,
    });
  }

  const completedExerciseIds = getCompletedExerciseIds(session, currentStep);

  if (completedExerciseIds.length > 0) {
    return {
      action: 'patch',
      restTimer: 'start-after-transition',
      patch: {
        restRemaining: restSeconds,
        restEndsAt: undefined,
        phase: 'transition',
        transitionExerciseIds: completedExerciseIds,
        transitionNextPhase: 'rest',
        suppressTransitionOnce,
      },
    };
  }

  return {
    action: 'patch',
    restTimer: 'start-now',
    patch: {
      restRemaining: restSeconds,
      restEndsAt: undefined,
      phase: 'rest',
      transitionExerciseIds: [],
      transitionNextPhase: 'set',
      suppressTransitionOnce,
    },
  };
};
