//
//  PhotoAddView.swift
//  APEX
//
//  Created by 조운경 on 10/21/25.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct PhotoAddView: View {
    enum PhotoType: Identifiable {
        case profile, card
        var id: String { self == .profile ? "profile" : "card" }
    }
    let type: PhotoType
    let onCroppedProfile: ((UIImage) -> Void)?
    let onCroppedCard: ((UIImage, Bool) -> Void)?
    @Environment(\.dismiss) private var dismiss
    private var isProfile: Bool { type == .profile }
    private enum CardSide: String, CaseIterable, Identifiable, Hashable {
        case front = "앞면"
        case back = "뒷면"
        var id: String { rawValue }
    }
    @State private var selectedCardSide: CardSide = .front

    // Picking/Cropping state
    @State private var editingImage: UIImage?
    @State private var editingSide: CardSide?
    @State private var pickedProfileImage: UIImage?
    @State private var pickedFrontImage: UIImage?
    @State private var pickedBackImage: UIImage?
    @State private var isEditing: Bool = false
    @State private var librarySelection: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var isLoading: Bool = false
    private let previewMaxDimension: CGFloat = 2048

    init(
        type: PhotoType,
        onCroppedProfile: ((UIImage) -> Void)? = nil,
        onCroppedCard: ((UIImage, Bool) -> Void)? = nil,
        initialProfile: UIImage? = nil,
        initialFront: UIImage? = nil,
        initialBack: UIImage? = nil
    ) {
        self.type = type
        self.onCroppedProfile = onCroppedProfile
        self.onCroppedCard = onCroppedCard
        _pickedProfileImage = State(initialValue: initialProfile)
        _pickedFrontImage = State(initialValue: initialFront)
        _pickedBackImage = State(initialValue: initialBack)
    }

    var body: some View {
        VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Large preview per type (show cropped result if available)
                Group {
                    if isProfile {
                        if let img = pickedProfileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 232, height: 232)
                                .cornerRadius(8)
                        } else {
                            Image("ProfileL")
                        }
                    } else {
                        let currentCardImage: UIImage? = (selectedCardSide == .front) ? pickedFrontImage : pickedBackImage
                        Group {
                            if let img = currentCardImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 308, height: 184)
                                    .cornerRadius(8)
                            } else {
                                Image("CardL")
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                                .onEnded { value in
                                    let dragX = value.translation.width
                                    if dragX < -30 { if selectedCardSide == .front { selectedCardSide = .back } }
                                    else if dragX > 30 { if selectedCardSide == .back { selectedCardSide = .front } }
                                }
                        )
                        .onTapGesture {
                            // quick toggle front/back
                            selectedCardSide = (selectedCardSide == .front) ? .back : .front
                        }
                        .padding(.vertical, 24)
                    }
                }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
            Text(isProfile ? "프로필" : (selectedCardSide == .front ? "명함 앞" : "명함 뒤"))
                .font(.title2)
                .padding(.vertical, 16)
            if !isProfile {
                HStack(spacing: 8) {
                    ForEach(CardSide.allCases, id: \.self) { side in
                        Circle()
                            .fill(side == selectedCardSide ? Color.black : Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 8, height: 8)
                            .onTapGesture { selectedCardSide = side }
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 80) {
                Button(action: {
                    isLoading = true
                    Task {
                        let status = AVCaptureDevice.authorizationStatus(for: .video)
                        if status == .notDetermined {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            if !granted { isLoading = false; return }
                        } else if status == .denied || status == .restricted {
                            isLoading = false
                            return
                        }
                        isLoading = false
                        showCamera = true
                    }
                }, label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .padding(.horizontal, 17)
                            .padding(.vertical, 22)
                            .frame(width: 64, height: 64)
                            .background(Color("BackgroundSecondary"))
                            .cornerRadius(32)
                        Text("카메라")
                            .font(.caption2)
                    }
                    .foregroundColor(.black)
                })
                
                
                PhotosPicker(selection: $librarySelection, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .padding(.horizontal, 17)
                            .padding(.vertical, 22)
                            .frame(width: 64, height: 64)
                            .background(Color("BackgroundSecondary"))
                            .cornerRadius(32)
                        Text("사진첩")
                            .font(.caption2)
                    }
                    .foregroundColor(.black)
                }
            }
            .padding(.bottom, 48)
        }
        .safeAreaInset(edge: .top) {
            ZStack(alignment: .center) {
                APEXSheetTopBar(
                    title: "사진 추가",
                    rightTitle: "완료",
                    onRightTap: {
                        // 완료 시에만 상위로 확정 전달
                        if isProfile {
                            if let img = pickedProfileImage { onCroppedProfile?(img) }
                        } else {
                            if let front = pickedFrontImage { onCroppedCard?(front, true) }
                            if let back = pickedBackImage { onCroppedCard?(back, false) }
                        }
                        dismiss()
                    },
                    onClose: {
                        // 취소: 확정 전달 없이 닫기
                        dismiss()
                    }
                )
            }
        }
        .onChange(of: librarySelection) { newItem in
            guard let newItem else { return }
            isLoading = true
            Task.detached(priority: .userInitiated) {
                var result: UIImage?
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    result = downscaledFromData(data, maxDimension: previewMaxDimension)?.fixedOrientation()
                }
                await MainActor.run {
                    if let result {
                        editingImage = result
                        editingSide = isProfile ? nil : selectedCardSide
                        isEditing = true
                    }
                    isLoading = false
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image {
                    isLoading = true
                    Task.detached(priority: .userInitiated) {
                        let scaled = downscaledFromUIImage(image, maxDimension: previewMaxDimension).fixedOrientation()
                        await MainActor.run {
                            editingImage = scaled
                            editingSide = isProfile ? nil : selectedCardSide
                            isEditing = true
                            isLoading = false
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isEditing) {
            if let imageToEdit = editingImage {
                if isProfile {
                    CircularCropperView(sourceImage: imageToEdit) { cropped in
                        pickedProfileImage = cropped
                        editingImage = nil
                        editingSide = nil
                        isEditing = false
                    }
                } else {
                    RectangularCropperView(sourceImage: imageToEdit) { cropped in
                        let side = editingSide ?? selectedCardSide
                        if side == .front { pickedFrontImage = cropped } else { pickedBackImage = cropped }
                        editingImage = nil
                        editingSide = nil
                        isEditing = false
                    }
                }
            } else {
                Color.clear
            }
        }
        .overlay(alignment: .center) {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView("로딩 중…")
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Crop UI (circle for profile, 304x184 rect for card)

private struct CircularCropperView: View {
    let sourceImage: UIImage
    let onConfirm: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotationDeg: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let diameter = min(size.width, size.height) * 0.72
            let cropRect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            ZStack {
                Color(.black)
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotationDeg))
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset },
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(0.5, min(6.0, lastScale * value))
                                }
                                .onEnded { _ in lastScale = scale }
                        )
                    )
                ZStack {
                    Color.black.opacity(0.55)
                    Circle().frame(width: diameter, height: diameter).blendMode(.destinationOut)
                }
                .compositingGroup()
                .allowsHitTesting(false)

                // Rotate button just below the circle
                VStack {
                    Spacer().frame(height: cropRect.minY + diameter + 16)
                    Button {
                        rotationDeg = (rotationDeg + 90).truncatingRemainder(dividingBy: 360)
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 24, weight: .medium))
                            .frame(width: 48, height: 48)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(width: size.width, height: size.height)
                VStack {
                    Spacer()
                    Button {
                        let cropped = renderCircularCrop(fullSize: size, cropRect: cropRect)
                        onConfirm(cropped)
                    } label: {
                        Text("확인").foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 56).background(Color("Primary")).cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func renderCircularCrop(fullSize: CGSize, cropRect: CGRect) -> UIImage {
        let content = TransformedImage(sourceImage: sourceImage, scale: scale, rotationDeg: rotationDeg, offset: offset, canvasSize: fullSize)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        guard let snapshot = renderer.uiImage else { return sourceImage }
        let pixelScale = snapshot.scale
        let outSize = CGSize(width: cropRect.size.width * pixelScale, height: cropRect.size.height * pixelScale)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: outSize, format: fmt).image { ctx in
            let rect = CGRect(origin: .zero, size: outSize)
            ctx.cgContext.addEllipse(in: rect); ctx.cgContext.clip()
            ctx.cgContext.translateBy(x: -cropRect.origin.x * pixelScale, y: -cropRect.origin.y * pixelScale)
            snapshot.draw(in: CGRect(origin: .zero, size: CGSize(width: snapshot.size.width * pixelScale, height: snapshot.size.height * pixelScale)))
        }
    }
}

private struct RectangularCropperView: View {
    let sourceImage: UIImage
    let onConfirm: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotationDeg: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cropWidth = min(304, size.width * 0.86)
            let cropHeight = cropWidth / (304.0 / 184.0)
            let cropRect = CGRect(x: (size.width - cropWidth) / 2, y: (size.height - cropHeight) / 2, width: cropWidth, height: cropHeight)
            ZStack {
                Color(.black)
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotationDeg))
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture().onChanged { value in
                                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                            }.onEnded { _ in lastOffset = offset },
                            MagnificationGesture().onChanged { value in
                                scale = max(0.5, min(6.0, lastScale * value))
                            }.onEnded { _ in lastScale = scale }
                        )
                    )
                ZStack {
                    Color.black.opacity(0.55)
                    Rectangle().frame(width: cropWidth, height: cropHeight).blendMode(.destinationOut).cornerRadius(8)
                }
                .compositingGroup()
                .allowsHitTesting(false)

                // Rotate button just below the rectangle
                VStack {
                    Spacer().frame(height: cropRect.minY + cropHeight + 16)
                    Button {
                        rotationDeg = (rotationDeg + 90).truncatingRemainder(dividingBy: 360)
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 24, weight: .medium))
                            .frame(width: 48, height: 48)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(width: size.width, height: size.height)
                VStack {
                    Spacer()
                    Button {
                        let cropped = renderRectCrop(fullSize: size, cropRect: cropRect)
                        onConfirm(cropped)
                    } label: {
                        Text("확인").foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 56).background(Color("Primary")).cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func renderRectCrop(fullSize: CGSize, cropRect: CGRect) -> UIImage {
        let content = TransformedImage(sourceImage: sourceImage, scale: scale, rotationDeg: rotationDeg, offset: offset, canvasSize: fullSize)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        guard let snapshot = renderer.uiImage else { return sourceImage }
        let pixelScale = snapshot.scale
        let outSize = CGSize(width: cropRect.size.width * pixelScale, height: cropRect.size.height * pixelScale)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: outSize, format: fmt).image { ctx in
            let rect = CGRect(origin: .zero, size: outSize)
            ctx.cgContext.addRect(rect); ctx.cgContext.clip()
            ctx.cgContext.translateBy(x: -cropRect.origin.x * pixelScale, y: -cropRect.origin.y * pixelScale)
            snapshot.draw(in: CGRect(origin: .zero, size: CGSize(width: snapshot.size.width * pixelScale, height: snapshot.size.height * pixelScale)))
        }
    }
}

// Shared transformed rendering
private struct TransformedImage: View {
    let sourceImage: UIImage
    let scale: CGFloat
    let rotationDeg: Double
    let offset: CGSize
    let canvasSize: CGSize
    var body: some View {
        Image(uiImage: sourceImage)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotationDeg))
            .offset(offset)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .background(Color.clear)
    }
}

// Downscale helpers
private func downscaledFromData(_ data: Data, maxDimension: CGFloat) -> UIImage? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
    return UIImage(cgImage: cgThumb)
}

private func downscaledFromUIImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let w = image.size.width, h = image.size.height
    let scale = min(1, maxDimension / max(w, h))
    if scale >= 0.999 { return image }
    let newSize = CGSize(width: w * scale, height: h * scale)
    let fmt = UIGraphicsImageRendererFormat(); fmt.scale = image.scale; fmt.opaque = false
    return UIGraphicsImageRenderer(size: newSize, format: fmt).image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}

// Camera picker
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onImage(nil) }
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage)
            picker.dismiss(animated: true) { self.onImage(image) }
        }
    }
}

#Preview {
    PhotoAddView(type: .card)
}
