import CoreLocation
import Foundation
import MapKit
import SwiftUI
import UIKit

struct ZoneEditorView: View {
    let isEditing: Bool
    @State private var draft: ZoneEditorDraft
    @State private var search = ZonePlaceSearch()
    @State private var camera: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion
    @State private var isShowingDetails = false
    @State private var pinDrag: PinDrag?
    @GestureState private var isPinGestureActive = false
    @State private var isChoosingLocation = false
    @State private var keyboardTop: CGFloat?
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
            let viewport = MapViewport(
                size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom),
                bottomSafeArea: geometry.safeAreaInsets.bottom,
                globalMinY: geometry.frame(in: .global).minY
            )
            map
                .frame(width: viewport.size.width, height: viewport.size.height)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                .overlay(alignment: .top) {
                    locationSearch(in: viewport).padding(.horizontal, 24).padding(.top, 12)
                }
                .onChange(of: viewport, initial: true) { _, value in focusOnZone(in: value) }
                .onChange(of: isChoosingLocation) { _, _ in focusOnZone(in: viewport) }
                .onChange(of: detailsHeight) { _, _ in focusOnZone(in: viewport) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                    guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
                    keyboardTop = frame.cgRectValue.minY
                    if isChoosingLocation && pinDrag == nil { focusOnZone(in: viewport) }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardTop = nil
                    if isChoosingLocation && pinDrag == nil { focusOnZone(in: viewport) }
                }
        }
        // The map stays full height while the keyboard covers its lower portion.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit study zone" : "Add a study zone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { isShowingDetails = true }
        .onDisappear { isShowingDetails = false; pinDrag = nil; search.cancel() }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                isChoosingLocation = true
                isShowingDetails = false
            }
        }
        .onChange(of: isPinGestureActive) { _, active in
            // GestureState also resets when a gesture is cancelled or interrupted.
            if !active { pinDrag = nil }
        }
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
            Map(position: $camera, interactionModes: isPinGestureActive ? [] : .all) {
                MapCircle(center: pinDrag?.coordinate ?? draft.coordinate, radius: draft.radius)
                    .foregroundStyle(AppColors.primary.opacity(0.12))
                    .stroke(AppColors.primary.opacity(0.5), lineWidth: 1)
                Annotation("Study zone", coordinate: pinDrag?.originCoordinate ?? draft.coordinate) {
                    pin
                        .offset(pinDrag?.translation ?? .zero)
                        .highPriorityGesture(DragGesture(coordinateSpace: .global)
                            .updating($isPinGestureActive) { _, active, _ in active = true }
                            .onChanged { value in updatePinDrag(value, using: proxy) }
                            .onEnded { value in finishPinDrag(value, using: proxy) })
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in visibleRegion = context.region }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = proxy.convert(point, from: .local) { draft.coordinate = coordinate }
                if isChoosingLocation { finishLocationSearch(clearQuery: true) }
            }
        }
    }

    private func updatePinDrag(_ value: DragGesture.Value, using proxy: MapProxy) {
        let initial: PinDrag
        if let pinDrag { initial = pinDrag }
        else {
            guard let point = proxy.convert(draft.coordinate, to: .local) else { return }
            initial = PinDrag(originCoordinate: draft.coordinate, originPoint: point, translation: .zero, coordinate: draft.coordinate)
        }
        var updated = initial
        updated.translation = value.translation
        let point = CGPoint(x: initial.originPoint.x + value.translation.width, y: initial.originPoint.y + value.translation.height)
        if let coordinate = proxy.convert(point, from: .local) { updated.coordinate = coordinate }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { pinDrag = updated }
    }

    private func finishPinDrag(_ value: DragGesture.Value, using proxy: MapProxy) {
        guard let drag = pinDrag else { return }
        let point = CGPoint(x: drag.originPoint.x + value.translation.width, y: drag.originPoint.y + value.translation.height)
        let coordinate = proxy.convert(point, from: .local) ?? drag.coordinate
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            draft.coordinate = coordinate
            pinDrag = nil
        }
        if isChoosingLocation { finishLocationSearch(clearQuery: true) }
    }

    private func finishLocationSearch(clearQuery: Bool = false) {
        isSearchFocused = false
        isChoosingLocation = false
        isShowingDetails = true
        if clearQuery { search.clear() }
        else { search.clearResults() }
    }

    private func focusOnZone(in viewport: MapViewport) {
        guard pinDrag == nil, viewport.size.width > 0, viewport.size.height > 0 else { return }
        let coveredHeight: CGFloat
        if isChoosingLocation {
            coveredHeight = keyboardTop.map { max(0, viewport.globalMinY + viewport.size.height - $0) } ?? 0
        } else {
            coveredHeight = detailsHeight + viewport.bottomSafeArea
        }
        let visibleHeight = max(120, viewport.size.height - coveredHeight)
        let targetY = (visibleHeight + min(76, visibleHeight / 2)) / 2
        // Fit a north-up map rectangle that puts the zone above the sheet/keyboard.
        // Map pixels still extend to the bottom of the screen behind both surfaces.
        let point = MKMapPoint(draft.coordinate)
        let mapWidth = Double(viewport.size.width)
        let mapHeight = Double(viewport.size.height)
        let scale = 900 / (mapWidth * MKMetersPerMapPointAtLatitude(draft.coordinate.latitude))
        let width = mapWidth * scale
        let height = mapHeight * scale
        let centerY = point.y + (mapHeight / 2 - Double(targetY)) * scale
        camera = .rect(MKMapRect(x: point.x - width / 2, y: centerY - height / 2, width: width, height: height))
    }

    private struct PinDrag {
        let originCoordinate: CLLocationCoordinate2D
        let originPoint: CGPoint
        var translation: CGSize
        var coordinate: CLLocationCoordinate2D
    }

    nonisolated private struct MapViewport: Equatable {
        let size: CGSize
        let bottomSafeArea: CGFloat
        let globalMinY: CGFloat
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

    private func locationSearch(in viewport: MapViewport) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                searchField
                if isChoosingLocation {
                    Button("Cancel") { finishLocationSearch(clearQuery: true) }
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.primary)
                        .frame(minHeight: 44)
                }
            }

            if !search.results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(search.results) { result in
                            Button {
                                draft.coordinate = result.coordinate
                                if draft.name.isEmpty { draft.name = result.name }
                                search.select(result)
                                finishLocationSearch()
                                focusOnZone(in: viewport)
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
                .frame(maxHeight: 240)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            } else if let message = search.message {
                Text(message).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .padding(16).frame(maxWidth: .infinity)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var searchField: some View {
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
                    isChoosingLocation = true
                    isShowingDetails = false
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

#Preview("Zone editor · SE size", traits: .fixedLayout(width: 375, height: 667)) {
    NavigationStack { ZoneEditorView() }.tint(AppColors.primary)
}

#Preview("Zone editor · 17 Pro size", traits: .fixedLayout(width: 402, height: 874)) {
    NavigationStack { ZoneEditorView() }.tint(AppColors.primary).preferredColorScheme(.dark)
}
