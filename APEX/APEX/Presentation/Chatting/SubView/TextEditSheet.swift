import SwiftUI

struct TextEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    let onCopyAll: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let deleteSubject: String
    @State private var showDeleteAlert: Bool = false

    init(
        initialText: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onCopyAll: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        deleteSubject: String
    ) {
        _text = State(initialValue: initialText)
        self.onCancel = onCancel
        self.onSave = onSave
        self.onCopyAll = onCopyAll
        self.onShare = onShare
        self.onDelete = onDelete
        self.deleteSubject = deleteSubject
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.body6)
                    .padding(16)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button (action: {
                        onCancel()
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                    })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .principal) {
                    Text("메모 수정")
                }
            }
            .background(Color("Background"))
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 48) {
                    Button { onCopyAll() } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)

                    Button { onShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            .alert("\(deleteSubject) 삭제하겠습니까?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) { onDelete(); dismiss() }
                Button("취소", role: .cancel) { }
            }
        }
    }
}


