import {
  inferEquipmentLoadType,
  type ExportExercise,
  type ExportTrainingSet,
  type LoadType,
} from '@/lib/sessionExport';

export type ExerciseEquipment = NonNullable<ExportExercise['equipment']>;
export type WeightStep = 0.5 | 1 | 1.25 | 2.5 | 5;

export type PreparedSetTargets = {
  editedReps: number;
  editedWeight: number;
  editedDurationSeconds: number;
  setTimerRemaining: number;
  isSetTimerRunning: false;
  setTimerEndsAt: undefined;
};

export type SetTargetOverride = Pick<
  PreparedSetTargets,
  'editedReps' | 'editedWeight' | 'editedDurationSeconds'
> & {
  // Equivalencia total usada al cambiar entre variantes de material.
  referenceWeightKg?: number;
};

export type BarbellPlateLayout = {
  barWeightKg: number;
  sidePlatesKg: number[];
};

export const getSetTargetKey = (exerciseId: string, setIndex: number) =>
  `${exerciseId}:${setIndex}`;

export const haveSamePlannedTarget = (
  previousSet: ExportTrainingSet,
  nextSet: ExportTrainingSet,
) =>
  previousSet.targetReps === nextSet.targetReps &&
  previousSet.targetWeightKg === nextSet.targetWeightKg &&
  previousSet.targetDurationSeconds === nextSet.targetDurationSeconds;

export const getHomogeneousFutureSetIndexes = (
  sets: ExportTrainingSet[],
  currentSetIndex: number,
) => {
  const currentSet = sets[currentSetIndex];

  if (!currentSet) {
    return [];
  }

  const indexes: number[] = [];

  for (let index = currentSetIndex + 1; index < sets.length; index += 1) {
    if (!haveSamePlannedTarget(currentSet, sets[index])) {
      break;
    }

    indexes.push(index);
  }

  return indexes;
};

export const isWeightStep = (value: unknown): value is WeightStep =>
  value === 0.5 ||
  value === 1 ||
  value === 1.25 ||
  value === 2.5 ||
  value === 5;

const barbellWeightKg = 20;
const multipowerBarWeightKg = 18;
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

const buildSymmetricLoadedBarLoads = (barWeightKg: number) =>
  Array.from(
    new Set(
      buildSidePlateLoads().map(
        (sideLoad) => Math.round((barWeightKg + sideLoad * 2) * 2) / 2,
      ),
    ),
  ).sort((a, b) => a - b);

const barbellLoadsKg = buildSymmetricLoadedBarLoads(barbellWeightKg);
const multipowerLoadsKg = buildSymmetricLoadedBarLoads(multipowerBarWeightKg);
const externalLoadsKg = buildPlateCombinationLoads();

export const getBarbellPlateLayout = (
  totalWeightKg: number,
  equipment?: ExportExercise['equipment'],
): BarbellPlateLayout | undefined => {
  const barWeightKg =
    equipment === 'multipower'
      ? multipowerBarWeightKg
      : equipment === 'barbell'
        ? barbellWeightKg
        : undefined;

  if (barWeightKg === undefined || totalWeightKg < barWeightKg) {
    return undefined;
  }

  let remainingSideWeight = roundEquipmentLoad(
    (totalWeightKg - barWeightKg) / 2,
  );
  const sidePlatesKg: number[] = [];

  [...plateInventoryKg]
    .sort((a, b) => b.weight - a.weight)
    .forEach((plate) => {
      const availablePerSide = Math.floor(plate.count / 2);

      for (
        let index = 0;
        index < availablePerSide && remainingSideWeight >= plate.weight;
        index += 1
      ) {
        sidePlatesKg.push(plate.weight);
        remainingSideWeight = roundEquipmentLoad(
          remainingSideWeight - plate.weight,
        );
      }
    });

  if (remainingSideWeight !== 0) {
    return undefined;
  }

  return { barWeightKg, sidePlatesKg };
};

export const getExerciseEquipment = (
  exercise: Pick<ExportExercise, 'equipment'>,
): ExerciseEquipment => (exercise.equipment ?? 'barbell') as ExerciseEquipment;

export const getWeightStepOptions = (
  loadType: LoadType,
  equipment?: ExportExercise['equipment'],
): WeightStep[] => {
  if (
    loadType === 'total' ||
    loadType === 'external' ||
    equipment === 'plate_loaded_machine'
  ) {
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

export const normalizeWeightStep = (
  value: WeightStep,
  loadType: LoadType,
  equipment?: ExportExercise['equipment'],
): WeightStep => {
  const options = getWeightStepOptions(loadType, equipment);
  return options.includes(value) ? value : options[0];
};

export const getAvailableLoadsForType = (
  loadType: LoadType,
  equipment?: ExportExercise['equipment'],
) => {
  if (loadType === 'per_dumbbell') {
    return dumbbellLoadsKg;
  }

  if (equipment === 'plate_loaded_machine') {
    return externalLoadsKg;
  }

  if (loadType === 'machine') {
    return cableLoadsKg;
  }

  if (loadType === 'total') {
    if (equipment === 'multipower') {
      return multipowerLoadsKg;
    }

    return barbellLoadsKg;
  }

  if (loadType === 'external') {
    return externalLoadsKg;
  }

  return [0];
};

const getWeightDelta = (loadType: LoadType, step: WeightStep) =>
  loadType === 'total' ? step * 2 : step;

export const getAdjustedWeight = (
  loadType: LoadType,
  equipment: ExportExercise['equipment'] | undefined,
  currentWeight: number,
  step: WeightStep,
  direction: -1 | 1,
) => {
  if (loadType === 'bodyweight') {
    return 0;
  }

  const normalizedStep = normalizeWeightStep(step, loadType, equipment);
  const target =
    currentWeight + getWeightDelta(loadType, normalizedStep) * direction;
  const loads = getAvailableLoadsForType(loadType, equipment);

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

const getNearestAvailableLoad = (
  loadType: LoadType,
  equipment: ExerciseEquipment,
  targetWeight: number,
) => {
  const loads = getAvailableLoadsForType(loadType, equipment);

  return loads.reduce(
    (nearest, load) =>
      Math.abs(load - targetWeight) < Math.abs(nearest - targetWeight)
        ? load
        : nearest,
    loads[0] ?? 0,
  );
};

export const getReferenceWeightKg = (
  weightKg: number,
  equipment?: ExerciseEquipment,
) =>
  (inferEquipmentLoadType(equipment) ?? 'bodyweight') === 'per_dumbbell'
    ? weightKg * 2
    : weightKg;

const getEquipmentWeightFromReference = (
  referenceWeightKg: number,
  equipment: ExerciseEquipment,
) => {
  const loadType = inferEquipmentLoadType(equipment) ?? 'bodyweight';

  if (loadType === 'bodyweight') {
    return 0;
  }

  const requestedWeight =
    loadType === 'per_dumbbell' ? referenceWeightKg / 2 : referenceWeightKg;

  return getNearestAvailableLoad(loadType, equipment, requestedWeight);
};

export const canUseEquipmentForReferenceWeight = (
  referenceWeightKg: number,
  equipment: ExerciseEquipment,
) => {
  const loadType = inferEquipmentLoadType(equipment) ?? 'bodyweight';

  if (loadType === 'bodyweight') {
    return referenceWeightKg === 0;
  }

  const requestedWeight =
    loadType === 'per_dumbbell' ? referenceWeightKg / 2 : referenceWeightKg;
  const availableLoads = getAvailableLoadsForType(loadType, equipment);
  const maximumWeight = availableLoads.at(-1) ?? 0;

  return requestedWeight <= maximumWeight;
};

export const convertWeightForEquipment = (
  currentWeight: number,
  currentEquipment: ExerciseEquipment,
  nextEquipment: ExerciseEquipment,
) => {
  return getEquipmentWeightFromReference(
    getReferenceWeightKg(currentWeight, currentEquipment),
    nextEquipment,
  );
};

export const getWeightForEquipmentReference = (
  referenceWeightKg: number,
  equipment: ExerciseEquipment,
) => getEquipmentWeightFromReference(referenceWeightKg, equipment);

export const getPreparedSetTargets = ({
  exercise,
  set,
  selectedEquipment,
}: {
  exercise: ExportExercise;
  set: ExportTrainingSet;
  selectedEquipment?: ExerciseEquipment;
}): PreparedSetTargets => {
  const plannedEquipment = getExerciseEquipment(exercise);
  const activeEquipment = selectedEquipment ?? plannedEquipment;
  const editedWeight =
    activeEquipment === plannedEquipment
      ? set.targetWeightKg
      : convertWeightForEquipment(
          set.targetWeightKg,
          plannedEquipment,
          activeEquipment,
        );

  return {
    editedReps: set.targetReps ?? 0,
    editedWeight,
    editedDurationSeconds: set.targetDurationSeconds ?? 0,
    setTimerRemaining: set.targetDurationSeconds ?? 0,
    isSetTimerRunning: false,
    setTimerEndsAt: undefined,
  };
};
