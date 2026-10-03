import SwiftUI
import SwiftData
import GymAppNativeCore

struct ExerciseCatalogPreferences: Codable, Equatable {
  var disabledBaseExerciseIDs: Set<String> = []
  var disabledVariantExerciseIDs: Set<String> = []
  var disabledEquipmentByBaseExercise: [String: Set<Equipment>] = [:]

  func allows(_ exercise: TrainingExercise) -> Bool {
    !disabledBaseExerciseIDs.contains(exercise.baseExerciseID)
      && !disabledVariantExerciseIDs.contains(exercise.exerciseID)
  }

  func allows(_ equipment: Equipment, for baseExerciseID: String) -> Bool {
    !(disabledEquipmentByBaseExercise[baseExerciseID] ?? []).contains(equipment)
  }

  mutating func setExerciseEnabled(_ enabled: Bool, baseExerciseID: String) {
    if enabled {
      disabledBaseExerciseIDs.remove(baseExerciseID)
    } else {
      disabledBaseExerciseIDs.insert(baseExerciseID)
    }
  }

  mutating func setVariantEnabled(_ enabled: Bool, exerciseID: String) {
    if enabled {
      disabledVariantExerciseIDs.remove(exerciseID)
    } else {
      disabledVariantExerciseIDs.insert(exerciseID)
    }
  }

  mutating func setEquipmentEnabled(_ enabled: Bool, equipment: Equipment, baseExerciseID: String) {
    var disabled = disabledEquipmentByBaseExercise[baseExerciseID] ?? []
    if enabled {
      disabled.remove(equipment)
    } else {
      disabled.insert(equipment)
    }
    if disabled.isEmpty {
      disabledEquipmentByBaseExercise.removeValue(forKey: baseExerciseID)
    } else {
      disabledEquipmentByBaseExercise[baseExerciseID] = disabled
    }
  }
}

struct ExerciseCatalogEntry: Codable, Identifiable {
  struct Variant: Codable, Identifiable {
    let exerciseID: String
    let label: String

    var id: String { exerciseID }

    private enum CodingKeys: String, CodingKey {
      case exerciseID = "exerciseId"
      case label
    }
  }

  let baseExerciseID: String
  let name: String
  let movementPattern: String?
  let primaryMuscles: [String]
  let equipment: [Equipment]
  let variants: [Variant]
  let tier: String

  var id: String { baseExerciseID }

  private enum CodingKeys: String, CodingKey {
    case baseExerciseID = "baseExerciseId"
    case name, movementPattern, primaryMuscles, equipment, variants, tier
  }

  static func entries(from plan: TrainingPlan) -> [ExerciseCatalogEntry] {
    Dictionary(grouping: plan.sessions.flatMap(\.exercises), by: \.baseExerciseID)
      .values
      .compactMap { exercises in
        guard let sample = exercises.first else { return nil }
        let variants = Dictionary(grouping: exercises.compactMap { exercise -> Variant? in
          guard let label = variationLabel(for: exercise) else { return nil }
          return Variant(exerciseID: exercise.exerciseID, label: label)
        }, by: \.label)
        .values
        .compactMap { $0.first }
        .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        return ExerciseCatalogEntry(
          baseExerciseID: sample.baseExerciseID,
          name: sample.displayName,
          movementPattern: sample.movementPattern,
          primaryMuscles: Array(Set(exercises.flatMap(\.primaryMuscles))).sorted(),
          equipment: Array(Set(exercises.flatMap(\.selectableEquipmentOptions))).sorted { $0.executionLabel < $1.executionLabel },
          variants: variants,
          tier: "free"
        )
      }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private static func variationLabel(for exercise: TrainingExercise) -> String? {
    let value = exercise.coachingVariationName ?? exercise.variantLabel
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let normalized = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
    let materialNames = Set(exercise.selectableEquipmentOptions.map {
      $0.executionLabel.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
    })
    return materialNames.contains(normalized) ? nil : value
  }

  func replacementTemplate(for source: TrainingExercise) -> TrainingExercise {
    TrainingExercise(
      exerciseID: "catalog.\(baseExerciseID).for.\(source.exerciseID)",
      name: name,
      baseExerciseID: baseExerciseID,
      baseExerciseName: name,
      variantLabel: nil,
      type: source.type,
      block: source.block,
      equipment: equipment.first ?? source.equipment,
      equipmentOptions: equipment,
      trainingBlock: source.trainingBlock,
      movementPattern: movementPattern,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: [],
      supersetID: source.supersetID,
      supersetOrder: source.supersetOrder,
      phase: source.phase,
      notes: "Prescripción inicial basada en \(source.displayName).",
      target: source.target,
      decisionOptions: source.decisionOptions,
      sets: source.sets
    )
  }

  func additionTemplate(
    for session: TrainingSession,
    equipment selectedEquipment: Equipment,
    inventory: EquipmentLoadInventory
  ) -> TrainingExercise? {
    guard let source = session.exercises.first(where: {
      $0.movementPattern == movementPattern
        || !Set($0.primaryMuscles).isDisjoint(with: Set(primaryMuscles))
    }) ?? session.exercises.first else { return nil }

    var template = replacementTemplate(for: source)
    template.exerciseID = "catalog.\(baseExerciseID).addition.\(session.sessionID)"
    template.equipment = selectedEquipment
    template.equipmentOptions = [selectedEquipment]
    template.supersetID = nil
    template.supersetOrder = nil
    template.block = "Accesorio"
    template.notes = "Introducción conservadora: prioriza técnica, rango cómodo y deja margen antes de progresar."
    template.target = "Añadir trabajo técnico sin comprometer el objetivo semanal."

    let phase = source.phase.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
    let setLimit = phase == "descarga" || phase == "readaptacion" ? 1 : 2
    let initialWeight = EquipmentLoadRules.availableLoads(for: selectedEquipment, inventory: inventory).first ?? 0
    template.sets = source.sets.prefix(setLimit).enumerated().map { offset, sourceSet in
      var set = sourceSet
      set.setIndex = offset + 1
      if let reps = sourceSet.targetReps {
        set.targetReps = min(12, max(6, phase == "intensificacion" ? min(reps, 8) : reps))
      }
      set.targetWeightKg = initialWeight
      set.restSeconds = min(120, max(60, sourceSet.restSeconds))
      return set
    }
    return template
  }
}

private struct ExerciseCatalogDocument: Codable {
  let schemaName: String
  let schemaVersion: Int
  let exercises: [ExerciseCatalogEntry]
}

enum ExerciseCatalogStore {
  static func entries(for plan: TrainingPlan) -> [ExerciseCatalogEntry] {
    guard let url = Bundle.main.url(forResource: "exerciseCatalog", withExtension: "json"),
          let document = try? JSONDecoder().decode(ExerciseCatalogDocument.self, from: Data(contentsOf: url)),
          document.schemaName == "gymapp.exercise-catalog",
          document.schemaVersion == 1,
          !document.exercises.isEmpty else {
      return ExerciseCatalogEntry.entries(from: plan)
    }
    return document.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
}

struct ExerciseCatalogSettingsView: View {
  let plan: TrainingPlan
  @Query private var profileRecords: [TrainingProfileRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var draft = TrainingProfile.initial
  @State private var hasLoaded = false

  private var entries: [ExerciseCatalogEntry] { ExerciseCatalogStore.entries(for: plan) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("El entrenador y las propuestas usarán solo los ejercicios, variantes y materiales que mantengas activos. Las sesiones ya planificadas no se modifican.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)

        ForEach(entries) { entry in
          NavigationLink {
            ExerciseCatalogEntrySettingsView(entry: entry, preferences: $draft.catalogPreferences)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: draft.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID) ? "minus.circle" : "figure.strengthtraining.traditional")
                .font(.gymH2.weight(.semibold))
                .foregroundStyle(draft.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID) ? Color.gymSecondaryText : Color.gymAccent)
                .frame(width: 30, height: 30)
              VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                  .font(.gymH2.weight(.bold))
                  .foregroundStyle(.primary)
                Text(catalogDetail(for: entry))
                  .font(.gymBody)
                  .foregroundStyle(Color.gymSecondaryText)
                  .lineLimit(2)
              }
              Spacer(minLength: 8)
              Image(systemName: "chevron.right")
                .font(.gymBody.weight(.bold))
                .foregroundStyle(Color.gymSecondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.7), lineWidth: 1) }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: "Catálogo de ejercicios", detail: "Elegibilidad para propuestas futuras") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: { TrainingProfileStore.save(draft, in: modelContext); dismiss() }) }
    .onAppear {
      guard !hasLoaded else { return }
      draft = TrainingProfileStore.load(from: profileRecords) ?? .initial
      hasLoaded = true
    }
    .onChange(of: draft.catalogPreferences) { _, _ in
      guard hasLoaded else { return }
      TrainingProfileStore.save(draft, in: modelContext)
    }
  }

  private func catalogDetail(for entry: ExerciseCatalogEntry) -> String {
    if draft.catalogPreferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID) { return "No incluir en propuestas" }
    let enabledEquipment = entry.equipment.filter { draft.catalogPreferences.allows($0, for: entry.baseExerciseID) }
    return "\(enabledEquipment.map(\.executionLabel).joined(separator: ", "))"
  }
}

private struct ExerciseCatalogEntrySettingsView: View {
  let entry: ExerciseCatalogEntry
  @Binding var preferences: ExerciseCatalogPreferences
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Toggle("Incluir \(entry.name) en propuestas", isOn: Binding(
          get: { !preferences.disabledBaseExerciseIDs.contains(entry.baseExerciseID) },
          set: { preferences.setExerciseEnabled($0, baseExerciseID: entry.baseExerciseID) }
        ))
        .toggleStyle(ThemeToggleStyle())

        if !entry.variants.isEmpty {
          SettingsCategory(title: "Variantes") {
            ForEach(Array(entry.variants.enumerated()), id: \.element.id) { index, variant in
              Toggle(variant.label, isOn: Binding(
                get: { !preferences.disabledVariantExerciseIDs.contains(variant.exerciseID) },
                set: { preferences.setVariantEnabled($0, exerciseID: variant.exerciseID) }
              ))
              .toggleStyle(ThemeToggleStyle())
              .padding(16)
              if index < entry.variants.count - 1 { SettingsDivider() }
            }
          }
        }

        SettingsCategory(title: "Material permitido") {
          ForEach(Array(entry.equipment.enumerated()), id: \.element) { index, equipment in
            Toggle(equipment.executionLabel, isOn: Binding(
              get: { preferences.allows(equipment, for: entry.baseExerciseID) },
              set: { preferences.setEquipmentEnabled($0, equipment: equipment, baseExerciseID: entry.baseExerciseID) }
            ))
            .toggleStyle(ThemeToggleStyle())
            .padding(16)
            if index < entry.equipment.count - 1 { SettingsDivider() }
          }
        }

        if !entry.primaryMuscles.isEmpty {
          Text("Principalmente: \(entry.primaryMuscles.joined(separator: ", "))")
            .font(.gymBody)
            .foregroundStyle(Color.gymSecondaryText)
        }
      }
      .padding(16)
      .padding(.bottom, 88)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) { AccentHeaderCard(title: entry.name, detail: entry.movementPattern ?? "Configuración de ejercicio") }
    .overlay(alignment: .bottomLeading) { BottomBackButton(action: dismiss.callAsFunction) }
  }
}
