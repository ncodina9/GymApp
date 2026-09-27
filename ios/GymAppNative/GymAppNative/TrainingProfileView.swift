import SwiftUI
import SwiftData
import GymAppNativeCore

struct TrainingProfileOnboardingView: View {
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ProfileGoalStep(profile: $draft, showsTitle: false)
        ProfileScheduleStep(profile: $draft, showsTitle: false)
        ProfileContextStep(profile: $draft, showsTitle: false)
      }
      .padding(16)
      .padding(.bottom, 96)
    }
    .background(GymCanvas())
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Perfil de entrenamiento", detail: "Se aplicará a planes y propuestas futuras")
    }
    .overlay(alignment: .bottom) {
      Button("Guardar perfil", action: save)
        .font(.gymH2.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 60)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .overlay(alignment: .bottomLeading) {
      Button(action: dismiss.callAsFunction) {
        Image(systemName: "chevron.left")
          .font(.gymH2.weight(.bold))
          .frame(width: 56, height: 56)
          .foregroundStyle(.primary)
          .glassEffect(.regular.interactive(), in: Circle())
      }
      .accessibilityLabel("Atrás")
      .buttonStyle(.plain)
      .padding(.leading, 20)
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

        ProfileTextField(label: "Prioridades musculares", placeholder: "Ej. pecho, espalda y piernas", value: $profile.priorityText)
        ProfileTextField(label: "Preferencias", placeholder: "Ej. prefiero ejercicios con barra", value: $profile.exercisePreferences)
        ProfileTextField(label: "Ejercicios a evitar", placeholder: "Ej. fondos", value: $profile.exercisesToAvoid)
        ProfileTextField(label: "Limitaciones o molestias", placeholder: "Ej. hombro derecho sensible", value: $profile.limitations)
      }
    }
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
