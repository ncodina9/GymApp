export type TrainingSet = {
  setIndex: number;
  targetReps: number;
  targetWeightKg: number;
  restSeconds: number;
  type: 'working';
};

export type Exercise = {
  exerciseId: string;
  name: string;
  notes: string;
  decisionOptions: string[];
  sets: TrainingSet[];
};

export type TrainingSession = {
  sessionId: string;
  date: string;
  week: number;
  weekday: string;
  label: string;
  estimatedMinutes: number;
  focus: string;
  exercises: Exercise[];
};

export const weekSessions: TrainingSession[] = [
  {
    sessionId: '2026-09-07-torso-fuerza',
    date: '2026-09-07',
    week: 1,
    weekday: 'lunes',
    label: 'Torso fuerza',
    estimatedMinutes: 58,
    focus: 'Press, dominadas y remo pesado',
    exercises: [
      {
        exerciseId: 'dumbbell-bench-press',
        name: 'Press banca mancuernas',
        notes:
          'Escapulas fijas. Repite el peso si la ultima serie pierde recorrido.',
        decisionOptions: ['Mantener', 'Subir 2.5 kg', 'Bajar 2.5 kg'],
        sets: [
          {
            setIndex: 1,
            targetReps: 8,
            targetWeightKg: 62.5,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 8,
            targetWeightKg: 62.5,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 8,
            targetWeightKg: 62.5,
            restSeconds: 150,
            type: 'working',
          },
        ],
      },
      {
        exerciseId: 'pull-ups',
        name: 'Dominadas',
        notes: 'Series limpias. Para en cuanto la barbilla no pase clara.',
        decisionOptions: ['Mantener reps', 'Anadir lastre', 'Reducir objetivo'],
        sets: [
          {
            setIndex: 1,
            targetReps: 8,
            targetWeightKg: 0,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 8,
            targetWeightKg: 0,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 7,
            targetWeightKg: 0,
            restSeconds: 150,
            type: 'working',
          },
        ],
      },
    ],
  },
  {
    sessionId: '2026-09-08-pierna-fuerza',
    date: '2026-09-08',
    week: 1,
    weekday: 'martes',
    label: 'Pierna fuerza',
    estimatedMinutes: 60,
    focus: 'Sentadilla e hip thrust',
    exercises: [
      {
        exerciseId: 'barbell-squat',
        name: 'Sentadilla con barra',
        notes:
          'Prioriza profundidad estable. Descanso completo en la tercera serie.',
        decisionOptions: ['Mantener', 'Subir 2.5 kg', 'Marcar molestia'],
        sets: [
          {
            setIndex: 1,
            targetReps: 6,
            targetWeightKg: 67.5,
            restSeconds: 150,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 6,
            targetWeightKg: 67.5,
            restSeconds: 150,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 6,
            targetWeightKg: 67.5,
            restSeconds: 180,
            type: 'working',
          },
        ],
      },
      {
        exerciseId: 'barbell-hip-thrust',
        name: 'Hip thrust con barra',
        notes:
          'Pausa breve arriba. No sacrifiques bloqueo de cadera por carga.',
        decisionOptions: ['Mantener', 'Subir 5 kg', 'Bajar volumen'],
        sets: [
          {
            setIndex: 1,
            targetReps: 10,
            targetWeightKg: 85,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 10,
            targetWeightKg: 85,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 10,
            targetWeightKg: 85,
            restSeconds: 150,
            type: 'working',
          },
        ],
      },
    ],
  },
  {
    sessionId: '2026-09-10-torso-volumen',
    date: '2026-09-10',
    week: 1,
    weekday: 'jueves',
    label: 'Torso volumen',
    estimatedMinutes: 55,
    focus: 'Remo, hombro y brazos',
    exercises: [
      {
        exerciseId: 'barbell-row',
        name: 'Remo inclinado barra',
        notes: 'Torso firme. Mantener mismo angulo en todas las reps.',
        decisionOptions: ['Mantener', 'Subir 2.5 kg', 'Bajar tempo'],
        sets: [
          {
            setIndex: 1,
            targetReps: 10,
            targetWeightKg: 52.5,
            restSeconds: 90,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 10,
            targetWeightKg: 52.5,
            restSeconds: 90,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 10,
            targetWeightKg: 52.5,
            restSeconds: 120,
            type: 'working',
          },
        ],
      },
      {
        exerciseId: 'standing-overhead-press',
        name: 'Press frontal de pie',
        notes: 'Bloquea abdomen antes de despegar la barra.',
        decisionOptions: ['Mantener', 'Subir 1 kg', 'Bajar 2 kg'],
        sets: [
          {
            setIndex: 1,
            targetReps: 9,
            targetWeightKg: 36,
            restSeconds: 90,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 9,
            targetWeightKg: 36,
            restSeconds: 90,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 9,
            targetWeightKg: 36,
            restSeconds: 120,
            type: 'working',
          },
        ],
      },
    ],
  },
  {
    sessionId: '2026-09-11-pierna-volumen',
    date: '2026-09-11',
    week: 1,
    weekday: 'viernes',
    label: 'Pierna volumen',
    estimatedMinutes: 57,
    focus: 'Bisagra, unilateral y accesorios',
    exercises: [
      {
        exerciseId: 'romanian-deadlift',
        name: 'Peso muerto rumano',
        notes:
          'Cadera atras y barra pegada. No conviertas la serie en peso muerto convencional.',
        decisionOptions: ['Mantener', 'Subir 2.5 kg', 'Bajar rango'],
        sets: [
          {
            setIndex: 1,
            targetReps: 10,
            targetWeightKg: 67.5,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 10,
            targetWeightKg: 67.5,
            restSeconds: 120,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 10,
            targetWeightKg: 67.5,
            restSeconds: 150,
            type: 'working',
          },
        ],
      },
      {
        exerciseId: 'hammer-curl',
        name: 'Curl martillo',
        notes: 'Codos quietos. Si balanceas, baja medio escalon.',
        decisionOptions: ['Mantener', 'Subir 1 kg', 'Bajar reps'],
        sets: [
          {
            setIndex: 1,
            targetReps: 12,
            targetWeightKg: 16,
            restSeconds: 75,
            type: 'working',
          },
          {
            setIndex: 2,
            targetReps: 12,
            targetWeightKg: 16,
            restSeconds: 75,
            type: 'working',
          },
          {
            setIndex: 3,
            targetReps: 12,
            targetWeightKg: 16,
            restSeconds: 90,
            type: 'working',
          },
        ],
      },
    ],
  },
];
