//
//  DataManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var autoSync = false
    @State private var lastSyncText = "2025년 10월 15일 오후 8:30"
    @State private var confirmAllDelete = false
    @State private var confirmAllChecked = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 16) {
                    sectionToggle(title: "iCloud 자동 동기화", isOn: $autoSync, helper: "노트에 저장한 미디어는 iCloud에 자동으로 백업하고 기기에서는 삭제하여 스토리지 여유를 가질 수 있어요.")

                    sectionRowWithRefresh(
                        title: "iCloud 동기화 새로고침",
                        helper: "노트에 저장한 미디어를 iCloud에 즉시 동기화 합니다.\n최종 동기화 시간: \(lastSyncText)"
                    ) {
                        // 더미
                    }

                    allDeleteBlock

                    Divider().padding(.horizontal, 16)

                    Text("연락처 노트 데이터 관리")
                        .font(.body4)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    // 더미 리스트
                    VStack(spacing: 8) {
                        contactRow(name: "Gyeong", size: "816.45MB")
                        contactRow(name: "Daisy", size: "816.45MB")
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color("Background"))
        }
        .confirmationDialog(
            "모든 미디어 데이터를 삭제하겠습니까?",
            isPresented: $confirmAllDelete,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { /* 더미 */ }
            Button("취소", role: .cancel) { }
        } message: {
            Text("모든 미디어 데이터를 삭제합니다.\nI-Cloud에 백업되지 않은 데이터는 복원 할 수 없습니다.\n\n\(confirmAllChecked ? "✔︎ " : "○ ") 위 내용을 모두 확인했습니다.")
        }
        .background(Color("Background"))
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title4)
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("노트 저장공간 관리")
                .font(.title3)
                .foregroundColor(.black)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Color("Background"))
    }

    private func sectionToggle(title: String, isOn: Binding<Bool>, helper: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color("Primary")))
                .font(.body2)
            Text(helper)
                .font(.body6)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
    }

    private func sectionRowWithRefresh(title: String, helper: String, onRefresh: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body2)
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            Text(helper)
                .font(.body6)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
    }

    private var allDeleteBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                confirmAllDelete = true
            } label: {
                Text("미디어 데이터 모두 삭제 (5.70 GB)")
                    .font(.body2)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Text("미디어 데이터를 모두 삭제 시 I-Cloud에 백업되지 않는 데이터는 복원 할 수 없습니다.")
                .font(.body6)
                .foregroundColor(.gray)

            // 확인 체크(간단 토글)
            HStack {
                Button {
                    confirmAllChecked.toggle()
                } label: {
                    Image(systemName: confirmAllChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(confirmAllChecked ? Color("Primary") : .gray)
                }
                .buttonStyle(.plain)
                Text("위 내용을 모두 확인했습니다.")
                    .font(.body5)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func contactRow(name: String, size: String) -> some View {
        HStack {
            InitialAvatar(letter: String(name.prefix(1)), size: 36, fontSize: 18)
            Text(name)
                .font(.body2)
            Spacer()
            Text(size)
                .font(.body5)
                .foregroundColor(.gray)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color("BackgroundSecondary").opacity(0.0))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    DataManagementView()
}
