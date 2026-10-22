import SwiftData
import SwiftUI

struct ZonesView: View {
    @Environment(\.studyUserID) private var ownerID

    var body: some View {
        ZoneListContent(ownerID: ownerID).id(ownerID)
    }
}

private struct ZoneListContent: View {
    let ownerID: String
    @Query private var zones: [StudyZone]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingZone = false
    @State private var zoneToEdit: StudyZone?
    @State private var zoneToDelete: StudyZone?
    @State private var errorMessage: String?

    init(ownerID: String) {
        self.ownerID = ownerID
        _zones = Query(filter: #Predicate<StudyZone> { $0.ownerID == ownerID },
                       sort: [SortDescriptor(\StudyZone.createdAt), SortDescriptor(\StudyZone.name)])
    }

    var body: some View {
        Group {
            if zones.isEmpty {
                ZonesEmptyView(canAdd: !ownerID.isEmpty) { isAddingZone = true }
            } else {
                savedZones
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Study zones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .largeTitle) {
                    Text("Study zones").font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            if !zones.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAddingZone = true } label: {
                        Image("ZoneListAdd").resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    .tint(AppColors.primary)
                    .accessibilityLabel("Add study zone")
                }
            }
        }
        .navigationDestination(isPresented: $isAddingZone) { ZoneEditorView() }
        .navigationDestination(item: $zoneToEdit) { zone in ZoneEditorView(zone: zone) }
        .confirmationDialog("Delete study zone?", isPresented: Binding(
            get: { zoneToDelete != nil }, set: { if !$0 { zoneToDelete = nil } }
        ), titleVisibility: .visible, presenting: zoneToDelete) { zone in
            Button("Delete Zone", role: .destructive) { delete(zone) }
            Button("Cancel", role: .cancel) { zoneToDelete = nil }
        } message: { zone in
            Text("“\(zone.name)” will be removed from your saved study zones.")
        }
        .alert("Couldn’t delete zone", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    private var savedZones: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Your places, ready when you are.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .padding(.bottom, 8)
                ForEach(zones) { zone in
                    Button { zoneToEdit = zone } label: { ZoneCard(zone: zone) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit study zone. Touch and hold for more actions.")
                        .contextMenu {
                            Button("Edit Zone", systemImage: "pencil") { zoneToEdit = zone }
                            Button("Delete Zone", systemImage: "trash", role: .destructive) { zoneToDelete = zone }
                        }
                }
                trackingTip
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            Button { isAddingZone = true } label: {
                Image("ZoneListAddFloating").resizable().scaledToFit().frame(width: 25, height: 25)
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 56, height: 56)
                    .background(AppColors.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add study zone")
            .padding(.trailing, 32).padding(.bottom, 16)
        }
    }

    private var trackingTip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Let your routine do the remembering.")
                .font(AppTypography.headline).foregroundStyle(AppColors.text)
            Text("Keep your favorite study places together, ready for your next session.")
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.text.opacity(0.05), radius: 8, y: 4)
    }

    private func delete(_ zone: StudyZone) {
        zoneToDelete = nil
        do { try ZoneStore.delete(zone, ownerID: ownerID, in: modelContext) }
        catch { errorMessage = error.localizedDescription }
    }
}

#Preview("17 · Study zones") {
    ZonesListPreview().tint(AppColors.primary)
}

#Preview("Study zones · Dark") {
    ZonesListPreview().tint(AppColors.primary).preferredColorScheme(.dark)
}

#Preview("Study zones · SE", traits: .fixedLayout(width: 375, height: 667)) {
    ZonesListPreview().tint(AppColors.primary)
}

private struct ZonesListPreview: View {
    private let container: ModelContainer

    init() {
        container = try! ModelContainer(for: StudySubject.self, StudyZone.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let subject = StudySubject(ownerID: "preview", name: "Mathematics", colorID: "blue", iconID: "atom", sortIndex: 0)
        container.mainContext.insert(subject)
        container.mainContext.insert(StudyZone(ownerID: "preview", name: "Library", latitude: 6.9271,
            longitude: 79.8612, radiusMeters: 150, iconID: "library", defaultSubject: subject))
        container.mainContext.insert(StudyZone(ownerID: "preview", name: "Home desk", latitude: 6.918,
            longitude: 79.87, radiusMeters: 100, iconID: "desk", defaultSubject: subject))
    }

    var body: some View {
        NavigationStack { ZonesView() }
            .environment(\.studyUserID, "preview")
            .modelContainer(container)
    }
}
