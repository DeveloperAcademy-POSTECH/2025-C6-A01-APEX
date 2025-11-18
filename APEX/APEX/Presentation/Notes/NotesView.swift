//
//  NotesView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @ObservedObject private var clientsStore = ClientsStore.shared
    @StateObject private var viewModel = NotesViewModel()
    
    var body: some View {
        ZStack {
            mainContent
            if viewModel.showDeleteDialog {
                deleteOverlay
            }
        }
        .apexToast(
            isPresented: $viewModel.showToast,
            image: Image(systemName: "pin"),
            text: viewModel.toastText,
            buttonTitle: "되돌리기",
            duration: 1.6,
            onButtonTap: { viewModel.send(.undoPin) }
        )
        
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) {
            NotesNavigationBar { print("Notes menu tapped") }
                .background(Color("Background"))
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            NotesFilterTabs(
                selectedFilter: $viewModel.selectedFilter,
                availableFilters: viewModel.availableFilters
            )
            
            NotesListView(
                clients: $clientsStore.clients,
                selectedFilter: $viewModel.selectedFilter,
                onTogglePin: { viewModel.send(.togglePin($0)) },
                onDelete: { viewModel.send(.showDelete($0)) },
                onTapRow: { router.push(.chat($0.id)) }
            )
        }
        .background(Color("Background"))
    }
    
    private var deleteOverlay: some View {
        OverlayLayer(
            isVisible: $viewModel.showDeleteDialog,
            isChecked: $viewModel.isDeleteConfirmed,
            clientToDelete: $viewModel.clientToDelete,
            onConfirmDelete: { viewModel.send(.deleteConfirmed($0)) }
        )
    }
    
    // MARK: - Navigation
    
    @ViewBuilder
    private func chattingDestination(for clientId: UUID) -> some View {
        // TODO: Replace with actual chatting view
        // For now, we'll show a placeholder or you can replace this with your actual chatting view
        Text("Chat for client: \(clientId.uuidString)")
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
    }
    
}

// MARK: - Overlay Layer (dimmed bg + card)

private struct OverlayLayer: View {
    @Binding var isVisible: Bool
    @Binding var isChecked: Bool
    @Binding var clientToDelete: Client?
    var onConfirmDelete: (Client) -> Void
    
    var body: some View {
        ZStack {
            // 전체화면 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    isVisible = false
                    clientToDelete = nil
                    isChecked = false
                }
            
            // 삭제 확인 카드
            DeleteConfirmCard(
                isChecked: $isChecked,
                onCancel: {
                    isVisible = false
                    clientToDelete = nil
                    isChecked = false
                },
                onDelete: {
                    guard isChecked, let target = clientToDelete else { return }
                    onConfirmDelete(target)
                    isVisible = false
                }
            )
            .padding(.horizontal, 46)
        }
    }
}

// MARK: - DeleteConfirmCard

private struct DeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    
    private enum Metrics {
        static let corner: CGFloat = 24
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
    private let deleteActiveRed = Color("Error")
    private let deleteActiveBackground = Color("ErrorHover")
    private let disabledGrayText = Color("GrayLabel")
    private let checkboxStroke = Color("BackgroundDisabled")
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            bodySection
            confirmCheckSection
            buttonsSection
        }
        .padding(.top, Metrics.paddingV)
        .glassEffect(in: .rect(cornerRadius: 28.0))
        .allowsHitTesting(true)
    }
    
    // MARK: Sections
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.titleTop)
            Text("해당 연락처 노트를\n영구적으로 삭제하겠습니까?")
                .font(.body1)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.paddingH)
            Spacer().frame(height: Metrics.titleToBody)
        }
    }
    
    private var bodySection: some View {
        Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
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
            print(isChecked)
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
                    .foregroundColor(Color("BlackLabel"))
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

#Preview {
    NotesView()
}
