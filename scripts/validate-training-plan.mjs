import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  estimateSessionDurationFromSteps,
  isSameSupersetRound,
} from '../lib/sessionDuration.js';

const planPath = resolve('data/trainingPlan.json');
const trainingPlan = JSON.parse(readFileSync(planPath, 'utf8'));

const errors = [];

const getSupersetMembers = (session, supersetId) =>
  session.exercises
    .map((exercise, exerciseIndex) => ({ exercise, exerciseIndex }))
    .filter((item) => item.exercise.supersetId === supersetId)
    .sort(
      (a, b) =>
        (a.exercise.supersetOrder ?? a.exerciseIndex) -
        (b.exercise.supersetOrder ?? b.exerciseIndex),
    );

const buildExecutionSteps = (session) => {
  const visitedSupersets = new Set();
  const steps = [];

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
      0,
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

const estimateSessionMinutes = (session) => {
  const steps = buildExecutionSteps(session);
  return estimateSessionDurationFromSteps(session, steps).totalMinutes;
};

const shouldRestAfterStep = (currentStep, nextStep) =>
  nextStep !== undefined && !isSameSupersetRound(currentStep, nextStep);

if (
  !Array.isArray(trainingPlan.sessions) ||
  trainingPlan.sessions.length === 0
) {
  errors.push('El plan no contiene sesiones.');
}

let maxEstimate = 0;
let supersetBlocksChecked = 0;

for (const session of trainingPlan.sessions ?? []) {
  const sessionLabel = `${session.date} ${session.sessionLabel}`;
  const steps = buildExecutionSteps(session);
  const plannedSetCount = session.exercises.reduce(
    (total, exercise) => total + exercise.sets.length,
    0,
  );

  if (steps.length === 0) {
    errors.push(`${sessionLabel}: no genera pasos de ejecucion.`);
  }

  if (steps.length !== plannedSetCount) {
    errors.push(
      `${sessionLabel}: genera ${steps.length} pasos, pero hay ${plannedSetCount} series planificadas.`,
    );
  }

  const estimate = estimateSessionMinutes(session);
  maxEstimate = Math.max(maxEstimate, estimate);

  if (estimate > 70) {
    errors.push(`${sessionLabel}: estimacion derivada de ${estimate} min.`);
  }

  for (const exercise of session.exercises) {
    if (
      exercise.exerciseId === 'core-plancha-dead-bug' &&
      exercise.sets.some((set) => set.targetDurationSeconds !== 60)
    ) {
      errors.push(`${sessionLabel}: las planchas deben durar siempre 60 s.`);
    }
  }

  const supersetIds = [
    ...new Set(
      session.exercises
        .map((exercise) => exercise.supersetId)
        .filter((supersetId) => supersetId !== undefined),
    ),
  ];

  for (const supersetId of supersetIds) {
    const members = getSupersetMembers(session, supersetId);
    supersetBlocksChecked += 1;

    if (members.length < 2) {
      errors.push(
        `${sessionLabel}: ${supersetId} tiene menos de 2 ejercicios.`,
      );
    }

    if (
      members.some(
        (member) => typeof member.exercise.supersetOrder !== 'number',
      )
    ) {
      errors.push(
        `${sessionLabel}: ${supersetId} necesita supersetOrder numerico en todos sus ejercicios.`,
      );
    }

    const roundNumbers = [
      ...new Set(
        steps
          .filter((step) => step.supersetId === supersetId)
          .map((step) => step.roundNumber),
      ),
    ];

    for (const roundNumber of roundNumbers) {
      const roundSteps = steps.filter(
        (step) =>
          step.supersetId === supersetId && step.roundNumber === roundNumber,
      );
      const orders = roundSteps.map((step) => step.supersetOrder);
      const sortedOrders = [...orders].sort((a, b) => a - b);

      if (orders.join(',') !== sortedOrders.join(',')) {
        errors.push(
          `${sessionLabel}: ${supersetId} ronda ${roundNumber} no respeta el orden de la superserie.`,
        );
      }

      roundSteps.slice(0, -1).forEach((step, index) => {
        const nextStep = roundSteps[index + 1];

        if (shouldRestAfterStep(step, nextStep)) {
          errors.push(
            `${sessionLabel}: ${supersetId} ronda ${roundNumber} marca descanso entre ejercicios vinculados.`,
          );
        }
      });
    }
  }
}

if (errors.length > 0) {
  console.error('Plan validation failed');
  errors.forEach((error) => console.error(`- ${error}`));
  process.exit(1);
}

console.log('Plan validation OK');
console.log(`Sessions: ${trainingPlan.sessions.length}`);
console.log(`Max derived estimate: ${maxEstimate} min`);
console.log(`Superset blocks checked: ${supersetBlocksChecked}`);
