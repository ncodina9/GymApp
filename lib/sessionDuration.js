export const defaultSessionDurationOptions = {
  warmupMobilityMinutes: 9,
  feedbackSecondsPerSet: 8,
  exerciseChangeSeconds: 45,
  supersetTransitionSeconds: 15,
};

/**
 * @typedef {object} DurationTrainingSet
 * @property {number=} targetReps
 * @property {number=} targetDurationSeconds
 * @property {number} restSeconds
 * @property {'working' | 'timed'} type
 */

/**
 * @typedef {object} DurationExercise
 * @property {DurationTrainingSet[]} sets
 */

/**
 * @typedef {object} DurationTrainingSession
 * @property {number} estimatedMinutes
 * @property {DurationExercise[]} exercises
 */

/**
 * @typedef {object} DurationExecutionStep
 * @property {number} exerciseIndex
 * @property {number} setIndex
 * @property {number} roundNumber
 * @property {string=} supersetId
 */

/**
 * @typedef {object} SessionDurationOptions
 * @property {number} warmupMobilityMinutes
 * @property {number} feedbackSecondsPerSet
 * @property {number} exerciseChangeSeconds
 * @property {number} supersetTransitionSeconds
 */

/**
 * @typedef {object} SessionDurationEstimate
 * @property {number} totalMinutes
 * @property {number} mobilityMinutes
 * @property {number} executionMinutes
 * @property {number} restMinutes
 * @property {number} changeoverMinutes
 * @property {number} feedbackMinutes
 * @property {number} targetMinutes
 */

/**
 * @param {DurationTrainingSet} set
 */
export const getSetExecutionSeconds = (set) => {
  if (set.type === 'timed') {
    return set.targetDurationSeconds ?? 60;
  }

  return Math.max(20, (set.targetReps ?? 8) * 4);
};

/**
 * @param {DurationExecutionStep} currentStep
 * @param {DurationExecutionStep | undefined} nextStep
 */
export const isSameSupersetRound = (currentStep, nextStep) =>
  nextStep !== undefined &&
  currentStep.supersetId !== undefined &&
  currentStep.supersetId === nextStep.supersetId &&
  currentStep.roundNumber === nextStep.roundNumber;

/**
 * @param {DurationTrainingSession} session
 * @param {DurationExecutionStep[]} steps
 * @param {Partial<SessionDurationOptions>=} options
 * @returns {SessionDurationEstimate}
 */
export const estimateSessionDurationFromSteps = (
  session,
  steps,
  options = {},
) => {
  const resolvedOptions = {
    ...defaultSessionDurationOptions,
    ...options,
  };
  let executionSeconds = 0;
  let restSeconds = 0;
  let changeoverSeconds = 0;
  const feedbackSeconds = steps.length * resolvedOptions.feedbackSecondsPerSet;

  steps.forEach((step, index) => {
    const currentSet =
      session.exercises[step.exerciseIndex].sets[step.setIndex];
    const nextStep = steps[index + 1];
    executionSeconds += getSetExecutionSeconds(currentSet);

    if (!nextStep) {
      return;
    }

    const skipsRest = isSameSupersetRound(step, nextStep);

    if (!skipsRest) {
      restSeconds += currentSet.restSeconds;
    }

    if (step.exerciseIndex !== nextStep.exerciseIndex) {
      changeoverSeconds += skipsRest
        ? resolvedOptions.supersetTransitionSeconds
        : resolvedOptions.exerciseChangeSeconds;
    }
  });

  const mobilitySeconds = resolvedOptions.warmupMobilityMinutes * 60;
  const totalSeconds =
    mobilitySeconds +
    executionSeconds +
    restSeconds +
    changeoverSeconds +
    feedbackSeconds;

  return {
    totalMinutes: Math.round(totalSeconds / 60),
    mobilityMinutes: resolvedOptions.warmupMobilityMinutes,
    executionMinutes: Math.round(executionSeconds / 60),
    restMinutes: Math.round(restSeconds / 60),
    changeoverMinutes: Math.round(changeoverSeconds / 60),
    feedbackMinutes: Math.round(feedbackSeconds / 60),
    targetMinutes: session.estimatedMinutes,
  };
};
