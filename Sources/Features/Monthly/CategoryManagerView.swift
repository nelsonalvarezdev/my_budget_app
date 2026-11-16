import SwiftUI
import SwiftData

/// Sheet for managing expense categories: create new ones (with a color)
/// and delete existing ones.
struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue

    /// Palette offered when creating a category.
    private let colorChoices: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple,
        .pink, .brown, .gray,
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("New category") {
                    TextField("Category name", text: $newCategoryName)
                        .autocorrectionDisabled()

                    Picker("Color", selection: $newCategoryColor) {
                        ForEach(colorChoices, id: \.description) { color in
                            HStack {
                                Circle().fill(color).frame(width: 20, height: 20)
                                Text(colorName(color))
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Create category") {
                        modelContext.insert(
                            ExpenseCategory(name: newCategoryName.trimmingCharacters(in: .whitespaces), colorHex: newCategoryColor.hexString)
                        )
                        newCategoryName = ""
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            HStack {
                                Circle().fill(category.color).frame(width: 14, height: 14)
                                Text(category.name)
                                if category.isDefault {
                                    Spacer()
                                    Text("Default")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets where !categories[offset].isDefault {
                                modelContext.delete(categories[offset])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .teal: "Teal"
        case .cyan: "Cyan"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .brown: "Brown"
        case .gray: "Gray"
        default: "Custom"
        }
    }
}
