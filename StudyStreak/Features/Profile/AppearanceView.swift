import SwiftUI

struct AppearanceView: View {
    let displayName: String
    @AppStorage(AppAppearance.storageKey) private var preference = AppAppearance.system.rawValue

    private var selection: AppAppearance { AppAppearance(rawValue: preference) ?? .system }

    var body: some View {
        List {
            Section {
                introduction
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(AppAppearance.allCases) { appearance in
                    appearanceRow(appearance)
                        .listRowBackground(AppColors.surface)
                        .listRowSeparatorTint(AppColors.border)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make it feel like your space.")
                .font(AppTypography.title2)
                .foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            Text("Choose a theme or follow your device.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondary)
            HStack(spacing: 16) {
                previewButton(.light)
                previewButton(.dark)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func previewButton(_ appearance: AppAppearance) -> some View {
        Button { preference = appearance.rawValue } label: {
            ThemePreview(displayName: displayName)
                .environment(\.colorScheme, appearance == .dark ? .dark : .light)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(appearance.title) appearance")
    }

    private func appearanceRow(_ appearance: AppAppearance) -> some View {
        Button { preference = appearance.rawValue } label: {
            HStack(spacing: 12) {
                Image(appearance.assetName)
                    .resizable().scaledToFit().frame(width: 24, height: 24)
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appearance.title).font(AppTypography.body.weight(.medium)).foregroundStyle(AppColors.text)
                    Text(appearance.subtitle).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selection == appearance {
                    Image("AppearanceCheck")
                        .resizable().scaledToFit().frame(width: 20, height: 20)
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 48)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == appearance ? .isSelected : [])
    }
}

private struct ThemePreview: View {
    let displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(AppColors.text)
                .frame(width: 62, height: 13)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            Text(displayName)
                .font(AppTypography.title2.weight(.bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 22)
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .frame(height: 61)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6).fill(AppColors.primary)
                        .frame(height: 19).padding(.horizontal, 11).padding(.bottom, 12)
                }
                .padding(.top, 9)
            RoundedRectangle(cornerRadius: 9).fill(AppColors.surface)
                .frame(height: 31).padding(.top, 12)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 208)
        .background(AppColors.background, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityHidden(true)
    }
}

#Preview("31 · Appearance") {
    NavigationStack { AppearanceView(displayName: "Devinda") }
        .tint(AppColors.primary)
}
