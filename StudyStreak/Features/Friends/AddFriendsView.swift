import SwiftUI

struct AddFriendsView: View {
    let username: String
    @State private var model: AddFriendsModel
    @State private var retryCount = 0
    @State private var searchRetry = 0
    @State private var unfriendTarget: UnfriendTarget?

    init(userID: String, username: String) {
        self.username = username
        _model = State(initialValue: AddFriendsModel(userID: userID))
    }

    private var canAct: Bool { model.isReady && !model.isLoadingRequests && model.requestError == nil }

    var body: some View {
        List {
            Section {
                UsernameShareCard(username: username)
                    .friendCardRow()
            }
            Section {
                searchField
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if let error = model.directoryError {
                Section {
                    retryMessage(error) { retryCount += 1 }.friendCardRow()
                }
            }
            searchSection
            pendingSections
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .contentMargins(.top, 16, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Add friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Add friends").font(AppTypography.headline).foregroundStyle(AppColors.text)
            }
        }
        .task(id: retryCount) {
            await model.start()
            await model.search()
        }
        .task(id: "\(model.query)|\(searchRetry)") { await model.search() }
        .onDisappear { model.stop() }
        .confirmationDialog("Remove friend?", isPresented: Binding(
            get: { unfriendTarget != nil }, set: { if !$0 { unfriendTarget = nil } }
        ), titleVisibility: .visible, presenting: unfriendTarget) { target in
            Button("Unfriend", role: .destructive) {
                unfriendTarget = nil
                Task {
                    await model.perform(.unfriend, otherID: target.profile.id,
                                        expectedConnection: target.connection)
                }
            }
            .disabled(!canAct)
            Button("Cancel", role: .cancel) { unfriendTarget = nil }
        } message: { target in
            Text("Remove @\(target.profile.username) from your friends? You can send another request later.")
        }
        .alert("Couldn’t update friends", isPresented: Binding(
            get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(model.actionError ?? "Please try again.") }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image("FriendSearch").resizable().scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
            TextField("Search by username", text: $model.query,
                      prompt: Text("Search by username").foregroundStyle(AppColors.secondary))
                .font(AppTypography.body).foregroundStyle(AppColors.text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.asciiCapable).submitLabel(.search)
                .onSubmit { searchRetry += 1 }
                .accessibilityLabel("Search by username")
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16).padding(.trailing, model.query.isEmpty ? 16 : 4)
        .padding(.vertical, model.query.isEmpty ? 12 : 2)
        .frame(minHeight: 48)
        .background(AppColors.border, in: RoundedRectangle(cornerRadius: 12))
    }

    private var searchSection: some View {
        Section {
            if model.isSearching {
                ProgressView("Searching…").tint(AppColors.primary)
                    .font(AppTypography.subheadline).friendCardRow()
            } else if let error = model.searchError {
                retryMessage(error) { searchRetry += 1 }.friendCardRow()
            } else if model.hasSearched && model.results.isEmpty {
                Text("No matching usernames. Check the spelling or ask your friend to share their username.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .friendCardRow()
            } else if !model.results.isEmpty {
                ForEach(model.results) { profile in
                    searchResult(profile)
                        .listRowInsets(EdgeInsets(
                            top: profile.id == model.results.first?.id ? 24 : 8, leading: 16,
                            bottom: profile.id == model.results.last?.id ? 24 : 8, trailing: 16))
                        .listRowBackground(AppColors.surface)
                        .listRowSeparatorTint(AppColors.border)
                }
            } else {
                Text(model.query.isEmpty
                     ? "Enter at least 2 characters of a username to find your study circle."
                     : "Use 2–20 letters, numbers, dots or underscores. You can include @ at the beginning.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
        } header: {
            if model.isSearching || model.hasSearched || model.searchError != nil {
                sectionHeading("Search results")
            }
        }
    }

    @ViewBuilder private var pendingSections: some View {
        Section {
            if let error = model.requestError {
                retryMessage(error) { retryCount += 1 }.friendCardRow()
            } else if model.isLoadingRequests {
                ProgressView("Loading requests…").tint(AppColors.primary)
                    .font(AppTypography.subheadline).friendCardRow()
            } else if model.incoming.isEmpty && model.outgoing.isEmpty {
                Text("No pending requests. Your study circle starts with one hello.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .friendCardRow()
            }
        } header: { sectionHeading("Pending requests") }

        if !model.failedProfileIDs.isEmpty {
            Section {
                retryMessage("Some profiles couldn’t load. Please try again.") { retryCount += 1 }
                    .friendCardRow()
            }
        }

        ForEach(model.incoming + model.outgoing) { connection in
            let otherID = connection.otherUserID(for: model.userID)
            Section {
                FriendRequestCard(profile: model.profiles[otherID],
                                  incoming: connection.recipientID == model.userID,
                                  profileUnavailable: model.failedProfileIDs.contains(otherID),
                                  busy: model.busyUserIDs.contains(otherID), enabled: canAct) { action in
                    Task { await model.perform(action, otherID: otherID) }
                }
                .friendCardRow()
            }
        }
    }

    private func searchResult(_ profile: FriendProfile) -> some View {
        HStack(spacing: 12) {
            ProfileAvatar(initial: profile.initial, photoData: profile.photoData, size: 40)
            Text(profile.username)
                .font(AppTypography.subheadline.weight(.medium)).foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            resultAction(profile)
        }
    }

    @ViewBuilder private func resultAction(_ profile: FriendProfile) -> some View {
        if model.busyUserIDs.contains(profile.id) {
            ProgressView().tint(AppColors.primary).frame(width: 84, height: 44)
        } else if let connection = model.connection(with: profile.id) {
            if connection.status == .accepted {
                unfriendButton(profile, connection: connection)
            } else if connection.senderID == model.userID {
                resultBadge("Requested")
            } else {
                resultButton("Accept", profile: profile, action: .accept)
            }
        } else {
            resultButton("Add", profile: profile, action: .send)
        }
    }

    private func unfriendButton(_ profile: FriendProfile, connection: FriendConnection) -> some View {
        Button(role: .destructive) {
            unfriendTarget = UnfriendTarget(profile: profile, connection: connection)
        } label: {
            Text("Unfriend").font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.danger)
                .frame(minWidth: 84, minHeight: 44)
                .background(AppColors.warm, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).disabled(!canAct)
        .accessibilityLabel("Unfriend \(profile.username)")
    }

    private struct UnfriendTarget {
        let profile: FriendProfile
        let connection: FriendConnection
    }

    private func resultButton(_ title: String, profile: FriendProfile, action: FriendAction) -> some View {
        Button { Task { await model.perform(action, otherID: profile.id) } } label: {
            Text(title).font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.primary)
                .frame(minWidth: 84, minHeight: 44)
                .background(AppColors.tint, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).disabled(!canAct)
        .accessibilityLabel("\(title) \(profile.username)")
    }

    private func resultBadge(_ title: String) -> some View {
        Text(title).font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.secondary)
            .frame(minWidth: 84, minHeight: 44)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title).font(AppTypography.title2).foregroundStyle(AppColors.text)
            .textCase(nil).padding(.bottom, 8).accessibilityAddTraits(.isHeader)
    }

    private func retryMessage(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            Button("Try again", action: retry)
                .font(AppTypography.subheadline.weight(.medium))
                .foregroundStyle(AppColors.primary).frame(minHeight: 44).buttonStyle(.plain)
        }
    }
}

private extension View {
    func friendCardRow() -> some View {
        listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface)
                .shadow(color: AppColors.text.opacity(0.04), radius: 8, x: 0, y: 4))
    }
}
