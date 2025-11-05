//
//  EditSheetDeleteConfirmation.swift
//  APEX
//
//  편집 시트용 삭제 확인 모달 컴포넌트
//

import SwiftUI

// MARK: - Edit Sheet Delete Confirmation Components

struct EditSheetOverlayLayer: View {
    @Binding var isVisible: Bool
    @Binding var isChecked: Bool
    var clientName: String
    var onConfirmDelete: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background (탭 시 닫기)
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                        isChecked = false
                    }
                }
            
            // Card
            EditSheetDeleteConfirmCard(
                isChecked: $isChecked,
                clientName: clientName,
                onCancel: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                        isChecked = false
                    }
                },
                onDelete: {
                    guard isChecked else { return }
                    onConfirmDelete()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                    }
                }
            )
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .zIndex(1)
            .accessibilityAddTraits(.isModal)
        }
    }
}

private struct EditSheetDeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var clientName: String
    var onCancel: () -> Void
    var onDelete: () -> Void
    
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
        
        // Button spec
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 133
        static let buttonCorner: CGFloat = 100
        static let buttonHPadding: CGFloat = 16
        static let buttonVPadding: CGFloat = 13
        
        // Confirm section spacing
        static let confirmCheckSpacing: CGFloat = 16
    }
    
    // 색상 스펙
    private let deleteActiveRed = Color(red: 0xCC/255.0, green: 0x41/255.0, blue: 0x41/255.0) // #CC4141
    private let deleteActiveBackground = Color(red: 1.0, green: 0xF6/255.0, blue: 0xF5/255.0) // #FFF6F5
    private let disabledGrayText = Color(red: 0.55, green: 0.55, blue: 0.55) // 기존 gray
    private let checkboxStroke = Color("BackgroundDisabled")
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            bodySection
            confirmCheckSection
            buttonsSection
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
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
    
    // MARK: Sections
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.titleTop)
            Text("'\(clientName)' 연락처를\n영구적으로 삭제하겠습니까?")
                .font(.body1)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.paddingH)
            Spacer().frame(height: Metrics.titleToBody)
        }
    }
    
    private var bodySection: some View {
        Text("연락처 정보와 관련된 모든 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.paddingH + 8)
            .padding(.bottom, Metrics.bodyToCheck)
    }
    
    private var confirmCheckSection: some View {
        Button {
            // 상태 토글은 버튼 액션에서만 애니메이션 처리
            withAnimation(.easeInOut(duration: 0.2)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: Metrics.confirmCheckSpacing) {
                checkboxView
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
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityLabel("내용 확인 동의")
        .accessibilityValue(isChecked ? "선택됨" : "선택 안됨")
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.checkToButtons)
            HStack(spacing: Metrics.buttonsSpacing) {
                cancelButton
                deleteButton
            }
            .padding(.horizontal, Metrics.paddingH)
            .padding(.bottom, Metrics.paddingV)
        }
    }
    
    // MARK: Components
    private var checkboxView: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Color("Primary") : Color.white)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isChecked ? Color("Primary") : checkboxStroke, lineWidth: 1)
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
        .contentShape(Circle())
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 10) {
                Text("취소")
                    .font(.title5)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Metrics.buttonHPadding)
            .padding(.vertical, Metrics.buttonVPadding)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var deleteButton: some View {
        Button(action: { if isChecked { onDelete() } }) {
            HStack(alignment: .center, spacing: 10) {
                Text("삭제")
                    .font(.title5)
                    .foregroundColor(isChecked ? deleteActiveRed : disabledGrayText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Metrics.buttonHPadding)
            .padding(.vertical, Metrics.buttonVPadding)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(isChecked ? deleteActiveBackground : Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isChecked)
        .accessibilityHint("확인 후 활성화됩니다.")
    }
}