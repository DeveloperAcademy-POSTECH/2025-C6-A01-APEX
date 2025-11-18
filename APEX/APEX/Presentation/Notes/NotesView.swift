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
    
    // 로컬 상태로 체크박스 관리 (windowOverlay 바인딩 문제 해결)
    @State private var isDeleteConfirmed: Bool = false
    
    var body: some View {
        mainContent
            .windowOverlay(isPresented: $viewModel.showDeleteDialog) {
                deleteOverlay
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
                onDelete: { 
                    isDeleteConfirmed = false // 리셋
                    viewModel.send(.showDelete($0)) 
                },
                onTapRow: { router.push(.chat($0.id)) }
            )
        }
        .background(Color("Background"))
    }
    
    private var deleteOverlay: some View {
        ZStack {
            // 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    isDeleteConfirmed = false
                    viewModel.send(.dismissDelete)
                }
            
            // 삭제 확인 카드 (로컬 상태 사용)
            DeleteConfirmCard(
                isChecked: $isDeleteConfirmed,
                onCancel: {
                    isDeleteConfirmed = false
                    viewModel.send(.dismissDelete)
                },
                onDelete: {
                    guard isDeleteConfirmed, let target = viewModel.clientToDelete else { return }
                    viewModel.send(.deleteConfirmed(target))
                    isDeleteConfirmed = false
                }
            )
            .padding(.horizontal, 46) // 통일된 패딩
            .contentShape(Rectangle()) // 모달 카드 영역의 터치를 차단
            .onTapGesture { } // 빈 제스처로 터치 이벤트 흡수
        }
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

// MARK: - Delete Confirmation Components

private struct DeleteConfirmCard: View {
    @Binding var isChecked: Bool
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
        Text("해당 연락처 노트를\n영구적으로 삭제하겠습니까?")
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
        .padding(.horizontal, 8) // 본문과 시작점 맞추기 위해 동일한 패딩
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

#Preview {
    NotesView()
}
