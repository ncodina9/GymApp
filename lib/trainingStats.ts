import {
  formatExportTarget,
  inferLoadType,
  type ExportTrainingSession,
} from '@/lib/sessionExport';
import { estimateSessionDurationFromSteps } from '@/lib/sessionDuration';
import { getWeekSessions } from '@/lib/sessionSelection';
import { buildExecutionSteps } from '@/lib/workoutSequence';
import type {
  StoredSessionMetadata,
  StoredSetEvent,
} from '@/lib/workoutStorage';

export type SessionHistorySummary = {
  sessionId: string;
  sessionDate: string;
  weekNumber: number;
  sessionLabel: string;
  estimatedMinutes: number;
  derivedEstimatedMinutes: number;
  attemptedSets: number;
  completedSets: number;
  totalSets: number;
  schemaVersion?: number;
  startedAt?: string;
  finishedAt?: string;
  exportedAt?: string;
  firstPerformedAt: string;
  lastPerformedAt: string;
};

export type ExerciseProgressInsight = {
  exerciseId: string;
  exerciseName: string;
  lastDate: string;
  nextDate?: string;
  nextSessionLabel?: string;
  target: string;
  lastLoadKg?: number;
  lastReps?: number;
  lastDurationSeconds?: number;
  lastRir?: number;
  lastDecision?: string;
  completedSets: number;
  attemptedSets: number;
  plannedSets: number;
  skippedSets: number;
  painHits: number;
  recommendation: string;
  tone: 'neutral' | 'up' | 'down' | 'warning';
};

export type ExerciseProgressionExposure = {
  sessionId: string;
  sessionDate: string;
  sessionLabel: string;
  target: string;
  attemptedSets: number;
  completedSets: number;
  plannedSets: number;
  skippedSets: number;
  topLoadKg?: number;
  totalReps: number;
  totalDurationSeconds: number;
  averageRir?: number;
  painHits: number;
  decision?: string;
  lastPerformedAt: string;
};

export type ExerciseProgressionSummary = {
  exerciseId: string;
  exerciseName: string;
  target: string;
  recommendation: string;
  tone: ExerciseProgressInsight['tone'];
  nextDate?: string;
  nextSessionLabel?: string;
  exposures: ExerciseProgressionExposure[];
};

export type TrainingStatsSummary = {
  weekNumber: number;
  weekFocusLabel: string;
  weekCompletedSessions: number;
  weekTotalSessions: number;
  completedSessions: number;
  storedSessions: number;
  averageDurationMinutes?: number;
  averageDeltaMinutes?: number;
  latestSessions: SessionHistorySummary[];
  durationSamples: {
    sessionId: string;
    label: string;
    actualMinutes: number;
    estimatedMinutes: number;
    deltaMinutes: number;
  }[];
  warningInsights: ExerciseProgressInsight[];
  upInsights: ExerciseProgressInsight[];
  downInsights: ExerciseProgressInsight[];
  skippedSets: number;
  painHits: number;
};

const getPainHits = (events: StoredSetEvent[]) =>
  events.filter(
    (event) =>
      event.painKnee > 0 ||
      event.painWrist > 0 ||
      (event.painShoulder ?? 0) > 0 ||
      (event.painLowerBack ?? 0) > 0 ||
      event.painOther > 0,
  ).length;

export const getDurationMinutes = (startedAt?: string, finishedAt?: string) => {
  if (!startedAt || !finishedAt) {
    return undefined;
  }

  const startedTime = new Date(startedAt).getTime();
  const finishedTime = new Date(finishedAt).getTime();

  if (!Number.isFinite(startedTime) || !Number.isFinite(finishedTime)) {
    return undefined;
  }

  const elapsedMs = finishedTime - startedTime;

  if (elapsedMs < 0) {
    return undefined;
  }

  return Math.max(1, Math.round(elapsedMs / 60000));
};

export const isSessionHistoryComplete = (summary: SessionHistorySummary) =>
  Boolean(summary.finishedAt) || summary.attemptedSets >= summary.totalSets;

export const getSessionHistorySummaries = (
  sessions: ExportTrainingSession[],
  events: StoredSetEvent[],
  metadata: StoredSessionMetadata[],
): SessionHistorySummary[] => {
  const eventsBySession = new Map<string, StoredSetEvent[]>();
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );

  events.forEach((event) => {
    const sessionEvents = eventsBySession.get(event.sessionId) ?? [];
    sessionEvents.push(event);
    eventsBySession.set(event.sessionId, sessionEvents);
  });

  return sessions
    .flatMap((session) => {
      const sessionEvents = eventsBySession.get(session.sessionId) ?? [];

      if (sessionEvents.length === 0) {
        return [];
      }

      const sortedEvents = [...sessionEvents].sort((a, b) =>
        a.performedAt.localeCompare(b.performedAt),
      );
      const sessionMetadata = metadataBySession.get(session.sessionId);

      return [
        {
          sessionId: session.sessionId,
          sessionDate: session.date,
          weekNumber: session.week,
          sessionLabel: session.label,
          estimatedMinutes: session.estimatedMinutes,
          derivedEstimatedMinutes: estimateSessionDurationFromSteps(
            session,
            buildExecutionSteps(session),
          ).totalMinutes,
          attemptedSets: sortedEvents.length,
          completedSets: sortedEvents.filter(
            (event) => event.status === 'completed',
          ).length,
          totalSets: buildExecutionSteps(session).length,
          ...(sessionMetadata?.schemaVersion
            ? { schemaVersion: sessionMetadata.schemaVersion }
            : {}),
          ...(sessionMetadata?.startedAt
            ? { startedAt: sessionMetadata.startedAt }
            : {}),
          ...(sessionMetadata?.finishedAt
            ? { finishedAt: sessionMetadata.finishedAt }
            : {}),
          ...(sessionMetadata?.exportedAt
            ? { exportedAt: sessionMetadata.exportedAt }
            : {}),
          firstPerformedAt: sortedEvents[0].performedAt,
          lastPerformedAt: sortedEvents[sortedEvents.length - 1].performedAt,
        },
      ];
    })
    .sort((a, b) => b.lastPerformedAt.localeCompare(a.lastPerformedAt));
};

export const getExerciseProgressInsights = (
  sessions: ExportTrainingSession[],
  events: StoredSetEvent[],
  metadata: StoredSessionMetadata[],
  todayIso: string,
): ExerciseProgressInsight[] => {
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );
  const eventsByExercise = new Map<string, StoredSetEvent[]>();

  events.forEach((event) => {
    const exerciseEvents = eventsByExercise.get(event.exerciseId) ?? [];
    exerciseEvents.push(event);
    eventsByExercise.set(event.exerciseId, exerciseEvents);
  });

  return Array.from(eventsByExercise.entries())
    .map(([exerciseId, exerciseEvents]) => {
      const sortedEvents = [...exerciseEvents].sort((a, b) =>
        a.performedAt.localeCompare(b.performedAt),
      );
      const lastEvent = sortedEvents[sortedEvents.length - 1];
      const lastSession =
        sessions.find((session) => session.sessionId === lastEvent.sessionId) ??
        sessions.find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const lastExercise = lastSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const nextSession = sessions
        .filter((session) => session.date >= todayIso)
        .find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const nextExercise = nextSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const completedEvents = sortedEvents.filter(
        (event) => event.status === 'completed',
      );
      const skippedSets = sortedEvents.filter(
        (event) => event.status === 'skipped',
      ).length;
      const recentEvents = sortedEvents.slice(-12);
      const painHits = getPainHits(recentEvents);
      const sessionEvents = sortedEvents.filter(
        (event) => event.sessionId === lastEvent.sessionId,
      );
      const completedSets = sessionEvents.filter(
        (event) => event.status === 'completed',
      ).length;
      const attemptedSets = sessionEvents.length;
      const plannedSets = lastExercise?.sets.length ?? attemptedSets;
      const lastCompletedEvent = completedEvents.at(-1);
      const lastDecision = metadataBySession.get(lastEvent.sessionId)
        ?.decisions?.[exerciseId];
      const decisionText = lastDecision?.toLowerCase() ?? '';
      const completedRirEvents = completedEvents.filter(
        (event) => event.actualDurationSeconds === undefined,
      );
      const avgRecentRir =
        completedRirEvents.length > 0
          ? completedRirEvents
              .slice(-Math.min(3, completedRirEvents.length))
              .reduce((total, event) => total + event.rirLast, 0) /
            Math.min(3, completedRirEvents.length)
          : 0;

      let tone: ExerciseProgressInsight['tone'] = 'neutral';
      let recommendation = 'Mantener y observar';

      if (painHits >= 2 || decisionText.includes('molestia')) {
        tone = 'warning';
        recommendation = 'Revisar técnica o carga';
      } else if (decisionText.includes('bajar')) {
        tone = 'down';
        recommendation = lastDecision ?? 'Bajar carga';
      } else if (decisionText.includes('subir')) {
        tone = 'up';
        recommendation = lastDecision ?? 'Subir carga';
      } else if (skippedSets >= 2 || completedSets < plannedSets) {
        tone = 'warning';
        recommendation = 'Mantener hasta completar series';
      } else if (avgRecentRir >= 2.5 && completedSets >= plannedSets) {
        tone = 'up';
        recommendation = 'Candidato a subir';
      }

      return {
        exerciseId,
        exerciseName: nextExercise?.name ?? lastExercise?.name ?? exerciseId,
        lastDate: lastEvent.sessionDate,
        ...(nextSession
          ? {
              nextDate: nextSession.date,
              nextSessionLabel: nextSession.label,
            }
          : {}),
        target: formatExportTarget(
          nextExercise?.target ?? lastExercise?.target ?? '',
          inferLoadType(nextExercise ?? lastExercise),
        ),
        ...(lastCompletedEvent
          ? {
              lastLoadKg: lastCompletedEvent.actualWeightKg,
              ...(lastCompletedEvent.actualDurationSeconds !== undefined
                ? {
                    lastDurationSeconds:
                      lastCompletedEvent.actualDurationSeconds,
                  }
                : {
                    lastReps: lastCompletedEvent.actualReps,
                    lastRir: lastCompletedEvent.rirLast,
                  }),
            }
          : {}),
        ...(lastDecision ? { lastDecision } : {}),
        completedSets,
        attemptedSets,
        plannedSets,
        skippedSets,
        painHits,
        recommendation,
        tone,
      };
    })
    .sort((a, b) => {
      const toneOrder = { warning: 0, up: 1, down: 2, neutral: 3 };
      return (
        toneOrder[a.tone] - toneOrder[b.tone] ||
        (a.nextDate ?? '9999-12-31').localeCompare(b.nextDate ?? '9999-12-31')
      );
    })
    .slice(0, 8);
};

export const getExerciseProgressionSummaries = (
  sessions: ExportTrainingSession[],
  events: StoredSetEvent[],
  metadata: StoredSessionMetadata[],
  insights: ExerciseProgressInsight[],
  todayIso: string,
): ExerciseProgressionSummary[] => {
  const metadataBySession = new Map(
    metadata.map((item) => [item.sessionId, item]),
  );
  const insightsByExercise = new Map(
    insights.map((insight) => [insight.exerciseId, insight]),
  );
  const eventsByExercise = new Map<string, StoredSetEvent[]>();

  events.forEach((event) => {
    const exerciseEvents = eventsByExercise.get(event.exerciseId) ?? [];
    exerciseEvents.push(event);
    eventsByExercise.set(event.exerciseId, exerciseEvents);
  });

  return Array.from(eventsByExercise.entries())
    .map(([exerciseId, exerciseEvents]) => {
      const sortedEvents = [...exerciseEvents].sort((a, b) =>
        a.performedAt.localeCompare(b.performedAt),
      );
      const lastEvent = sortedEvents[sortedEvents.length - 1];
      const lastSession =
        sessions.find((session) => session.sessionId === lastEvent.sessionId) ??
        sessions.find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const lastExercise = lastSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const nextSession = sessions
        .filter((session) => session.date >= todayIso)
        .find((session) =>
          session.exercises.some(
            (exercise) => exercise.exerciseId === exerciseId,
          ),
        );
      const nextExercise = nextSession?.exercises.find(
        (exercise) => exercise.exerciseId === exerciseId,
      );
      const exerciseName =
        nextExercise?.name ?? lastExercise?.name ?? exerciseId;
      const target = formatExportTarget(
        nextExercise?.target ?? lastExercise?.target ?? '',
        inferLoadType(nextExercise ?? lastExercise),
      );
      const eventsBySession = new Map<string, StoredSetEvent[]>();

      sortedEvents.forEach((event) => {
        const sessionEvents = eventsBySession.get(event.sessionId) ?? [];
        sessionEvents.push(event);
        eventsBySession.set(event.sessionId, sessionEvents);
      });

      const exposures = Array.from(eventsBySession.entries())
        .flatMap(([sessionId, sessionEvents]) => {
          const session = sessions.find((item) => item.sessionId === sessionId);
          const exercise = session?.exercises.find(
            (item) => item.exerciseId === exerciseId,
          );

          if (!session) {
            return [];
          }

          const sessionSortedEvents = [...sessionEvents].sort((a, b) =>
            a.performedAt.localeCompare(b.performedAt),
          );
          const completedEvents = sessionSortedEvents.filter(
            (event) => event.status === 'completed',
          );
          const completedLoads = completedEvents
            .map((event) => event.actualWeightKg)
            .filter((weight) => weight > 0);
          const completedRirEvents = completedEvents.filter(
            (event) => event.actualDurationSeconds === undefined,
          );
          const averageRir =
            completedRirEvents.length > 0
              ? Math.round(
                  (completedRirEvents.reduce(
                    (total, event) => total + event.rirLast,
                    0,
                  ) /
                    completedRirEvents.length) *
                    10,
                ) / 10
              : undefined;

          return [
            {
              sessionId,
              sessionDate: session.date,
              sessionLabel: session.label,
              target: formatExportTarget(
                exercise?.target ?? '',
                inferLoadType(exercise),
              ),
              attemptedSets: sessionSortedEvents.length,
              completedSets: completedEvents.length,
              plannedSets: exercise?.sets.length ?? sessionSortedEvents.length,
              skippedSets: sessionSortedEvents.filter(
                (event) => event.status === 'skipped',
              ).length,
              ...(completedLoads.length > 0
                ? { topLoadKg: Math.max(...completedLoads) }
                : {}),
              totalReps: completedEvents.reduce(
                (total, event) => total + event.actualReps,
                0,
              ),
              totalDurationSeconds: completedEvents.reduce(
                (total, event) => total + (event.actualDurationSeconds ?? 0),
                0,
              ),
              ...(averageRir !== undefined ? { averageRir } : {}),
              painHits: getPainHits(sessionSortedEvents),
              ...(metadataBySession.get(sessionId)?.decisions?.[exerciseId]
                ? {
                    decision:
                      metadataBySession.get(sessionId)?.decisions?.[exerciseId],
                  }
                : {}),
              lastPerformedAt:
                sessionSortedEvents[sessionSortedEvents.length - 1].performedAt,
            },
          ];
        })
        .sort((a, b) => b.lastPerformedAt.localeCompare(a.lastPerformedAt))
        .slice(0, 8);
      const insight = insightsByExercise.get(exerciseId);

      return {
        exerciseId,
        exerciseName,
        target,
        recommendation: insight?.recommendation ?? 'Mantener y observar',
        tone: insight?.tone ?? 'neutral',
        ...(nextSession
          ? {
              nextDate: nextSession.date,
              nextSessionLabel: nextSession.label,
            }
          : {}),
        exposures,
      };
    })
    .sort((a, b) => {
      const toneOrder = { warning: 0, up: 1, down: 2, neutral: 3 };
      return (
        toneOrder[a.tone] - toneOrder[b.tone] ||
        a.exerciseName.localeCompare(b.exerciseName)
      );
    });
};

export const getTrainingStatsSummary = ({
  sessions,
  recommendedSession,
  history,
  insights,
}: {
  sessions: ExportTrainingSession[];
  recommendedSession: ExportTrainingSession;
  history: SessionHistorySummary[];
  insights: ExerciseProgressInsight[];
}): TrainingStatsSummary => {
  const currentWeekSessions = getWeekSessions(sessions, recommendedSession);
  const completedSessionIds = new Set(
    history
      .filter((summary) => isSessionHistoryComplete(summary))
      .map((summary) => summary.sessionId),
  );
  const durationSamples = history
    .flatMap((summary) => {
      const actualMinutes = getDurationMinutes(
        summary.startedAt,
        summary.finishedAt,
      );

      if (!actualMinutes) {
        return [];
      }

      return [
        {
          sessionId: summary.sessionId,
          label: summary.sessionLabel,
          actualMinutes,
          estimatedMinutes: summary.derivedEstimatedMinutes,
          deltaMinutes: actualMinutes - summary.derivedEstimatedMinutes,
        },
      ];
    })
    .slice(0, 5);
  const averageDurationMinutes =
    durationSamples.length > 0
      ? Math.round(
          durationSamples.reduce(
            (total, sample) => total + sample.actualMinutes,
            0,
          ) / durationSamples.length,
        )
      : undefined;
  const averageDeltaMinutes =
    durationSamples.length > 0
      ? Math.round(
          durationSamples.reduce(
            (total, sample) => total + sample.deltaMinutes,
            0,
          ) / durationSamples.length,
        )
      : undefined;

  return {
    weekNumber: recommendedSession.week,
    weekFocusLabel: recommendedSession.weekFocusLabel,
    weekCompletedSessions: currentWeekSessions.filter((session) =>
      completedSessionIds.has(session.sessionId),
    ).length,
    weekTotalSessions: currentWeekSessions.length,
    completedSessions: history.filter((summary) =>
      isSessionHistoryComplete(summary),
    ).length,
    storedSessions: history.length,
    ...(averageDurationMinutes ? { averageDurationMinutes } : {}),
    ...(averageDeltaMinutes !== undefined ? { averageDeltaMinutes } : {}),
    latestSessions: history.slice(0, 3),
    durationSamples,
    warningInsights: insights.filter((insight) => insight.tone === 'warning'),
    upInsights: insights.filter((insight) => insight.tone === 'up'),
    downInsights: insights.filter((insight) => insight.tone === 'down'),
    skippedSets: insights.reduce(
      (total, insight) => total + insight.skippedSets,
      0,
    ),
    painHits: insights.reduce((total, insight) => total + insight.painHits, 0),
  };
};
