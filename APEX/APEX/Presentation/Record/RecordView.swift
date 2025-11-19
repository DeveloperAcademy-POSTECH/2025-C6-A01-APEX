//
//  RecordView.swift
//  APEX
//
//  Created by 조운경 on 10/30/25.
//

import SwiftUI
import AVFoundation
import Speech

struct RecordView: View {
    @StateObject private var viewModel: RecordViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isKeyboardShown: Bool = false

    init(audioURL: URL?) {
        _viewModel = StateObject(wrappedValue: RecordViewModel(audioURL: audioURL))
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {

                // Square audio tile (ChattingView UI, larger for editor)
                Group {
                    if let url = viewModel.workingURL ?? viewModel.originalURL {
                        AudioSquareTile(
                            url: url,
                            duration: viewModel.resolveDuration(for: url),
                            preferredLength: 173.6,
                            titleOverride: viewModel.filenameText
                        )
                        .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color("BackgroundSecondary"))
                            .frame(width: 173.6, height: 173.6)
                    }
                }
                .padding(.vertical, 24)

                // Play/Pause button
                Button(action: { viewModel.send(.togglePlay) }, label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color("Primary"))
                        .clipShape(Circle())
                })
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 32)

                // Playback bar (reused)
                MediaPlaybackBar(
                    current: $viewModel.currentTime,
                    total: $viewModel.totalTime,
                    volume: Binding(
                        get: { viewModel.volume },
                        set: { newVal in viewModel.setVolume(newVal) }
                    ),
                    onScrub: { newSeconds in
                        viewModel.send(.onScrub(newSeconds))
                    },
                    onScrubBegan: { viewModel.send(.onScrubBegan) },
                    onScrubEnded: { viewModel.send(.onScrubEnded) },
                    timeColor: .gray,
                    trackColor: Color.gray.opacity(0.25)
                )
                .padding(.bottom, 8)

                // Filename editor
                APEXTextField(
                    kind: .singleLine,
                    label: "파일 이름",
                    placeholder: "파일 이름 입력",
                    text: $viewModel.filenameText,
                    state: .normal(helper: nil),
                    isRequired: false,
                    isDisabled: false,
                    showsClearButton: true
                )
                .id("filenameField")
                .padding(.top, 42)
                .padding(.bottom, 16)
                APEXTextField(
                    style: .editor,
                    label: "음성녹음 기록",
                    placeholder: "주요 대화",
                    text: $viewModel.conversation,
                    isRequired: false
                )
                    .frame(height: 165)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 24)
        }
        // Allow programmatic scrolling only when keyboard is shown
        .scrollDisabled(!isKeyboardShown)
        .background(Color("Background"))
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaBar(edge: .top) {
            APEXRecordTopBar(
                onClose: { dismiss() },
                onDone: { viewModel.send(.save); dismiss() }
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer() // 전체 높이 채운 뒤 아래로 밀기
                    HStack(spacing: 48) {
                        Button(action: { viewModel.send(.save) }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.send(.tapShare) }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.send(.tapDelete) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.bottom, proxy.safeAreaInsets.bottom) // 홈 인디케이터 보정
                    .background(Color("Background"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 전체 영역 채우기
            }
            .ignoresSafeArea(.keyboard, edges: .bottom) // 키보드 올라와도 고정
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.workingURL ?? viewModel.originalURL {
                ShareView(initialAttachments: [ShareAttachmentItem(id: UUID(), kind: .audio(url))])
            } else {
                ShareView()
            }
        }
        .alert("음성 녹음을 삭제할까요?", isPresented: $viewModel.showDeleteAlert) {
            Button("삭제", role: .destructive) {
                viewModel.send(.confirmDelete)
                dismiss()
            }
            Button("취소", role: .cancel) { }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.apexDismissKeyboard()
            }
        )
        .onAppear {
            viewModel.send(.onAppear)
        }
        .onDisappear { viewModel.send(.onDisappear) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardShown = true
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("filenameField", anchor: .bottom)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
            if isKeyboardShown {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("filenameField", anchor: .bottom)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardShown = false
        }
        }
    }
}

#Preview {
    RecordView(audioURL: nil)
}
