import MapKit
import SwiftUI

enum StudyZoneCardStatus: String {
    case inactive = "Inactive", active = "Active", studying = "Studying"
    case checking = "Checking", paused = "Paused", unavailable = "Unavailable", notMonitored = "Not monitored"
}

struct ZoneCard: View {
    let zone: StudyZone
    var trackingStatus: StudyZoneCardStatus = .inactive
    var weeklySeconds: TimeInterval = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                nameAndStatus
                subjectChip
                Text("\(StudyTime.duration(weeklySeconds)) studied this week")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.text.opacity(0.05), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var nameAndStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                name
                Spacer(minLength: 0)
                status
            }
            VStack(alignment: .leading, spacing: 4) { name; status }
        }
    }

    private var name: some View {
        Text(zone.name).font(AppTypography.headline).foregroundStyle(AppColors.text)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var status: some View {
        Text(trackingStatus.rawValue).font(AppTypography.caption).foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch trackingStatus {
        case .active: AppColors.successText
        case .studying: AppColors.primary
        case .unavailable: AppColors.danger
        default: AppColors.secondary
        }
    }

    private var pinColor: Color {
        trackingStatus == .active ? AppColors.success : AppColors.primary
    }

    private var subjectChip: some View {
        Group {
            if let subject = zone.defaultSubject {
                HStack(spacing: 8) {
                    SubjectIconImage(icon: subject.subjectIcon, size: 16)
                    Text(subject.name).font(AppTypography.caption.weight(.semibold))
                }
                .foregroundStyle(AppColors.tagText)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(minHeight: 36)
                .background(subject.subjectColor.color, in: Capsule())
                if !subject.isActive { replacementHint }
            } else {
                replacementHint
            }
        }
    }

    private var replacementHint: some View {
        Text("Choose an active subject")
            .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
    }

    private var thumbnail: some View {
        let coordinate = CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude)
        let region = MKCoordinateRegion(center: coordinate,
            latitudinalMeters: max(600, zone.radiusMeters * 4), longitudinalMeters: max(600, zone.radiusMeters * 4))
        return Map(initialPosition: .region(region), interactionModes: []) {
            MapCircle(center: coordinate, radius: zone.radiusMeters)
                .foregroundStyle(pinColor.opacity(0.12))
            Annotation(zone.name, coordinate: coordinate) {
                zoneIcon
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 32, height: 32)
                    .background(pinColor, in: Circle())
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .frame(width: 76, height: dynamicTypeSize.isAccessibilitySize ? 100 : 84)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .id("\(zone.latitude),\(zone.longitude),\(zone.radiusMeters)")
    }

    @ViewBuilder private var zoneIcon: some View {
        if let icon = ZoneIcon(rawValue: zone.iconID), icon != .custom {
            Image(icon == .library ? "ZoneLibraryPin" : icon.assetName)
                .resizable().scaledToFit().frame(width: 20, height: 20)
        } else {
            Image(systemName: zone.iconID).font(.system(size: 20))
        }
    }
}
