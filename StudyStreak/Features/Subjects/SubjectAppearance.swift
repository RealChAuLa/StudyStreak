import SwiftUI

enum SubjectColor: String, CaseIterable, Identifiable {
    case blue, purple, teal, pink, green, orange, yellow, red
    case mint, sky, periwinkle, lavender, rose, peach, sage, sand

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .blue: AppColors.Subject.blue
        case .purple: AppColors.Subject.purple
        case .teal: AppColors.Subject.teal
        case .pink: AppColors.Subject.pink
        case .green: AppColors.Subject.green
        case .orange: AppColors.Subject.orange
        case .yellow: AppColors.Subject.yellow
        case .red: AppColors.Subject.red
        default: Color("Subject\(title)")
        }
    }
}

enum SubjectIcon: String, CaseIterable, Identifiable {
    case book, pen, atom, code, leaf, sparkles, building, chart
    case flask, globe, music, palette, microscope

    var id: String { rawValue }
    var title: String {
        switch self {
        case .code: "Computer science"
        case .chart: "Economics"
        default: rawValue.capitalized
        }
    }
    var assetName: String { "Subject\(rawValue.capitalized)" }
    var rowAssetName: String {
        switch self {
        case .book, .atom, .code, .leaf: "\(assetName)Row"
        default: assetName
        }
    }
}

extension StudySubject {
    var subjectColor: SubjectColor { SubjectColor(rawValue: colorID) ?? .blue }
    var subjectIcon: SubjectIcon { SubjectIcon(rawValue: iconID) ?? .book }
}

struct SubjectIconImage: View {
    let icon: SubjectIcon
    var size: CGFloat = 24
    var isListRow = false

    var body: some View {
        Image(isListRow ? icon.rowAssetName : icon.assetName)
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
