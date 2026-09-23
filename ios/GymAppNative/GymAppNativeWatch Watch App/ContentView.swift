//
//  ContentView.swift
//  GymAppNativeWatch Watch App
//
//  Created by Néstor Codina on 23/09/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectivity: WatchWorkoutConnectivity

    var body: some View {
        Group {
            if let workout = connectivity.workout {
                WatchWorkoutView(workout: workout, onCommand: connectivity.send)
            } else {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        "Sin entrenamiento activo",
                        systemImage: "iphone",
                        description: Text("Inicia o reanuda un entrenamiento en el iPhone.")
                    )
                    Text(connectivity.connectionStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Actualizar") { connectivity.requestState() }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct WatchWorkoutView: View {
    let workout: WatchWorkoutState
    let onCommand: (WatchWorkoutCommand) -> Void

    private var isResting: Bool { workout.phase == .rest }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(workout.workoutName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(workout.exerciseName)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Serie \(workout.exerciseSetNumber)/\(workout.exerciseSetTotal)")
                    .font(.headline)

                HStack(spacing: 8) {
                    metric("Reps", value: workout.reps.map(String.init) ?? "Tiempo")
                    metric("Peso", value: WeightFormatter.string(from: workout.weightKg))
                }

                if let endsAt = workout.timerEndsAt {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(endsAt, style: .timer)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isResting ? .cyan : .primary)
                    }
                }

                if isResting {
                    HStack(spacing: 8) {
                        Button("-15") { onCommand(.subtractRest15) }
                        Button("+15") { onCommand(.addRest15) }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Label("Registra la serie en el iPhone", systemImage: "iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ProgressView(
                    value: Double(workout.completedSetCount),
                    total: Double(max(workout.totalSetCount, 1))
                )
                Text("\(workout.completedSetCount) de \(workout.totalSetCount) series")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private enum WeightFormatter {
    static func string(from value: Double) -> String {
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(Locale(identifier: "es_ES")))
        return "\(formatted) kg"
    }
}

#Preview {
    ContentView()
}
