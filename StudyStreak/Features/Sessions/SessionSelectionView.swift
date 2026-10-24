import SwiftData
import SwiftUI

struct SessionSelectionView: View {
    let ownerID: String
    let existing: SessionRecord?
    let onCommitted: () -> Void
    @Environment(StudySessionTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [StudySubject]
    @Query private var zones: [StudyZone]
    @State private var subjectID: UUID?
    @State private var zoneID: UUID?
    @State private var isAddingSubject = false
    @State private var errorMessage: String?

    init(ownerID: String, existing: SessionRecord? = nil, onCommitted: @escaping () -> Void) {
        self.ownerID = ownerID
        self.existing = existing
        self.onCommitted = onCommitted
        _subjectID = State(initialValue: existing?.subject.id)
        _zoneID = State(initialValue: existing?.zoneID)
        _subjects = Query(filter: #Predicate<StudySubject> { $0.ownerID == ownerID && $0.isActive },
                          sort: \.sortIndex)
        _zones = Query(filter: #Predicate<StudyZone> { $0.ownerID == ownerID && $0.isEnabled },
                       sort: \.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heading
                Text("Choose a subject to give your focus a name.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                subjectPicker
                if subjects.isEmpty {
                    Text("Add your first subject, or activate one in Your subjects.")
                        .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                zonePicker
                if let errorMessage {
                    Text(errorMessage).font(AppTypography.subheadline).foregroundStyle(AppColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { actions }
        .onAppear {
            if !subjects.contains(where: { $0.id == subjectID }) { subjectID = subjects.first?.id }
        }
        .onChange(of: subjects.map(\.id)) { _, _ in
            if !subjects.contains(where: { $0.id == subjectID }) { subjectID = subjects.first?.id }
        }
        .onChange(of: zones.map(\.id)) { _, ids in
            if let zoneID, !ids.contains(zoneID) { self.zoneID = nil }
        }
        .sheet(isPresented: $isAddingSubject) {
            SubjectEditorView(ownerID: ownerID) { subject in subjectID = subject.id }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(existing == nil ? "What are you studying?" : "Change subject")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            SessionCloseButton { dismiss() }
        }
    }

    private var subjectPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(subjects) { subject in
                    let snapshot = SessionSubject(id: subject.id, name: subject.name,
                                                  colorID: subject.colorID, iconID: subject.iconID)
                    Button { subjectID = subject.id } label: {
                        SessionSubjectPill(subject: snapshot, height: 44)
                            .fixedSize(horizontal: true, vertical: false)
                            .overlay {
                                Capsule().stroke(subjectID == subject.id ? AppColors.primary : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(subjectID == subject.id ? .isSelected : [])
                }
                Button { isAddingSubject = true } label: {
                    Label("Add Subject", systemImage: "plus")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(AppColors.tint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY ZONE").font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondary)
            if let existing {
                Text(existing.zoneName ?? "Not in a zone")
                    .font(AppTypography.body).foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Menu {
                    Button("Not in a zone") { zoneID = nil }
                    ForEach(zones) { zone in
                        Button(zone.name) { zoneID = zone.id }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(zones.first { $0.id == zoneID }?.name ?? "Not in a zone")
                            .font(AppTypography.body).foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image("SessionDown").resizable().scaledToFit().frame(width: 20, height: 20)
                            .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("Study zone")
                .accessibilityValue(zones.first { $0.id == zoneID }?.name ?? "Not in a zone")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: existing == nil ? "Start Session" : "Done", action: commit)
                .disabled(!subjects.contains { $0.id == subjectID })
            Text(existing == nil ? "You can pause or stop whenever you need."
                 : (existing?.state == .paused ? "Your session will stay paused." : "Your timer will keep running."))
                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(AppColors.background)
    }

    private func commit() {
        guard let subjectID else { return }
        do {
            if existing != nil { try tracker.changeSubject(to: subjectID) }
            else { try tracker.start(subjectID: subjectID, zoneID: zoneID) }
            onCommitted()
        } catch {
            errorMessage = SessionTrackingError.message(for: error)
        }
    }
}
