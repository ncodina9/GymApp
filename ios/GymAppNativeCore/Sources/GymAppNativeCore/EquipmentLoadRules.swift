import Foundation

public enum EquipmentLoadType: Sendable {
  case total
  case perDumbbell
  case machine
  case external
  case bodyweight
}

public struct BarbellPlateLayout: Equatable, Sendable {
  public let barWeightKg: Double
  public let sidePlatesKg: [Double]
}

public struct PlateLoad: Codable, Equatable, Sendable {
  public let weightKg: Double
  public let count: Int

  public init(weightKg: Double, count: Int) {
    self.weightKg = weightKg
    self.count = count
  }
}

public struct EquipmentLoadInventory: Codable, Equatable, Sendable {
  public let dumbbellLoadsKg: [Double]
  public let plates: [PlateLoad]
  public let cableStepKg: Double
  public let cableMaximumKg: Double
  public let barbellWeightKg: Double
  public let multipowerBarWeightKg: Double

  public init(dumbbellLoadsKg: [Double], plates: [PlateLoad], cableStepKg: Double, cableMaximumKg: Double = 100, barbellWeightKg: Double, multipowerBarWeightKg: Double) {
    self.dumbbellLoadsKg = dumbbellLoadsKg.sorted()
    self.plates = plates.sorted { $0.weightKg < $1.weightKg }
    self.cableStepKg = cableStepKg
    self.cableMaximumKg = cableMaximumKg
    self.barbellWeightKg = barbellWeightKg
    self.multipowerBarWeightKg = multipowerBarWeightKg
  }

  public static let standard = EquipmentLoadInventory(
    dumbbellLoadsKg: [5, 6, 7.5, 8, 9, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30],
    plates: [.init(weightKg: 1.25, count: 4), .init(weightKg: 2.5, count: 4), .init(weightKg: 5, count: 12), .init(weightKg: 10, count: 12), .init(weightKg: 15, count: 2), .init(weightKg: 20, count: 4)],
    cableStepKg: 5,
    barbellWeightKg: 20,
    multipowerBarWeightKg: 18
  )
}

public enum EquipmentLoadRules {
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
    equipment: Equipment,
    inventory: EquipmentLoadInventory = .standard
  ) -> Double {
    guard referenceWeightKg > 0 else { return 0 }

    let requestedWeight = loadType(for: equipment) == .perDumbbell
      ? referenceWeightKg / 2
      : referenceWeightKg

    return nearestAvailableLoad(to: requestedWeight, equipment: equipment, inventory: inventory)
  }

  public static func canUse(
    equipment: Equipment,
    referenceWeightKg: Double,
    inventory: EquipmentLoadInventory = .standard
  ) -> Bool {
    if loadType(for: equipment) == .bodyweight {
      return referenceWeightKg == 0
    }

    guard referenceWeightKg >= 0 else { return false }
    let requestedWeight = loadType(for: equipment) == .perDumbbell
      ? referenceWeightKg / 2
      : referenceWeightKg
    return requestedWeight <= (availableLoads(for: equipment, inventory: inventory).last ?? 0)
  }

  public static func availableLoads(for equipment: Equipment, inventory: EquipmentLoadInventory = .standard) -> [Double] {
    switch equipment {
    case .barbell:
      symmetricLoadedBarLoads(barWeightKg: inventory.barbellWeightKg, inventory: inventory)
    case .multipower:
      symmetricLoadedBarLoads(barWeightKg: inventory.multipowerBarWeightKg, inventory: inventory)
    case .dumbbell:
      inventory.dumbbellLoadsKg
    case .cable:
      stride(from: inventory.cableStepKg, through: inventory.cableMaximumKg, by: inventory.cableStepKg).map { $0 }
    case .plateLoadedMachine, .external:
      plateCombinationLoads(inventory: inventory)
    case .bodyweight:
      [0]
    }
  }

  public static func adjustedWeight(
    from currentWeightKg: Double,
    equipment: Equipment,
    direction: Int,
    inventory: EquipmentLoadInventory = .standard
  ) -> Double {
    guard direction != 0 else { return currentWeightKg }
    let loads = availableLoads(for: equipment, inventory: inventory)
    guard !loads.isEmpty else { return currentWeightKg }
    let currentIndex = loads.indices.min {
      abs(loads[$0] - currentWeightKg) < abs(loads[$1] - currentWeightKg)
    } ?? 0
    let nextIndex = min(max(0, currentIndex + (direction > 0 ? 1 : -1)), loads.count - 1)
    return loads[nextIndex]
  }

  public static func plateLayout(
    totalWeightKg: Double,
    equipment: Equipment,
    inventory: EquipmentLoadInventory = .standard
  ) -> BarbellPlateLayout? {
    let barWeightKg: Double
    switch equipment {
    case .barbell: barWeightKg = inventory.barbellWeightKg
    case .multipower: barWeightKg = inventory.multipowerBarWeightKg
    default: return nil
    }

    guard totalWeightKg >= barWeightKg else { return nil }
    var remainingSideWeight = roundToHundredth((totalWeightKg - barWeightKg) / 2)
    var sidePlates: [Double] = []

    for plate in inventory.plates.sorted(by: { $0.weightKg > $1.weightKg }) {
      for _ in 0 ..< (plate.count / 2) where remainingSideWeight >= plate.weightKg {
        sidePlates.append(plate.weightKg)
        remainingSideWeight = roundToHundredth(remainingSideWeight - plate.weightKg)
      }
    }

    guard remainingSideWeight == 0 else { return nil }
    return BarbellPlateLayout(barWeightKg: barWeightKg, sidePlatesKg: sidePlates)
  }

  private static func nearestAvailableLoad(to target: Double, equipment: Equipment, inventory: EquipmentLoadInventory) -> Double {
    let loads = availableLoads(for: equipment, inventory: inventory)
    return loads.min { lhs, rhs in
      abs(lhs - target) < abs(rhs - target)
    } ?? 0
  }

  private static func symmetricLoadedBarLoads(barWeightKg: Double, inventory: EquipmentLoadInventory) -> [Double] {
    Array(
      Set(
        sidePlateLoads(inventory: inventory).map { sideLoad in
          roundToHundredth(barWeightKg + sideLoad * 2)
        }
      )
    )
    .sorted()
  }

  private static func sidePlateLoads(inventory: EquipmentLoadInventory) -> [Double] {
    var loads: Set<Double> = [0]

    for plate in inventory.plates {
      let existing = loads
      let perSideCount = plate.count / 2

      for load in existing {
        for count in 1 ... perSideCount {
          loads.insert(roundToHundredth(load + plate.weightKg * Double(count)))
        }
      }
    }

    return Array(loads)
  }

  private static func plateCombinationLoads(inventory: EquipmentLoadInventory) -> [Double] {
    var loads: Set<Double> = [0]

    for plate in inventory.plates {
      let existing = loads

      for load in existing {
        for count in 1 ... plate.count {
          loads.insert(roundToHundredth(load + plate.weightKg * Double(count)))
        }
      }
    }

    return loads.filter { $0 > 0 }.sorted()
  }

  private static func roundToHundredth(_ value: Double) -> Double {
    (value * 100).rounded() / 100
  }
}
