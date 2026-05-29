import SwiftUI

struct SingleChoiceView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void

    var body: some View {
        optionGrid(systemImage: "checkmark.circle.fill")
    }

    private func optionGrid(systemImage: String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                CalibrationOptionButton(
                    title: option,
                    systemImage: systemImage,
                    isSelected: selected == option
                ) {
                    selected = option
                    onSelect(option)
                }
            }
        }
    }
}

struct FractionPickerView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                CalibrationOptionButton(
                    title: option,
                    systemImage: "circle.lefthalf.filled",
                    isSelected: selected == option
                ) {
                    selected = option
                    onSelect(option)
                }
            }
        }
    }
}

struct SliceCounterView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                CalibrationOptionButton(
                    title: option,
                    systemImage: "chart.pie.fill",
                    isSelected: selected == option
                ) {
                    selected = option
                    onSelect(option)
                }
            }
        }
    }
}

struct UnitSliderView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let selectedIndex = options.firstIndex(of: selected) {
                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { newValue in
                            let index = max(0, min(options.count - 1, Int(newValue.rounded())))
                            let option = options[index]
                            selected = option
                            onSelect(option)
                        }
                    ),
                    in: 0...Double(max(options.count - 1, 0)),
                    step: 1
                )
                .tint(Color(hex: "818cf8"))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    CalibrationOptionButton(
                        title: option,
                        systemImage: "scalemass.fill",
                        isSelected: selected == option
                    ) {
                        selected = option
                        onSelect(option)
                    }
                }
            }
        }
    }
}

private struct CalibrationOptionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isSelected ? .white : Color(hex: "c7d2fe"))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.horizontal, 8)
            .background(isSelected ? Color(hex: "6366f1") : Color(hex: "6366f1").opacity(0.12))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "818cf8").opacity(isSelected ? 0.4 : 0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
