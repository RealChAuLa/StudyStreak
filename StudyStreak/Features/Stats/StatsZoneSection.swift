import SwiftUI

struct StatsZoneSection: View {
    let totals: [StatsZoneTotal]
    let savedZones: [StudyZone]
    let onEdit: (StudyZone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By zone").font(AppTypography.title2).foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            if totals.isEmpty {
                Text("Study in a saved zone to see where your time adds up.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .studySessionCard()
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(totals) { total in
                            if let saved = savedZones.first(where: { $0.id == total.zoneID }) {
                                Button { onEdit(saved) } label: { card(total, saved: saved) }
                                    .buttonStyle(.plain).accessibilityHint("Edit study zone")
                            } else {
                                card(total, saved: nil)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private func card(_ total: StatsZoneTotal, saved: StudyZone?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            icon(for: saved, hasZone: total.zoneID != nil)
                .foregroundStyle(AppColors.primary).accessibilityHidden(true)
            Text(saved?.name ?? total.name).font(AppTypography.subheadline.weight(.medium))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(StudyTime.duration(total.seconds)).font(AppTypography.title2)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 130, alignment: .leading)
        .studySessionCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func icon(for zone: StudyZone?, hasZone: Bool) -> some View {
        if let zone, let icon = ZoneIcon(rawValue: zone.iconID), icon != .custom {
            Image(icon.assetName).resizable().scaledToFit().frame(width: 20, height: 20)
        } else {
            Image(systemName: zone?.iconID ?? (hasZone ? "mappin.circle" : "location.slash"))
                .font(.system(size: 20)).frame(width: 20, height: 20)
        }
    }
}
