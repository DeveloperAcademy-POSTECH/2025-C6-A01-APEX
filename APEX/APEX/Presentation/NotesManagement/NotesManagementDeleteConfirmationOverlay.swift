//
//  NotesManagementDeleteConfirmationOverlay.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementDeleteConfirmationOverlay: View {
    @Binding var isVisible: Bool
    @State private var isChecked: Bool = false
    let selectedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                    isChecked = false
                }
            
            // 삭제 확인 카드
            NotesManagementDeleteConfirmationCard(
                selectedCount: selectedCount,
                isChecked: $isChecked,
                onCancel: {
                    onCancel()
                    isChecked = false
                },
                onConfirm: {
                    guard isChecked else { return }
                    onConfirm()
                    isVisible = false
                    isChecked = false
                }
            )
            .padding(.horizontal, 46)
        }
    }
}

// MARK: - NotesManagementDeleteConfirmationCard

private struct NotesManagementDeleteConfirmationCard: View {
    let selectedCount: Int
    @Binding var isChecked: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
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
        .allowsHitTesting(true)
    }
    
    private var titleSection: some View {
        Text("\(selectedCount)개의 연락처 노트를\n영구적으로 삭제하겠습니까?")
            .font(.body1)
            .foregroundColor(Color("BlackLabel"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    private var bodySection: some View {
        Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    private var buttonsSection: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            cancelButton
            deleteButton
        }
    }
    
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
        Button(action: { if isChecked { onConfirm() } }) {
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
    }
}

#Preview {
    @State var isVisible = true
    
    return NotesManagementDeleteConfirmationOverlay(
        isVisible: $isVisible,
        selectedCount: 3,
        onConfirm: {},
        onCancel: {}
    )
}