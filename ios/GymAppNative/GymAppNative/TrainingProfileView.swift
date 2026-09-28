import SwiftUI
import SwiftData
import GymAppNativeCore

struct TrainingProfileOnboardingView: View {
  let onDefer: () -> Void
  @Environment(\.modelContext) private var modelContext
  @State private var profile = TrainingProfile.initial
  @State private var step = 0

  var body: some View {
    VStack(spacing: 0) {
      TabView(selection: $step) {
        ProfileGoalStep(profile: $profile)
          .tag(0)
        ProfileScheduleStep(profile: $profile)
          .tag(1)
        ProfileContextStep(profile: $profile)
          .tag(2)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      VStack(spacing: 12) {
        HStack(spacing: 6) {
          ForEach(0 ..< 3, id: \.self) { index in
            Capsule()
              .fill(index == step ? Color.gymAccent : Color.gymAccent.opacity(0.22))
              .frame(width: index == step ? 28 : 8, height: 6)
          }
        }

        Button(step == 2 ? "Crear mi perfil" : "Continuar") {
          if step == 2 {
            TrainingProfileStore.save(profile, in: modelContext)
          } else {
            withAnimation(.smooth) { step += 1 }
          }
        }
        .font(.gymH2.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 60)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
        .buttonStyle(.plain)

        if step > 0 {
          Button("Atrás") { withAnimation(.smooth) { step -= 1 } }
            .font(.gymBody.weight(.semibold))
            .foregroundStyle(Color.gymSecondaryText)
            .buttonStyle(.plain)
        }

        Button("Mantener mi planificación actual", action: onDefer)
          .font(.gymBody.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
          .buttonStyle(.plain)
      }
      .padding(16)
    }
    .background(GymCanvas())
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Tu entrenamiento", detail: "Configuración inicial")
    }
  }
}

struct TrainingProfileSettingsView: View {
  @Query private var profileRecords: [TrainingProfileRecord]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var draft = TrainingProfile.initial
  @State private var hasLoaded = false
  @AppStorage("trainingProfileOnboardingDeferred") private var onboardingDeferred = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ProfileGoalStep(profile: $draft, showsTitle: false)
        ProfileSectionDivider()
        ProfileScheduleStep(profile: $draft, showsTitle: false)
        ProfileSectionDivider()
        ProfileContextStep(profile: $draft, showsTitle: false)
      }
      .padding(16)
      .padding(.bottom, 92)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Perfil de entrenamiento", detail: "Se aplicará a planes y propuestas futuras")
    }
    .overlay(alignment: .bottom) {
      HStack(spacing: 12) {
        Button(action: dismiss.callAsFunction) {
          Image(systemName: "chevron.left")
            .font(.gymH2.weight(.bold))
            .frame(width: 56, height: 56)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel("Atrás")
        .buttonStyle(.plain)

        Button("Guardar perfil", action: save)
          .font(.gymH2.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 60)
          .foregroundStyle(Color.gymAccentForeground)
          .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    }
    .onAppear {
      guard !hasLoaded else { return }
      draft = TrainingProfileStore.load(from: profileRecords) ?? .initial
      hasLoaded = true
    }
  }

  private func save() {
    TrainingProfileStore.save(draft, in: modelContext)
    onboardingDeferred = false
    dismiss()
  }
}

private struct ProfileGoalStep: View {
  @Binding var profile: TrainingProfile
  var showsTitle = true

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if showsTitle {
        onboardingTitle("¿Qué quieres conseguir?", detail: "El plan se ajustará a tu objetivo y al tiempo que quieras dedicarle.")
      } else {
        sectionTitle("Objetivo y horizonte")
      }

      VStack(spacing: 8) {
        ForEach(TrainingGoal.allCases) { goal in
          ProfileSelectionRow(
            title: goal.label,
            symbol: symbol(for: goal),
            isSelected: profile.goal == goal
          ) { profile.goal = goal }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Horizonte para el objetivo")
          .font(.gymH3.weight(.bold))
        Text("El agente usará este plazo para plantear un macrociclo y señalar expectativas poco realistas.")
          .font(.gymBody)
          .foregroundStyle(Color.gymSecondaryText)
        HStack(spacing: 8) {
          ForEach([8, 12, 16, 24, 52], id: \.self) { weeks in
            TimeframeOption(
              weeks: weeks,
              isSelected: profile.targetTimeframeWeeks == weeks,
              action: { profile.targetTimeframeWeeks = weeks }
            )
          }
        }
      }
    }
  }

  private func symbol(for goal: TrainingGoal) -> String {
    switch goal {
    case .strength: "dumbbell.fill"
    case .muscle: "figure.strengthtraining.traditional"
    case .health: "heart.fill"
    case .performance: "bolt.fill"
    }
  }
}

private struct TimeframeOption: View {
  let weeks: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button("\(weeks) sem", action: action)
      .font(.gymBody.weight(.semibold))
      .frame(maxWidth: .infinity, minHeight: 44)
      .foregroundStyle(isSelected ? Color.gymControlSelectionForeground : Color.gymSecondaryText)
      .background(isSelected ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.gymAccent : Color.secondary.opacity(0.35), lineWidth: 1)
      }
      .buttonStyle(.plain)
  }
}

private struct ProfileScheduleStep: View {
  @Binding var profile: TrainingProfile
  var showsTitle = true
  private let weekdays = [(1, "L"), (2, "M"), (3, "X"), (4, "J"), (5, "V"), (6, "S"), (7, "D")]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if showsTitle {
        onboardingTitle("¿Cuándo entrenas?", detail: "La disponibilidad y el tiempo por sesión son límites del plan, no sugerencias.")
      } else {
        sectionTitle("Disponibilidad")
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Días disponibles")
          .font(.gymH3.weight(.bold))
        HStack(spacing: 8) {
          ForEach(weekdays, id: \.0) { day, label in
            Button(label) {
              if profile.trainingWeekdays.contains(day) {
                guard profile.trainingWeekdays.count > 1 else { return }
                profile.trainingWeekdays.remove(day)
              } else {
                profile.trainingWeekdays.insert(day)
              }
            }
            .font(.gymH3.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(profile.trainingWeekdays.contains(day) ? Color.gymAccentForeground : Color.gymSecondaryText)
            .background(profile.trainingWeekdays.contains(day) ? Color.gymAccent : Color.gymSurface, in: Circle())
            .buttonStyle(.plain)
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Tiempo por sesión")
          .font(.gymH3.weight(.bold))
        Picker("Tiempo por sesión", selection: $profile.sessionDurationMinutes) {
          ForEach([30, 45, 60, 75, 90], id: \.self) { minutes in
            Text("\(minutes) min").tag(minutes)
          }
        }
        .pickerStyle(.segmented)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Experiencia")
          .font(.gymH3.weight(.bold))
        Picker("Experiencia", selection: $profile.experience) {
          ForEach(TrainingExperience.allCases) { experience in
            Text(experience.label).tag(experience)
          }
        }
        .pickerStyle(.segmented)
      }
    }
  }
}

private struct ProfileContextStep: View {
  @Binding var profile: TrainingProfile
  var showsTitle = true

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if showsTitle {
          onboardingTitle("Contexto para tu plan", detail: "Estos datos permiten proponer alternativas realistas cuando cambie tu semana.")
        } else {
          sectionTitle("Material y preferencias")
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Material disponible")
            .font(.gymH3.weight(.bold))
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Equipment.allCases, id: \.self) { equipment in
              ProfileSelectionRow(
                title: equipment.label,
                symbol: equipment.symbol,
                isSelected: profile.availableEquipment.contains(equipment)
              ) {
                if profile.availableEquipment.contains(equipment) {
                  guard profile.availableEquipment.count > 1 else { return }
                  profile.availableEquipment.remove(equipment)
                } else {
                  profile.availableEquipment.insert(equipment)
                }
              }
            }
          }
        }

        ProfileSectionDivider()
        LoadInventorySection(profile: $profile)

        ProfileSectionDivider()
        ProfileTextField(label: "Prioridades musculares", placeholder: "Ej. pecho, espalda y piernas", value: $profile.priorityText)
        ProfileTextField(label: "Preferencias", placeholder: "Ej. prefiero ejercicios con barra", value: $profile.exercisePreferences)
        ProfileTextField(label: "Ejercicios a evitar", placeholder: "Ej. fondos", value: $profile.exercisesToAvoid)
        ProfileTextField(label: "Limitaciones", placeholder: "Ej. evitar superseries", value: $profile.limitations)
        ProfileHealthEntryEditor(
          title: "Molestias declaradas",
          detail: "Se muestran para valorarlas de 0 a 3 durante la serie. No bloquean ejercicios; el plan te pedirá precaución cuando afecten a un movimiento.",
          placeholder: "Ej. hombro derecho",
          addLabel: "Añadir molestia",
          entries: $profile.declaredDiscomforts
        )
        ProfileHealthEntryEditor(
          title: "Lesiones o restricciones médicas",
          detail: "Una lesión sí bloquea patrones o ejercicios compatibles hasta que la elimines. Usa descripciones concretas, por ejemplo: lesión de rodilla.",
          placeholder: "Ej. lesión de rodilla",
          addLabel: "Añadir lesión",
          entries: $profile.declaredInjuries
        )
      }
    }
  }
}

private struct LoadInventorySection: View {
  @Binding var profile: TrainingProfile

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Cargas disponibles")
        .font(.gymH3.weight(.bold))
      Text("Añade cada peso y sus unidades. Toca una carga para eliminarla.")
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)

      LoadInventoryEditor(
        title: "Mancuernas",
        values: $profile.dumbbellWeightsKg,
        unitsByWeight: $profile.dumbbellUnitsByWeight
      )
      LoadInventoryEditor(
        title: "Discos",
        values: $profile.plateWeightsKg,
        unitsByWeight: $profile.plateUnitsByWeight
      )
      LoadNumberField(label: "Paso de las poleas", value: $profile.cableStepKg)
      LoadNumberField(label: "Peso de la barra", value: $profile.barbellWeightKg)
      LoadNumberField(label: "Peso de la Multipower", value: $profile.multipowerBarWeightKg)
      ProfileSectionDivider()
      Text("Peso corporal").font(.gymH3.weight(.bold))
      Text("Configura el salto de asistencia y los lastres que puedes montar con seguridad.")
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)
      LoadNumberField(label: "Paso de asistencia", value: $profile.bodyweightAssistanceStepKg)
      BodyweightLoadEditor(values: $profile.bodyweightWeightedLoadsKg)
    }
    .padding(.vertical, 4)
  }
}

private struct BodyweightLoadEditor: View {
  @Binding var values: [Double]
  @State private var weightText = ""
  @State private var selectedWeights: Set<Double> = []

  private let columns = [GridItem(.adaptive(minimum: 84), spacing: 8, alignment: .leading)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Lastres disponibles").font(.gymH3.weight(.bold))
      HStack(spacing: 8) {
        TextField("Peso en kg", text: $weightText)
          .font(.gymBody.weight(.semibold))
          .keyboardType(.decimalPad)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
          .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.35), lineWidth: 1) }
        Button(action: add) {
          Image(systemName: "plus")
            .font(.gymH3.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(parsedWeight == nil)
        .opacity(parsedWeight == nil ? 0.45 : 1)
        .accessibilityLabel("Añadir lastre")
      }
      if !values.isEmpty {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
          ForEach(values, id: \.self) { weight in
            Button { toggleSelection(weight) } label: {
              Text("+\(weight.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
                .font(.gymBody.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selectedWeights.contains(weight) ? Color.gymControlSelectionForeground : .primary)
                .background(selectedWeights.contains(weight) ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(selectedWeights.contains(weight) ? Color.gymAccent : Color.gymAccent.opacity(0.35), lineWidth: selectedWeights.contains(weight) ? 2 : 1) }
            }
            .buttonStyle(.plain)
          }
        }
        if !selectedWeights.isEmpty {
          Button(role: .destructive, action: removeSelected) {
            Label("Eliminar seleccionados", systemImage: "trash")
              .font(.gymBody.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var parsedWeight: Double? {
    Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
      .flatMap { $0 > 0 ? ($0 * 100).rounded() / 100 : nil }
  }

  private func add() {
    guard let weight = parsedWeight else { return }
    if !values.contains(where: { abs($0 - weight) < 0.001 }) {
      values.append(weight)
      values.sort()
    }
    weightText = ""
  }

  private func toggleSelection(_ weight: Double) {
    if selectedWeights.contains(weight) { selectedWeights.remove(weight) } else { selectedWeights.insert(weight) }
  }

  private func removeSelected() {
    values.removeAll { selectedWeights.contains($0) }
    selectedWeights.removeAll()
  }
}

private struct LoadInventoryEditor: View {
  let title: String
  @Binding var values: [Double]
  @Binding var unitsByWeight: [String: Int]
  @State private var weightText = ""
  @State private var units = 2
  @State private var selectedWeights: Set<Double> = []

  private let chipColumns = [GridItem(.adaptive(minimum: 78), spacing: 8, alignment: .leading)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.gymH3.weight(.bold))

      HStack(spacing: 8) {
        TextField("Peso en kg", text: $weightText)
          .font(.gymBody.weight(.semibold))
          .keyboardType(.decimalPad)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
          .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.35), lineWidth: 1) }

        Button(action: add) {
          Image(systemName: "plus")
            .font(.gymH3.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: Circle())
        }
        .accessibilityLabel("Añadir \(title.lowercased())")
        .buttonStyle(.plain)
        .disabled(parsedWeight == nil)
        .opacity(parsedWeight == nil ? 0.45 : 1)
      }

      HStack(spacing: 10) {
        Text("Unidades")
          .font(.gymSupport.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
        Spacer()
        Button { units = max(1, units - 1) } label: {
          Image(systemName: "minus")
            .font(.gymBody.weight(.bold))
            .frame(width: 36, height: 36)
            .background(Color.gymSurface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(units == 1)
        .opacity(units == 1 ? 0.4 : 1)

        Text("\(units) ud")
          .font(.gymBody.weight(.bold))
          .frame(minWidth: 44)

        Button { units = min(99, units + 1) } label: {
          Image(systemName: "plus")
            .font(.gymBody.weight(.bold))
            .frame(width: 36, height: 36)
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: Circle())
        }
        .buttonStyle(.plain)
      }

      if !values.isEmpty {
        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
          ForEach(values, id: \.self) { weight in
            Button { toggleSelection(weight) } label: {
              VStack(spacing: 2) {
                Text("\(weight.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
                  .font(.gymBody.weight(.bold))
                Text("\(units(for: weight)) ud")
                  .font(.gymSupport)
                  .foregroundStyle(Color.gymSecondaryText)
              }
              .frame(maxWidth: .infinity, minHeight: 50)
              .padding(.horizontal, 6)
              .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
              .overlay {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(selectedWeights.contains(weight) ? Color.gymAccent : Color.gymAccent.opacity(0.35), lineWidth: selectedWeights.contains(weight) ? 2 : 1)
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seleccionar \(weight.formatted()) kg")
          }
        }

        if !selectedWeights.isEmpty {
          Button(role: .destructive, action: removeSelected) {
            Label("Eliminar seleccionados", systemImage: "trash")
              .font(.gymBody.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var parsedWeight: Double? {
    Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
      .flatMap { $0 > 0 ? ($0 * 100).rounded() / 100 : nil }
  }

  private func add() {
    guard let weight = parsedWeight else { return }
    if !values.contains(where: { abs($0 - weight) < 0.001 }) {
      values.append(weight)
      values.sort()
    }
    unitsByWeight[loadKey(weight)] = units
    weightText = ""
    selectedWeights.remove(weight)
  }

  private func toggleSelection(_ weight: Double) {
    if selectedWeights.contains(weight) {
      selectedWeights.remove(weight)
    } else {
      selectedWeights.insert(weight)
    }
  }

  private func removeSelected() {
    values.removeAll { selectedWeights.contains($0) }
    for weight in selectedWeights {
      unitsByWeight.removeValue(forKey: loadKey(weight))
    }
    selectedWeights.removeAll()
  }

  private func units(for weight: Double) -> Int {
    max(1, unitsByWeight[loadKey(weight)] ?? 2)
  }

  private func loadKey(_ weight: Double) -> String {
    String(format: "%.2f", weight)
  }
}

private struct ProfileHealthEntryEditor: View {
  let title: String
  let detail: String
  let placeholder: String
  let addLabel: String
  @Binding var entries: [String]
  @State private var entryText = ""
  @State private var selectedEntries = Set<String>()

  private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.gymH3.weight(.bold))
      Text(detail)
        .font(.gymSupport)
        .foregroundStyle(Color.gymSecondaryText)

      HStack(spacing: 8) {
        TextField(placeholder, text: $entryText)
          .font(.gymBody.weight(.semibold))
          .textInputAutocapitalization(.sentences)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
          .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.35), lineWidth: 1) }

        Button(action: add) {
          Image(systemName: "plus")
            .font(.gymH3.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: Circle())
        }
        .accessibilityLabel(addLabel)
        .buttonStyle(.plain)
        .disabled(trimmedEntry.isEmpty)
        .opacity(trimmedEntry.isEmpty ? 0.45 : 1)
      }

      if !entries.isEmpty {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
          ForEach(entries, id: \.self) { entry in
            Button { toggleSelection(entry) } label: {
              Text(entry)
                .font(.gymBody.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .foregroundStyle(selectedEntries.contains(entry) ? Color.gymControlSelectionForeground : .primary)
                .background(selectedEntries.contains(entry) ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedEntries.contains(entry) ? Color.gymAccent : Color.gymAccent.opacity(0.35), lineWidth: selectedEntries.contains(entry) ? 2 : 1)
                }
            }
            .buttonStyle(.plain)
          }
        }

        if !selectedEntries.isEmpty {
          Button(role: .destructive, action: removeSelected) {
            Label("Eliminar seleccionadas", systemImage: "trash")
              .font(.gymBody.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var trimmedEntry: String {
    entryText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func add() {
    guard !trimmedEntry.isEmpty,
          !entries.contains(where: { $0.compare(trimmedEntry, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
    else { return }
    entries.append(trimmedEntry)
    entries.sort { $0.localizedStandardCompare($1) == .orderedAscending }
    entryText = ""
  }

  private func toggleSelection(_ entry: String) {
    if selectedEntries.contains(entry) {
      selectedEntries.remove(entry)
    } else {
      selectedEntries.insert(entry)
    }
  }

  private func removeSelected() {
    entries.removeAll { selectedEntries.contains($0) }
    selectedEntries.removeAll()
  }
}

private struct LoadNumberField: View {
  let label: String
  @Binding var value: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.gymH3.weight(.bold))
      HStack {
        Spacer()
      TextField("kg", value: $value, format: .number.precision(.fractionLength(0 ... 2)))
        .font(.gymBody.weight(.bold))
        .multilineTextAlignment(.trailing)
        .keyboardType(.decimalPad)
        .frame(width: 88)
      Text("kg").font(.gymSupport).foregroundStyle(Color.gymSecondaryText)
      }
      .padding(12)
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 14))
      .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.35), lineWidth: 1) }
    }
  }
}

private struct ProfileSectionDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.gymAccent.opacity(0.18))
      .frame(height: 1)
      .padding(.vertical, 4)
  }
}

private struct ProfileSelectionRow: View {
  let title: String
  let symbol: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: symbol).frame(width: 20)
        Text(title).lineLimit(1)
        Spacer(minLength: 4)
        if isSelected { Image(systemName: "checkmark") }
      }
      .font(.gymBody.weight(.semibold))
      .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
      .padding(.horizontal, 12)
      .foregroundStyle(isSelected ? Color.gymControlSelectionForeground : .primary)
      .background(isSelected ? Color.gymControlSelectionFill : Color.gymSurface, in: RoundedRectangle(cornerRadius: 14))
      .overlay { RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.gymAccent : Color.secondary.opacity(0.35), lineWidth: 1) }
    }
    .buttonStyle(.plain)
  }
}

private struct ProfileTextField: View {
  let label: String
  let placeholder: String
  @Binding var value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.gymH3.weight(.bold))
      TextField(placeholder, text: $value, axis: .vertical)
        .font(.gymBody)
        .lineLimit(2 ... 4)
        .padding(12)
        .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.separator.opacity(0.7), lineWidth: 1) }
    }
  }
}

private func onboardingTitle(_ title: String, detail: String) -> some View {
  VStack(alignment: .leading, spacing: 8) {
    Text(title).font(.gymH1.weight(.bold))
    Text(detail).font(.gymBody).foregroundStyle(Color.gymSecondaryText)
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .padding(.horizontal, 20)
  .padding(.top, 28)
}

private func sectionTitle(_ value: String) -> some View {
  Text(value)
    .font(.gymH2.weight(.bold))
    .frame(maxWidth: .infinity, alignment: .leading)
}

private extension Equipment {
  var label: String {
    switch self {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Máquina de discos"
    case .external: "Lastre"
    case .bodyweight: "Peso corporal"
    }
  }

  var symbol: String {
    switch self {
    case .barbell: "figure.strengthtraining.traditional"
    case .multipower: "square.stack.3d.up"
    case .dumbbell: "dumbbell.fill"
    case .cable: "arrow.down.to.line"
    case .plateLoadedMachine: "gearshape.2"
    case .external: "plus.circle"
    case .bodyweight: "figure.strengthtraining.functional"
    }
  }
}

private extension TrainingProfile {
  var priorityText: String {
    get { priorityMuscleGroups.joined(separator: ", ") }
    set {
      priorityMuscleGroups = newValue
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
  }
}
