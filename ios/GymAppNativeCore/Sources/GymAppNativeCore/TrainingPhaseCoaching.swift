import Foundation

/// Preserves a single effort prescription for execution feedback and coaching
/// copy, even when older plan notes contain a stale RIR reference.
public struct TrainingPhaseEffort: Equatable, Sendable {
  public let defaultRIR: Int
  public let rangeLabel: String
  public let cue: String

  public init(defaultRIR: Int, rangeLabel: String, cue: String) {
    self.defaultRIR = defaultRIR
    self.rangeLabel = rangeLabel
    self.cue = cue
  }
}

public enum TrainingPhaseCoaching {
  public static func effort(for phase: String) -> TrainingPhaseEffort {
    switch normalized(phase) {
    case "descarga", "readaptacion":
      .init(
        defaultRIR: 3,
        rangeLabel: "3-4",
        cue: "Semana de descarga: deja 3-4 RIR y prioriza una ejecución fácil, sin apurar series."
      )
    case "intensificacion":
      .init(
        defaultRIR: 1,
        rangeLabel: "1-2",
        cue: "Semana de intensificación: trabaja con intención, dejando 1-2 RIR solo si la técnica se mantiene estable."
      )
    case "realizacion", "test":
      .init(
        defaultRIR: 1,
        rangeLabel: "según prescripción",
        cue: "Semana de realización: respeta la prescripción y no fuerces repeticiones extra para perseguir un RIR concreto."
      )
    case "acumulacion":
      .init(
        defaultRIR: 2,
        rangeLabel: "2-3",
        cue: "Semana de acumulación: acumula trabajo limpio dejando 2-3 RIR para sostener el volumen."
      )
    default:
      .init(
        defaultRIR: 2,
        rangeLabel: "2",
        cue: "Mantén un margen técnico de 2 RIR y detén la serie si la ejecución se degrada."
      )
    }
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
  }
}
