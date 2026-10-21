import MapKit
import SwiftUI

struct ZoneEditorView: View {
    let isEditing: Bool
    @State private var draft: ZoneEditorDraft
    @State private var search = ZonePlaceSearch()
    @State private var camera: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion
    @State private var isShowingDetails = false
    @State private var isDraggingPin = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(draft: ZoneEditorDraft = ZoneEditorDraft(), isEditing: Bool = false) {
        self.isEditing = isEditing
        _draft = State(initialValue: draft)
        let region = MKCoordinateRegion(center: draft.coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        _visibleRegion = State(initialValue: region)
        _camera = State(initialValue: .region(region))
    }

    private var detailsHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 540 : 408 }

    var body: some View {
        GeometryReader { geometry in
            map
                .frame(height: max(240, geometry.size.height - detailsHeight + 48))
                .overlay(alignment: .top) { locationSearch.padding(.horizontal, 24).padding(.top, 12) }
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit study zone" : "Add a study zone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { isShowingDetails = true }
        .onDisappear { isShowingDetails = false; search.cancel() }
        .onChange(of: isSearchFocused) { _, focused in isShowingDetails = !focused }
        .sheet(isPresented: $isShowingDetails) {
            ZoneDetailsSheet(draft: $draft) {
                // TODO: Save the draft with SwiftData in the next milestone.
            }
            .presentationDetents([.height(detailsHeight), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground(AppColors.background)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(detailsHeight)))
            .interactiveDismissDisabled()
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: isDraggingPin ? [.zoom, .rotate] : .all) {
                MapCircle(center: draft.coordinate, radius: draft.radius)
                    .foregroundStyle(AppColors.primary.opacity(0.12))
                    .stroke(AppColors.primary.opacity(0.5), lineWidth: 1)
                Annotation("Study zone", coordinate: draft.coordinate) {
                    pin
                        .gesture(DragGesture(coordinateSpace: .named("zoneMap"))
                            .onChanged { value in
                                isDraggingPin = true
                                if let coordinate = proxy.convert(value.location, from: .named("zoneMap")) {
                                    draft.coordinate = coordinate
                                }
                            }
                            .onEnded { _ in isDraggingPin = false })
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in visibleRegion = context.region }
            .onTapGesture(coordinateSpace: .local) { point in
                isSearchFocused = false
                if let coordinate = proxy.convert(point, from: .local) { draft.coordinate = coordinate }
            }
            .coordinateSpace(name: "zoneMap")
        }
    }

    private var pin: some View {
        Group {
            if draft.icon == .custom {
                Image(systemName: draft.customSymbol).font(.system(size: 20))
            } else {
                Image(draft.icon == .library ? "ZoneLibraryPin" : draft.icon.assetName)
                    .resizable().scaledToFit().frame(width: 20, height: 20)
            }
        }
        .foregroundStyle(AppColors.onPrimary)
        .frame(width: 36, height: 36)
        .background(AppColors.primary, in: Circle())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Study zone pin")
        .accessibilityHint("Drag the pin or tap the map to move it.")
    }

    private var locationSearch: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image("ZoneSearch").resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
                TextField("Search place or address", text: $search.query)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.text)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        isSearchFocused = false
                        Task { await search.search(near: visibleRegion) }
                    }
                    .onChange(of: search.query) { _, _ in search.clearResults() }
                    .accessibilityLabel("Search place or address")
                if search.isSearching {
                    ProgressView().tint(AppColors.primary)
                } else if !search.query.isEmpty {
                    Button { search.clear() } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(AppColors.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 48)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))

            if !search.results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(search.results) { result in
                            Button {
                                draft.coordinate = result.coordinate
                                if draft.name.isEmpty { draft.name = result.name }
                                camera = .region(MKCoordinateRegion(center: result.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
                                search.select(result)
                                isSearchFocused = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name).font(AppTypography.headline).foregroundStyle(AppColors.text)
                                    Text(result.address).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            } else if let message = search.message {
                Text(message).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .padding(16).frame(maxWidth: .infinity)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

#Preview("34 · Add study zone") {
    NavigationStack { ZoneEditorView() }.tint(AppColors.primary)
}

#Preview("19 · Edit study zone") {
    NavigationStack {
        ZoneEditorView(draft: ZoneEditorDraft(name: "Library"), isEditing: true)
    }.tint(AppColors.primary)
}

#Preview("Add study zone · Dark") {
    NavigationStack { ZoneEditorView() }.tint(AppColors.primary).preferredColorScheme(.dark)
}
