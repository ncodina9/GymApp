export type SelectableSession = {
  sessionId: string;
  date: string;
  week: number;
};

export type SelectableTrainingPlan = {
  sessions: SelectableSession[];
};

const padDatePart = (value: number) => String(value).padStart(2, '0');

export const toIsoDate = (date: Date) =>
  [
    date.getFullYear(),
    padDatePart(date.getMonth() + 1),
    padDatePart(date.getDate()),
  ].join('-');

export const getRecommendedSession = <Session extends SelectableSession>(
  sessions: Session[],
  todayIso = toIsoDate(new Date()),
) => {
  if (sessions.length === 0) {
    return undefined;
  }

  return (
    sessions.find((session) => session.date === todayIso) ??
    sessions.find((session) => session.date >= todayIso) ??
    sessions[0]
  );
};

export const findSessionById = <Session extends SelectableSession>(
  sessions: Session[],
  sessionId: string | undefined,
) => sessions.find((session) => session.sessionId === sessionId);

export const resolveSelectedSession = <Session extends SelectableSession>(
  sessions: Session[],
  sessionId: string | undefined,
  todayIso = toIsoDate(new Date()),
) =>
  findSessionById(sessions, sessionId) ??
  getRecommendedSession(sessions, todayIso) ??
  sessions[0];

export const getWeekSessions = <Session extends SelectableSession>(
  sessions: Session[],
  selectedSession: Session,
) => sessions.filter((session) => session.week === selectedSession.week);
