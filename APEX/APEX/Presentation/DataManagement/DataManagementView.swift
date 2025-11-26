//
//  DataManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI
import Combine

// MARK: - View (조립만)

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = DataManagementViewModel(
        sync: RealStorageSyncService(),
        usage: RealDataUsageService()
    )

    // 로컬 상태로 체크박스 관리 (NotesView 방식으로 통일)
    @State private var isDeleteConfirmed: Bool = false

    var body: some View {
        ZStack {
            // Main Content
            ScrollView {
                VStack(spacing: 0) {
                    // 상단 설정 섹션들
                    VStack(spacing: 0) {
                        DMToggleSection(
                            title: "iCloud 자동 동기화",
                            helper: "노트에 저장한 미디어는 iCloud에 자동으로 백업하고 기기에서는 삭제하여 스토리지 여유를 가질 수 있어요.",
                            isOn: $viewModel.isAutoSyncOn,
                            onToggle: { viewModel.send(.setAutoSync($0)) }
                        )

                        DMRefreshSection(
                            title: "iCloud 동기화 새로고침",
                            helperPrefix: "노트에 저장한 미디어를 iCloud에 즉시 동기화 합니다.",
                            lastSyncText: viewModel.lastSyncText,
                            isRefreshing: viewModel.isRefreshing,
                            onRefresh: { viewModel.send(.refresh) }
                        )
                    }
                    
                    Spacer().frame(height: 24)  // 상단 섹션과 구분선 사이 32pt

                    Rectangle()
                        .fill(Color("BackgroundSecondary"))
                        .frame(height: 2)

                    VStack(alignment: .leading, spacing: 0) {
                        DMMediaDataSection(
                            totalSizeText: viewModel.totalSizeText,
                            contacts: viewModel.contacts,
                            onDeleteAllTap: { viewModel.requestDeleteAll() },
                            onContactDeleteTap: { contact in
                                viewModel.requestDeleteContact(contact.id)
                            }
                        )
                    }
                }
                .padding(.all, 16)  // 전체 컨텐츠 패딩 16pt
            }
            .background(Color("Background"))
            .safeAreaInset(edge: .top) {
                DMTopBar { router.pop() }
            }

            DMConfirmDialog(
                isVisible: $viewModel.showingDialog,
                isChecked: $isDeleteConfirmed,
                title: viewModel.dialogKind?.title ?? "",
                bodyText: viewModel.dialogKind?.body ?? "",
                confirmTitle: "삭제",
                cancelTitle: "취소",
                onConfirm: {
                    guard isDeleteConfirmed else { return }
                    viewModel.send(.confirmDelete)
                    isDeleteConfirmed = false
                },
                onCancel: {
                    viewModel.send(.cancelDialog)
                    isDeleteConfirmed = false
                }
            )
        }
        .task { viewModel.send(.onAppear) }
        .background(Color("Background"))
    }
}

#Preview {
    DataManagementView()
}
