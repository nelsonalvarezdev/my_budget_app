import SwiftUI
import SwiftData

/// Sheet for managing expense categories, listed A to Z: create new ones
/// and delete those that are not built in.
struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("New category") {
                    TextField("Category name", text: $newCategoryName)
                        .autocorrectionDisabled()


                    Button("Create category") {
                        modelContext.insert(
                            ExpenseCategory(name: newCategoryName.trimmingCharacters(in: .whitespaces))
                        )
                        newCategoryName = ""
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                let sorted = categories.alphabetical
                if !sorted.isEmpty {
                    Section("Categories") {
                        ForEach(sorted) { category in
                            HStack {
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
                            for offset in offsets where !sorted[offset].isDefault {
                                modelContext.delete(sorted[offset])
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
}
