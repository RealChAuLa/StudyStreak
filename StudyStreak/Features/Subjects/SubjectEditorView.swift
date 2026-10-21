import SwiftData
import SwiftUI

struct SubjectEditorView: View {
    let ownerID: String
    let subject: StudySubject?
    let onSaved: (StudySubject) -> Void
    @Query private var subjects: [StudySubject]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: SubjectColor
    @State private var icon: SubjectIcon
    @State private var isActive: Bool
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(ownerID: String, subject: StudySubject? = nil, onSaved: @escaping (StudySubject) -> Void = { _ in }) {
        self.ownerID = ownerID
        self.subject = subject
        self.onSaved = onSaved
        _subjects = Query(filter: #Predicate<StudySubject> { $0.ownerID == ownerID })
        _name = State(initialValue: subject?.name ?? "")
        _color = State(initialValue: subject?.subjectColor ?? .blue)
        _icon = State(initialValue: subject?.subjectIcon ?? .book)
        _isActive = State(initialValue: subject?.isActive ?? true)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool {
        subjects.contains { $0.id != subject?.id && SubjectStore.normalizedName($0.name) == SubjectStore.normalizedName(name) }
    }
    private var canSave: Bool { !ownerID.isEmpty && (1...40).contains(trimmedName.count) && !isDuplicate }

    var body: some View {
        NavigationStack {
            subjectForm
                .scrollIndicators(.hidden, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
                .background(AppColors.background.ignoresSafeArea())
                .navigationTitle(subject == nil ? "Add a subject" : "Edit subject")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isNameFocused = false }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    saveButton
                }
        }
        .tint(AppColors.primary)
        .alert("Couldn’t save subject", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var subjectForm: some View {
        Form {
            nameSection
            activitySection
            colorSection
            iconSection
        }
    }

    private var nameSection: some View {
        Section {
            HStack(spacing: 12) {
                TextField("e.g. Design Studies", text: $name)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.text)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false }
                    .accessibilityLabel("Subject name")
                Image("SubjectNamePen").resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundStyle(AppColors.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .listRowBackground(AppColors.surface)
        } header: {
            fieldLabel("Subject name")
        } footer: {
            nameValidation
        }
    }

    @ViewBuilder
    private var nameValidation: some View {
        if isDuplicate {
            Text("You already have a subject with this name.").foregroundStyle(AppColors.danger)
        } else if trimmedName.count > 40 {
            Text("Use 40 characters or fewer.").foregroundStyle(AppColors.danger)
        }
    }

    private var colorSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SubjectColor.allCases) { option in colorButton(option) }
                }
            }
            .scrollIndicators(.visible, axes: .horizontal)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        } header: { fieldLabel("Color · swipe for more") }
    }

    private var activitySection: some View {
        Section {
            Toggle("Currently studying", isOn: $isActive)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.text)
                .tint(AppColors.success)
                .listRowBackground(AppColors.surface)
        } footer: {
            Text("Only active subjects appear when choosing a zone’s default subject.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private func colorButton(_ option: SubjectColor) -> some View {
        Button { color = option } label: {
            Circle().fill(option.color)
                .frame(width: 36, height: 36)
                .overlay {
                    if option == color {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.tagText)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(option == color ? .isSelected : [])
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                ForEach(SubjectIcon.allCases) { option in iconButton(option) }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        } header: { fieldLabel("Icon") }
    }

    private func iconButton(_ option: SubjectIcon) -> some View {
        Button { icon = option } label: {
            SubjectIconImage(icon: option)
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(icon == option ? AppColors.tint : AppColors.surface,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if icon == option {
                        RoundedRectangle(cornerRadius: 12).stroke(AppColors.primary, lineWidth: 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(option == icon ? .isSelected : [])
    }

    private var saveButton: some View {
        PrimaryButton(title: "Save Subject", action: save)
            .disabled(!canSave)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppColors.background)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.secondary)
    }

    private func save() {
        guard canSave else { return }
        isNameFocused = false
        do {
            let saved = try SubjectStore.save(name: name, color: color, icon: icon, isActive: isActive, ownerID: ownerID,
                                               editing: subject, in: modelContext)
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = (error as? SubjectStoreError)?.errorDescription ?? "Your subject couldn’t be saved. Please try again."
        }
    }
}

#Preview("21 · Add subject sheet") {
    SubjectEditorView(ownerID: "preview")
        .modelContainer(for: StudySubject.self, inMemory: true)
}
