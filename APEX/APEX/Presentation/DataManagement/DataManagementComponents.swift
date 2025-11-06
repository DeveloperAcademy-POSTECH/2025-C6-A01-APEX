import SwiftUI
import UIKit

// MARK: - Custom Button Style
struct PressableButtonStyle: ButtonStyle {
    let normalColor: Color
    let pressedColor: Color
    let cornerRadius: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedColor : normalColor)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Top Bar
struct DMTopBar: View {
    var onClose: () -> Void
    var title: String = "노트 저장공간 관리"

    private enum Metrics {
        static let height: CGFloat = 44
        static let hPadding: CGFloat = 12
        static let tappable: CGFloat = 44
        static let iconSize: CGFloat = 16
    }

    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(Font.custom("SF Pro", size: Metrics.iconSize).weight(.medium))
                        .foregroundColor(.black)
                        .frame(width: Metrics.tappable, height: Metrics.tappable)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                // 우측 공간 균형(좌측 버튼과 동일 폭 확보)
                Color.clear
                    .frame(width: Metrics.tappable, height: Metrics.tappable)
            }
            .frame(height: Metrics.height)
            .padding(.horizontal, Metrics.hPadding)
            .background(Color("Background"))

            // Centered title
            Text(title)
                .font(.title5)
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(height: Metrics.height)
                .padding(.horizontal, Metrics.hPadding)
                .allowsHitTesting(false)
                
        }
        .border(.red)
    }
    
}


// MARK: - Toggle Section
struct DMToggleSection: View {
    let title: String
    let helper: String
    @Binding var isOn: Bool
    var onToggle: (Bool) -> Void

    private enum Metrics {
        static let hPadding: CGFloat = 8
        static let vPadding: CGFloat = 10
        static let titleToHelperSpacing: CGFloat = 4
        static let helperToToggleSpacing: CGFloat = 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(title)
                .font(.body1)
                .foregroundColor(.primary)
            
            Spacer().frame(height: Metrics.titleToHelperSpacing)
            
            // Helper text와 Toggle을 나란히 배치
            HStack(alignment: .center, spacing: 0) {
                Text(helper)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 345, alignment: .leading)
                
                Spacer()
                
                Toggle("", isOn: Binding(get: { isOn }, set: { new in
                    isOn = new
                    onToggle(new)
                }))
                .toggleStyle(SwitchToggleStyle(tint: Color("Primary")))
                .labelsHidden()
            }
        }
        .padding(.horizontal, Metrics.hPadding)
        .padding(.vertical, Metrics.vPadding)
        .border(.red)
    }
}

// MARK: - Refresh Section
struct DMRefreshSection: View {
    let title: String
    let helperPrefix: String
    let lastSyncText: String
    let isRefreshing: Bool
    var onRefresh: () -> Void

    private enum Metrics {
        static let hPadding: CGFloat = 8
        static let vPadding: CGFloat = 10
        static let titleToHelperSpacing: CGFloat = 4
        static let helperToButtonSpacing: CGFloat = 10
        static let iconSize: CGFloat = 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(title)
                .font(.body1)
                .foregroundColor(.primary)
            
            Spacer().frame(height: Metrics.titleToHelperSpacing)
            
            // Helper text와 Refresh Button을 나란히 배치
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(helperPrefix)
                    Text("최종 동기화 시간: \(lastSyncText)")
                }
                .font(.caption2)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 345, alignment: .leading)
                
                Spacer()
                
                Button(action: { if !isRefreshing { onRefresh() } }) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.system(size: Metrics.iconSize, weight: .medium))
                        .foregroundColor(isRefreshing ? Color("BackgroundDisabled") : .gray)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
        }
        .padding(.horizontal, Metrics.hPadding)
        .padding(.vertical, Metrics.vPadding)
    }
}

// MARK: - Delete All Block
struct DMDeleteAllBlock: View {
    let totalSizeText: String
    var isEnabled: Bool = true
    var onTap: () -> Void

    private enum Metrics {
        static let hPadding: CGFloat = 8
        static let vPadding: CGFloat = 8
        static let height: CGFloat = 44
        static let corner: CGFloat = 10
        static let buttonToDescriptionSpacing: CGFloat = 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.buttonToDescriptionSpacing) {
            Button(action: { if isEnabled { onTap() } }) {
                Text("미디어 데이터 모두 삭제 (\(totalSizeText))")
                    .font(.body2)
                    .foregroundColor(isEnabled ? .primary : Color("BackgroundDisabled"))
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.height)
                    .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(
                normalColor: Color("BackgroundSecondary"),
                pressedColor: Color("BackgroundHover"),
                cornerRadius: Metrics.corner
            ))
            .disabled(!isEnabled)

            Text("미디어 데이터를 모두 삭제 시 i-Cloud에 백업되지 않는 데이터는 복원 할 수 없습니다.")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, Metrics.hPadding)
        .padding(.vertical, Metrics.vPadding)
    }
}

// MARK: - Contact List Section
struct DMContactListSection: View {
    let title: String = "연락처 노트 데이터 관리"
    let contacts: [DMContactUsage]
    var onContactDeleteTap: (DMContactUsage) -> Void

    private enum Metrics {
        static let titleHeight: CGFloat = 40
        static let titlePadding: CGFloat = 8
        static let titleToListSpacing: CGFloat = 4
        static let listVPadding: CGFloat = 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.titleToListSpacing) {
            // Title
            HStack {
                Text(title)
                    .font(.body1)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Metrics.titleHeight)
            .padding(.all, Metrics.titlePadding)
            
            // Contact List
            VStack(spacing: 0) {
                ForEach(contacts) { contact in
                    DMContactRow(contact: contact) {
                        onContactDeleteTap(contact)
                    }
                }
            }
            .padding(.vertical, Metrics.listVPadding)
        }
    }
}

// MARK: - Contact Row
struct DMContactRow: View {
    let contact: DMContactUsage
    var onDeleteTap: () -> Void

    private enum Metrics {
        static let rowHeight: CGFloat = 64
        static let sizeTextColor = Color.gray
    }

    var body: some View {
        Button(action: onDeleteTap) {
            HStack(spacing: 12) {
                Profile(image: contact.image, initials: contact.initials, size: .small, fontSize: 30.72)
                Text(contact.name)
                    .font(.body2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text(contact.sizeText)
                    .font(.body6)
                    .foregroundColor(Metrics.sizeTextColor)
            }
            .frame(height: Metrics.rowHeight)
            .frame(maxWidth: .infinity)
            .background(Color("BackgroundSecondary").opacity(0.0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confirm Dialog (overlay card)
struct DMConfirmDialog: View {
    @Binding var isVisible: Bool
    @Binding var isChecked: Bool
    let title: String
    let bodyText: String
    let confirmTitle: String
    let cancelTitle: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private enum Metrics {
        static let corner: CGFloat = 34
        static let paddingH: CGFloat = 14
        static let paddingV: CGFloat = 14
        static let titleTop: CGFloat = 8
        static let titleToBody: CGFloat = 10
        static let bodyToCheck: CGFloat = 10
        static let checkToButtons: CGFloat = 24
        static let buttonsSpacing: CGFloat = 16
        static let checkboxSize: CGFloat = 24
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 133
        static let buttonCorner: CGFloat = 100
        static let buttonHPadding: CGFloat = 16
        static let buttonVPadding: CGFloat = 13
        static let confirmCheckSpacing: CGFloat = 16
    }

    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { isVisible = false; onCancel() } }

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: Metrics.titleTop)
                            Text(title)
                                .font(.body1)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Metrics.paddingH)
                            Spacer().frame(height: Metrics.titleToBody)
                        }

                        Text(bodyText)
                            .font(.body3)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Metrics.paddingH + 8)
                            .padding(.bottom, Metrics.bodyToCheck)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isChecked.toggle() }
                        } label: {
                            HStack(spacing: Metrics.confirmCheckSpacing) {
                                ZStack {
                                    Circle()
                                        .fill(isChecked ? Color("Primary") : Color.white)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle().stroke(isChecked ? Color("Primary") : Color("BackgroundDisabled"), lineWidth: 1)
                                        )
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .opacity(isChecked ? 1 : 0)
                                }
                                .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)

                                Text("위 내용을 모두 확인했습니다.")
                                    .font(.body2)
                                    .foregroundColor(.black)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Metrics.paddingH + 8)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            Spacer().frame(height: Metrics.checkToButtons)
                            HStack(spacing: Metrics.buttonsSpacing) {
                                Button {
                                    withAnimation { isVisible = false }
                                    onCancel()
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(cancelTitle)
                                            .font(.title5)
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal, Metrics.buttonHPadding)
                                    .padding(.vertical, Metrics.buttonVPadding)
                                    .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight)
                                    .background(Color("BackgroundSecondary"))
                                    .cornerRadius(Metrics.buttonCorner)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    guard isChecked else { return }
                                    withAnimation { isVisible = false }
                                    onConfirm()
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(confirmTitle)
                                            .font(.title5)
                                            .foregroundColor(isChecked ? Color(red: 0xCC/255.0, green: 0x41/255.0, blue: 0x41/255.0) : Color(red: 0.55, green: 0.55, blue: 0.55))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal, Metrics.buttonHPadding)
                                    .padding(.vertical, Metrics.buttonVPadding)
                                    .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight)
                                    .background(isChecked ? Color(red: 1.0, green: 0xF6/255.0, blue: 0xF5/255.0) : Color("BackgroundSecondary"))
                                    .cornerRadius(Metrics.buttonCorner)
                                }
                                .buttonStyle(.plain)
                                .disabled(!isChecked)
                            }
                            .padding(.horizontal, Metrics.paddingH)
                            .padding(.bottom, Metrics.paddingV)
                        }
                    }
                    .padding(.top, Metrics.paddingV)
                    .background(
                        ZStack {
                            Color.clear.background(.ultraThinMaterial)
                            Color(.sRGB, red: 245/255, green: 245/255, blue: 245/255, opacity: 0.4)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .frame(maxWidth: 309)
                }
                .padding(.horizontal, 24)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Previews

#Preview("TopBar") {
    DMTopBar(onClose: {})
        .background(Color("Background"))
}

#Preview("ToggleSection") {
    @Previewable @State var on: Bool = false
    return DMToggleSection(
        title: "iCloud 자동 동기화",
        helper: "노트에 저장한 미디어를 i-Cloud에 자동으로 백업하고 기기에서는 삭제하여 스토리지 용량을 가볍게 쓸 수 있어요.",
        isOn: $on,
        onToggle: { _ in }
    )
    .background(Color("Background"))
}

#Preview("RefreshSection") {
    DMRefreshSection(
        title: "iCloud 동기화 새로고침",
        helperPrefix: "노트에 저장한 미디어를 i-cloud에 즉시 동기화 합니다.",
        lastSyncText: "2025년 10월 15일 오후 8:30",
        isRefreshing: false,
        onRefresh: {}
    )
    .background(Color("Background"))
}

#Preview("DeleteAllBlock - enabled") {
    DMDeleteAllBlock(totalSizeText: "5.70 GB", isEnabled: true, onTap: {})
        .background(Color("Background"))
        .padding(.vertical, 8)
}

#Preview("DeleteAllBlock - disabled") {
    DMDeleteAllBlock(totalSizeText: "5.70 GB", isEnabled: false, onTap: {})
        .background(Color("Background"))
        .padding(.vertical, 8)
}

#Preview("ContactRow") {
    let sample = DMContactUsage(id: UUID(), name: "Gyeong", initials: "G", sizeText: "816.45 MB", image: nil)
    return DMContactRow(contact: sample, onDeleteTap: {})
        .background(Color("Background"))
        .padding(.horizontal, 16)
}

#Preview("ContactListSection") {
    let samples = [
        DMContactUsage(id: UUID(), name: "Gyeong", initials: "G", sizeText: "816.45 MB", image: nil),
        DMContactUsage(id: UUID(), name: "Daisy", initials: "D", sizeText: "816.45 MB", image: nil)
    ]
    return DMContactListSection(contacts: samples, onContactDeleteTap: { _ in })
        .background(Color("Background"))
}

#Preview("ConfirmDialog (All delete)") {
    @Previewable @State var visible = true
    @Previewable @State var checked = false
    return DMConfirmDialog(
        isVisible: $visible,
        isChecked: $checked,
        title: "모든 미디어 데이터를 삭제하겠습니까?",
        bodyText: "모든 미디어 데이터를 삭제합니다.\ni-Cloud에 백업되지 않은 데이터는 복원 할 수 없습니다.",
        confirmTitle: "삭제",
        cancelTitle: "취소",
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("ConfirmDialog (Per-contact)") {
    @Previewable @State var visible = true
    @Previewable @State var checked = true
    return DMConfirmDialog(
        isVisible: $visible,
        isChecked: $checked,
        title: "해당 연락처 노트의\n미디어 데이터를 모두 삭제하겠습니까?",
        bodyText: "노트를 제외한 모든 미디어 데이터\n(사진, 동영상, 음성, 파일)이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.",
        confirmTitle: "삭제",
        cancelTitle: "취소",
        onConfirm: {},
        onCancel: {}
    )
}
