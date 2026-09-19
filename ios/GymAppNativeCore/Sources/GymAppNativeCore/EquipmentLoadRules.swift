import Foundation

public enum EquipmentLoadType: Sendable {
  case total
  case perDumbbell
  case machine
  case external
  case bodyweight
}

public enum EquipmentLoadRules {
  private static let dumbbellLoadsKg: [Double] = [
    5, 6, 7.5, 8, 9, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30,
  ]
  private static let plateInventory: [(weight: Double, count: Int)] = [
    (1.25, 4), (2.5, 4), (5, 12), (10, 12), (15, 2), (20, 4),
  ]
  private static let cableLoadsKg = (1 ... 20).map { Double($0 * 5) }
  private static let barbellWeightKg = 20.0
  private static let multipowerBarWeightKg = 18.0

  public static func loadType(for equipment: Equipment) -> EquipmentLoadType {
    switch equipment {
    case .barbell, .multipower:
      .total
    case .dumbbell:
      .perDumbbell
    case .cable:
      .machine
    case .plateLoadedMachine, .external:
      .external
    case .bodyweight:
      .bodyweight
    }
  }

  public static func referenceWeightKg(_ weightKg: Double, equipment: Equipment) -> Double {
    loadType(for: equipment) == .perDumbbell ? weightKg * 2 : weightKg
  }

  public static func weightForReferenceWeight(
    _ referenceWeightKg: Double,
    equipment: Equipment
  ) -> Double {
    guard referenceWeightKg > 0 else { return 0 }

    let requestedWeight = loadType(for: equipment) == .perDumbbell
      ? referenceWeightKg / 2
      : referenceWeightKg

    return nearestAvailableLoad(to: requestedWeight, equipment: equipment)
  }

  public static func canUse(
    equipment: Equipment,
    referenceWeightKg: Double
  ) -> Bool {
    if loadType(for: equipment) == .bodyweight {
      return referenceWeightKg == 0
    }

    guard referenceWeightKg >= 0 else { return false }
    let requestedWeight = loadType(for: equipment) == .perDumbbell
      ? referenceWeightKg / 2
      : referenceWeightKg
    return requestedWeight <= (availableLoads(for: equipment).last ?? 0)
  }

  public static func availableLoads(for equipment: Equipment) -> [Double] {
    switch equipment {
    case .barbell:
      symmetricLoadedBarLoads(barWeightKg: barbellWeightKg)
    case .multipower:
      symmetricLoadedBarLoads(barWeightKg: multipowerBarWeightKg)
    case .dumbbell:
      dumbbellLoadsKg
    case .cable:
      cableLoadsKg
    case .plateLoadedMachine, .external:
      plateCombinationLoads()
    case .bodyweight:
      [0]
    }
  }

  private static func nearestAvailableLoad(to target: Double, equipment: Equipment) -> Double {
    let loads = availableLoads(for: equipment)
    return loads.min { lhs, rhs in
      abs(lhs - target) < abs(rhs - target)
    } ?? 0
  }

  private static func symmetricLoadedBarLoads(barWeightKg: Double) -> [Double] {
    Array(
      Set(
        sidePlateLoads().map { sideLoad in
          roundToHundredth(barWeightKg + sideLoad * 2)
        }
      )
    )
    .sorted()
  }

  private static func sidePlateLoads() -> [Double] {
    var loads: Set<Double> = [0]

    for plate in plateInventory {
      let existing = loads
      let perSideCount = plate.count / 2

      for load in existing {
        for count in 1 ... perSideCount {
          loads.insert(roundToHundredth(load + plate.weight * Double(count)))
        }
      }
    }

    return Array(loads)
  }

  private static func plateCombinationLoads() -> [Double] {
    var loads: Set<Double> = [0]

    for plate in plateInventory {
      let existing = loads

      for load in existing {
        for count in 1 ... plate.count {
          loads.insert(roundToHundredth(load + plate.weight * Double(count)))
        }
      }
    }

    return loads.filter { $0 > 0 }.sorted()
  }

  private static func roundToHundredth(_ value: Double) -> Double {
    (value * 100).rounded() / 100
  }
}
