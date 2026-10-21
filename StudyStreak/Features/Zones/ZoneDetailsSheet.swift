import SwiftUI

struct ZoneDetailsSheet: View {
    @Binding var draft: ZoneEditorDraft
    let onSave: () -> Void
    @State private var isShowingCustomIcons = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                radiusControl
                VStack(spacing: 12) {
                    nameField
                    iconPicker
                    subjectPicker
                }
                PrimaryButton(title: "Save Zone") {
                    isNameFocused = false
                    onSave()
                }
                .disabled(!draft.canSave)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNameFocused = false }
            }
        }
        .sheet(isPresented: $isShowingCustomIcons) {
            CustomZoneIconPicker(selection: draft.customSymbol) { symbol in
                draft.customSymbol = symbol
                draft.icon = .custom
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var radiusControl: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Geofence radius").foregroundStyle(AppColors.text)
                Spacer()
                Text("\(Int(draft.radius)) m")
                    .foregroundStyle(AppColors.primary)
                    .monospacedDigit()
            }
            .font(AppTypography.headline)
            .padding(.bottom, 4)

            Slider(value: $draft.radius, in: 100...500, step: 10)
                .tint(AppColors.primary)
                .frame(minHeight: 44)
                .accessibilityLabel("Geofence radius")
                .accessibilityValue("\(Int(draft.radius)) meters")

            HStack {
                Text("100 m minimum")
                Spacer()
                Text("500 m")
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondary)
            .accessibilityHidden(true)
        }
    }

    private var nameField: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text("Zone name")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 100, alignment: .leading)
                zoneNameInput
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Zone name").font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                zoneNameInput
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var zoneNameInput: some View {
        TextField("Campus Library", text: $draft.name)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.text)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($isNameFocused)
            .onSubmit { isNameFocused = false }
            .accessibilityLabel("Zone name")
    }

    private var iconPicker: some View {
        HStack(spacing: 8) {
            Text("Icon")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
                .frame(minWidth: 56, alignment: .leading)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ZoneIcon.allCases) { icon in
                        Button {
                            if icon == .custom { isShowingCustomIcons = true }
                            else { draft.icon = icon }
                        } label: {
                            Group {
                                if icon == .custom && draft.icon == .custom {
                                    Image(systemName: draft.customSymbol).font(.title3)
                                } else {
                                    Image(icon.assetName).resizable().scaledToFit().frame(width: 23, height: 23)
                                }
                            }
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 48, height: 44)
                            .background(draft.icon == icon ? AppColors.tint : AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(icon.title)
                        .accessibilityAddTraits(draft.icon == icon ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var subjectPicker: some View {
        Menu {
            Picker("Default Subject", selection: $draft.subject) {
                ForEach(ZoneSubjectOption.allCases) { subject in
                    Text(subject.rawValue).tag(subject)
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    subjectLabel
                    Spacer(minLength: 8)
                    subjectChip
                    downIcon
                }
                VStack(alignment: .leading, spacing: 8) {
                    subjectLabel
                    HStack { subjectChip; Spacer(); downIcon }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Default Subject")
        .accessibilityValue(draft.subject.rawValue)
    }

    private var subjectLabel: some View {
        Text("Default Subject").font(AppTypography.subheadline).foregroundStyle(AppColors.secondary).fixedSize()
    }

    private var subjectChip: some View {
        HStack(spacing: 8) {
            Image("ZoneSubject").resizable().scaledToFit().frame(width: 16, height: 16)
            Text(draft.subject.rawValue).font(AppTypography.caption.weight(.semibold))
        }
        .foregroundStyle(AppColors.tagText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 36)
        .background(draft.subject.color, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private var downIcon: some View {
        Image("ZoneChevron").resizable().scaledToFit().frame(width: 16, height: 16)
            .foregroundStyle(AppColors.secondary)
    }
}

private struct CustomZoneIconPicker: View {
    let selection: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let symbols = [
        ("book", "Book"), ("graduationcap", "Graduation cap"),
        ("laptopcomputer", "Laptop"), ("house", "Home"),
        ("pencil", "Pencil"), ("mappin", "Map pin")
    ]

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(symbols, id: \.0) { symbol, title in
                    Button {
                        onSelect(symbol)
                        dismiss()
                    } label: {
                        Image(systemName: symbol)
                            .font(.title2)
                            .foregroundStyle(AppColors.primary)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(symbol == selection ? AppColors.tint : AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                    .accessibilityAddTraits(symbol == selection ? .isSelected : [])
                }
            }
            .padding(24)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Choose an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
    }
}
