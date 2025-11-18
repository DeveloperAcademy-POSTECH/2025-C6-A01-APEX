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
            .padding(.horizontal, 46)
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
        // 통일된 값들
        static let cornerRadius: CGFloat = 32
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        
        // 간격들
        static let titleTop: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        static let checkboxToButtonSpacing: CGFloat = 24  // 체크박스와 버튼 사이
        static let buttonSpacing: CGFloat = 16
        
        // 체크박스
        static let checkboxSize: CGFloat = 24
        static let confirmSpacing: CGFloat = 16
        
        // 버튼
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 120
        static let buttonCorner: CGFloat = 100
    }
    
    // 색상 스펙
    private let deleteActiveRed = Color("Error")
    private let deleteActiveBackground = Color("ErrorHover")
    private let disabledGrayText = Color("GrayLabel")
    private let checkboxStroke = Color("BackgroundDisabled")
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            bodySection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            confirmSection
            
            Spacer()
                .frame(height: Metrics.checkboxToButtonSpacing)
            
            buttonsSection
        }
        .padding(Metrics.horizontalPadding)
        .glassEffect(in: .rect(cornerRadius: Metrics.cornerRadius))
    }
    
    // MARK: - Sections
    
    private var titleSection: some View {
        Text("'\(clientName)' 연락처를\n영구적으로 삭제하겠습니까?")
            .font(.body1)
            .foregroundColor(Color("BlackLabel"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    private var bodySection: some View {
        Text("연락처 정보와 관련된 모든 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }
    
    private var confirmSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: Metrics.confirmSpacing) {
                checkboxView
                Text("위 내용을 모두 확인했습니다.")
                    .font(.body2)
                    .foregroundColor(.black)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private var buttonsSection: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            cancelButton
            deleteButton
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
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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