import SwiftData
import SwiftUI

struct SubjectsView: View {
    let ownerID: String
    @Query private var subjects: [StudySubject]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingSubject = false
    @State private var subjectToEdit: StudySubject?
    @State private var errorMessage: String?

    init(ownerID: String) {
        self.ownerID = ownerID
        _subjects = Query(filter: #Predicate<StudySubject> { $0.ownerID == ownerID },
                          sort: [SortDescriptor(\StudySubject.sortIndex), SortDescriptor(\StudySubject.createdAt)])
    }

    var body: some View {
        Group {
            if subjects.isEmpty {
                SubjectsEmptyView(canAddSubject: !ownerID.isEmpty) { isAddingSubject = true }
            } else {
                subjectList
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Subjects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isAddingSubject) {
            SubjectEditorView(ownerID: ownerID)
                .presentationDetents([.height(590), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $subjectToEdit) { subject in
            SubjectEditorView(ownerID: ownerID, subject: subject)
                .presentationDetents([.height(590), .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Couldn’t reorder subjects", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    private var subjectList: some View {
        List {
            Section {
                ForEach(subjects) { subject in
                    subjectRow(subject)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(AppColors.surface)
                        .listRowSeparatorTint(AppColors.border)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit", systemImage: "pencil") { subjectToEdit = subject }
                                .tint(AppColors.primary)
                        }
                }
                .onMove(perform: moveSubjects)
            } header: {
                Text("A place for every kind of curiosity.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                    .textCase(nil)
                    .padding(.bottom, 8)
            }

            Section {
                Button { isAddingSubject = true } label: {
                    Text("+ Add Subject")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppColors.tint)
                .disabled(ownerID.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
    }

    private func subjectRow(_ subject: StudySubject) -> some View {
        HStack(spacing: 12) {
            SubjectIconImage(icon: subject.subjectIcon, size: 19, isListRow: true)
                .foregroundStyle(AppColors.tagText)
                .frame(width: 36, height: 36)
                .background(subject.subjectColor.color, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                // Real totals will come from saved study sessions when tracking is added.
                Text("0m total")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("SubjectGrip").resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(AppColors.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityHint("Touch and hold, then drag to reorder. Swipe left to edit.")
    }

    private func moveSubjects(from offsets: IndexSet, to destination: Int) {
        var reordered = subjects
        reordered.move(fromOffsets: offsets, toOffset: destination)
        do { try SubjectStore.reorder(reordered, ownerID: ownerID, in: modelContext) }
        catch { errorMessage = error.localizedDescription }
    }
}

#Preview("20 · Your subjects") {
    NavigationStack { SubjectsView(ownerID: "preview") }
        .modelContainer(for: StudySubject.self, inMemory: true)
        .tint(AppColors.primary)
}

#Preview("Your subjects · Dark") {
    NavigationStack { SubjectsView(ownerID: "preview") }
        .modelContainer(for: StudySubject.self, inMemory: true)
        .tint(AppColors.primary)
        .preferredColorScheme(.dark)
}
