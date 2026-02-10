//
//  SwatchStep1View.swift
//  Chat-Ai
//
//  Step 1: 4 states — chọn 2 ảnh son → xác nhận → analyzing (progress) → Lipstick identified (info overlay)
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - PHPicker: chọn đúng 2 ảnh (upload)
struct PHPickerView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        init(_ parent: PHPickerView) {
            self.parent = parent
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { parent.onComplete([]); return }
            let providers = results.map(\.itemProvider)
            var images: [UIImage?] = Array(repeating: nil, count: providers.count)
            let group = DispatchGroup()
            for (index, provider) in providers.enumerated() {
                group.enter()
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { obj, _ in
                        if let img = obj as? UIImage {
                            images[index] = img
                        }
                        group.leave()
                    }
                } else { group.leave() }
            }
            group.notify(queue: .main) {
                self.parent.onComplete(images.compactMap { $0 })
            }
        }
    }
}

// MARK: - Image Picker (camera / single photo, iOS 15 compatible)
struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case photoLibrary
        case camera
    }
    let source: Source
    @Binding var image: UIImage?
    /// When true and source is camera, use front camera (selfie). Default false = rear camera.
    var useFrontCamera: Bool = false
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        switch source {
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        case .camera:
            picker.sourceType = .camera
            if useFrontCamera, UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            } else if !useFrontCamera, UIImagePickerController.isCameraDeviceAvailable(.rear) {
                picker.cameraDevice = .rear
            }
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Step 1 View (4 states)
struct SwatchStep1View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    /// Gọi khi user bấm "Add face photo" — parent chuyển sang Step 2, truyền url 2 ảnh son + brand/product/shade (có thể đã chỉnh)
    var onProceedToStep2: ((_ lipstickURL1: String, _ lipstickURL2: String, _ brand: String, _ product: String, _ shade: String) -> Void)?
    /// Gọi khi user bấm nút X đóng màn (để ContentView chuyển tab và hiện lại tab bar)
    var onClose: (() -> Void)?

    @State private var lipstickImage1: UIImage?
    @State private var lipstickImage2: UIImage?
    @State private var lipstickImageURL1: String?
    @State private var lipstickImageURL2: String?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showNeedTwoImagesAlert = false
    @State private var pickingForSlot: Int = 1
    @State private var step1ShowingState3 = false
    @State private var step1ShowingState4 = false
    @State private var step1ShowingFirstPhotoReview = false
    @State private var state3UploadError: String?
    @State private var showUploadErrorAlert = false
    /// API recognize xong → cập nhật brand/product/shade, set true. Kết hợp với state3TimerDone để chuyển State 4.
    @State private var state3ApiDone = false
    /// Timer 50s chạy xong (hoặc đã ramp 1s khi API xong sớm) → set true. Chỉ chuyển State 4 khi cả state3ApiDone và state3TimerDone đều true.
    @State private var state3TimerDone = false

    @State private var mockProgressTotal: CGFloat = 0
    @State private var mockTimer: Timer?
    /// Progress chạy 0→99% trong 50s. Hết 50s mà API chưa xong thì đứng ở 99%, khi API xong nhảy lên 100% rồi chuyển State 4. API xong sớm thì ramp 100% trong 1s rồi chuyển.
    private let mockDuration: TimeInterval = 50

    // State 4: lipstick details từ API (editable), edit mode, and which field is being edited
    @State private var step1State4Brand = ""
    @State private var step1State4Product = ""
    @State private var step1State4Shade = ""
    @State private var step1State4EditMode = false
    @State private var step1State4EditingField: String? = nil
    @State private var step1State4EditSheetFieldKey: String = ""
    @State private var step1State4EditSheetValue = ""
    @State private var step1State4ShowEditView = false

    private var step1State4AllFilled: Bool {
        !step1State4Brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !step1State4Product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !step1State4Shade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var step1State2: Bool {
        lipstickImage1 != nil && lipstickImage2 != nil
    }

    private let progressCornerRadius: CGFloat = 20
    private let progressFillColor = Color(hex: "030712")
    private let progressEmptyColor = Color(hex: "F9FAFB")
    private let imageSize1: (w: CGFloat, h: CGFloat) = (93, 131)
    private let imageSize2: (w: CGFloat, h: CGFloat) = (55, 125)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                if step1ShowingState4 || !step1ShowingState3 || step1ShowingFirstPhotoReview {
                    step1ModalHeader
                }

                if step1ShowingState4 {
                    step1State4Content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if step1ShowingFirstPhotoReview {
                    step1FirstPhotoReviewContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            if step1ShowingState3 {
                                step1State3Content
                            } else if step1State2 {
                                step1State2Content
                            } else {
                                step1State1Content
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, step1ShowingState4 ? 0 : 16)
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(source: .camera, image: bindingForSlot(pickingForSlot))
        }
        .sheet(isPresented: $showingLibrary) {
            PHPickerView(selectionLimit: 2) { images in
                if images.count == 2 {
                    lipstickImage1 = images[0]
                    lipstickImage2 = images[1]
                } else if images.count == 1 {
                    showNeedTwoImagesAlert = true
                }
            }
        }
        .alert("Please select 2 images", isPresented: $showNeedTwoImagesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need to select 2 lipstick photos to continue.")
        }
        .alert("Upload failed", isPresented: $showUploadErrorAlert) {
            Button("OK", role: .cancel) {
                state3UploadError = nil
            }
        } message: {
            Text(state3UploadError ?? "")
        }
        .onChange(of: showingCamera) { isShowing in
            if !isShowing {
                if pickingForSlot == 1, lipstickImage1 != nil {
                    step1ShowingFirstPhotoReview = true
                } else if pickingForSlot == 2 {
                    step1ShowingFirstPhotoReview = false
                }
            }
        }
        .onDisappear {
            mockTimer?.invalidate()
            mockTimer = nil
        }
    }

    private func nextEmptySlot() -> Int {
        lipstickImage1 == nil ? 1 : 2
    }

    private func bindingForSlot(_ slot: Int) -> Binding<UIImage?> {
        if slot == 1 { return $lipstickImage1 }
        return $lipstickImage2
    }

    // MARK: - Modal Header
    private var step1ModalHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            if (step1State2 && !step1ShowingState3) || step1ShowingState4 || step1ShowingFirstPhotoReview {
                Button(action: {
                    if step1ShowingState4 {
                        step1ShowingState4 = false
                        step1ShowingState3 = false
                    } else if step1ShowingFirstPhotoReview {
                        lipstickImage1 = nil
                        step1ShowingFirstPhotoReview = false
                    } else {
                        retakePhotos()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "4A5565"))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressFillColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

            Button(action: { onClose?() ?? dismiss() }) {
                Image("close_line_swatch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F9FAFB"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, step1ShowingState4 ? 4 : 16)
        .padding(.bottom, step1ShowingState4 ? 4 : 8)
    }

    // MARK: - State 1: Take 2 lipstick photos
    private var step1State1Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take 2 lipstick photos ")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Good example")
                    .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(Color(hex: "6A7282"))

                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let squareSize = (availableWidth - 12) / 2
                    HStack(alignment: .top, spacing: 12) {
                        slotView(
                            image: lipstickImage1,
                            sampleImageName: "LipstickSampleBox",
                            caption: "Full tube - logo visible",
                            squareSize: squareSize,
                            imageSize: imageSize1
                        )
                        slotView(
                            image: lipstickImage2,
                            sampleImageName: "LipstickSampleTube",
                            caption: "Bottom label or tube text",
                            squareSize: squareSize,
                            imageSize: imageSize2
                        )
                    }
                    .frame(width: availableWidth, height: squareSize + 12 + 24)
                }
                .frame(height: 220)
            }
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                Button(action: {
                    pickingForSlot = nextEmptySlot()
                    showingCamera = true
                }) {
                    HStack(spacing: 8) {
                        Image("camera_2_ai_swatch")
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: "F9FAFB"))
                            .frame(width: 20, height: 20)
                        Text("Take a photo")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    }
                    .foregroundColor(Color(hex: "F9FAFB"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .padding(.trailing, 20)
                    .background(Color(hex: "030712"))
                    .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showingLibrary = true }) {
                    HStack(spacing: 8) {
                        Image("upload_2_swatch")
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: "030712"))
                            .frame(width: 20, height: 20)
                        Text("Upload a photo")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    }
                    .foregroundColor(Color(hex: "101828"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9999)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private func slotView(image: UIImage?, sampleImageName: String, caption: String, squareSize: CGFloat, imageSize: (w: CGFloat, h: CGFloat)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Color(hex: "F3F4F6")
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(12)
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(sampleImageName)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: imageSize.w, height: imageSize.h)
            }
            .frame(width: squareSize, height: squareSize)
            .clipped()
            .cornerRadius(12)
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "30A159"))
                Text(caption)
                    .font(.custom("Overused Grotesk", size: 12).weight(.regular))
                    .foregroundColor(Color(hex: "364153"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - First photo review (màn trung gian — Figma 55397-53688)
    private var step1FirstPhotoReviewContent: some View {
        VStack(alignment: .center, spacing: 24) {
            if let img = lipstickImage1 {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 479)
                    .clipped()
                    .cornerRadius(20)
            }
            VStack(spacing: 12) {
                Button(action: {
                    pickingForSlot = 2
                    showingCamera = true
                }) {
                    Text("Take one more")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    lipstickImage1 = nil
                    step1ShowingFirstPhotoReview = false
                }) {
                    Text("Retake photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "101828"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(Color(hex: "101828"), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 20)
    }

    // MARK: - State 2: Confirm your photos
    private var step1State2Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm your photos")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            HStack(alignment: .top, spacing: 4) {
                if let img1 = lipstickImage1 {
                    Image(uiImage: img1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                }
                if let img2 = lipstickImage2 {
                    Image(uiImage: img2)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 12) {
                Button(action: { confirmPhotos() }) {
                    Text("Yes, use these photos")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { retakePhotos() }) {
                    Text("Retake photos")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "101828"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private func retakePhotos() {
        lipstickImage1 = nil
        lipstickImage2 = nil
        lipstickImageURL1 = nil
        lipstickImageURL2 = nil
        step1ShowingState3 = false
        step1ShowingState4 = false
        step1ShowingFirstPhotoReview = false
        state3ApiDone = false
        state3TimerDone = false
        mockTimer?.invalidate()
        mockProgressTotal = 0
    }

    private func confirmPhotos() {
        guard let img1 = lipstickImage1, let img2 = lipstickImage2,
              let userId = authViewModel.currentUser?.id else {
            return
        }
        let data1 = img1.jpegData(compressionQuality: 0.85) ?? Data()
        let data2 = img2.jpegData(compressionQuality: 0.85) ?? Data()
        Task {
            do {
                let url1 = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data1)
                let url2 = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data2)
                await MainActor.run {
                    lipstickImageURL1 = url1
                    lipstickImageURL2 = url2
                    step1ShowingState3 = true
                    state3ApiDone = false
                    state3TimerDone = false
                    startMockProgressTimer()
                }
                // Log 2 URL ảnh và access_token gửi lên API để check
                let accessToken = AuthService.shared.getAccessToken()
                print("[Swatch] access_token: \(accessToken ?? "nil")")
                print("[Swatch] POST /api/mobile/swatches/recognize — image_urls[0]: \(url1)")
                print("[Swatch] POST /api/mobile/swatches/recognize — image_urls[1]: \(url2)")
                // Gọi API recognize song song với timer 10s
                let result = try await SwatchAPIService.shared.recognizeLipstick(imageURLs: [url1, url2])
                await MainActor.run {
                    step1State4Brand = result.brand ?? ""
                    step1State4Product = result.product ?? ""
                    step1State4Shade = result.shade ?? ""
                    state3ApiDone = true
                    if state3TimerDone {
                        // Đang đứng ở 99% chờ API → nhảy lên 100% rồi chuyển State 4
                        mockProgressTotal = 100
                        step1ShowingState4 = true
                    } else {
                        // API xong trước 50s → ramp progress lên 100% trong 1s rồi chuyển State 4
                        startRampTo100AndProceed()
                    }
                }
            } catch {
                print("[Swatch] Error: \(error)")
                await MainActor.run {
                    let message = error.localizedDescription
                    state3UploadError = message.hasPrefix("A server with the specified hostname") || message.contains("could not be found")
                        ? "\(message) Kiểm tra: 1) Backend đang chạy tại \(AppConfig.swatchAPIBaseURL)? 2) Simulator và máy chạy backend cùng WiFi/mạng."
                        : message
                    showUploadErrorAlert = true
                }
            }
        }
    }

    private func startMockProgressTimer() {
        mockProgressTotal = 0
        mockTimer?.invalidate()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            mockProgressTotal += CGFloat(0.05 / mockDuration) * 99
            if mockProgressTotal >= 99 {
                mockTimer?.invalidate()
                mockTimer = nil
                mockProgressTotal = 99
                state3TimerDone = true
                if state3ApiDone {
                    mockProgressTotal = 100
                    step1ShowingState4 = true
                }
                // Hết 50s mà API chưa xong: progress đứng ở 99%, khi API xong sẽ nhảy lên 100% (xử lý ở block API return)
            }
        }
        RunLoop.main.add(mockTimer!, forMode: .common)
    }

    /// API xong trước 50s: tắt timer chậm, tăng progress từ hiện tại lên 100% trong 1s rồi chuyển State 4.
    private func startRampTo100AndProceed() {
        mockTimer?.invalidate()
        let startProgress = mockProgressTotal
        let startTime = Date()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= 1 {
                mockProgressTotal = 100
                mockTimer?.invalidate()
                mockTimer = nil
                state3TimerDone = true
                step1ShowingState4 = true
                return
            }
            mockProgressTotal = startProgress + (100 - startProgress) * CGFloat(elapsed / 1)
        }
        RunLoop.main.add(mockTimer!, forMode: .common)
    }

    // MARK: - State 3: Analyzing (progress)
    private var step1State3Content: some View {
        VStack(alignment: .center, spacing: 24) {
            HStack(alignment: .top, spacing: 4) {
                state3ImagePreview(url: lipstickImageURL1, image: lipstickImage1)
                state3ImagePreview(url: lipstickImageURL2, image: lipstickImage2)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .center, spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "F9FAFB"), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(mockProgressTotal / 100))
                        .stroke(Color(hex: "030712"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(mockProgressTotal))%")
                        .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(Color(hex: "6A7282"))
                }
                .frame(width: 64, height: 64)
                Text("Finding your lipstick...")
                    .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 24) {
                state3ProgressRow(
                    label: "Detecting the brand logo",
                    progress: min(1, mockProgressTotal / 33.33),
                    isActive: mockProgressTotal > 0
                )
                state3ProgressRow(
                    label: "Identifying the product line",
                    progress: min(1, max(0, (mockProgressTotal - 33.33) / 33.33)),
                    isActive: mockProgressTotal > 33.33
                )
                state3ProgressRow(
                    label: "Reading shade name",
                    progress: min(1, max(0, (mockProgressTotal - 66.66) / 33.34)),
                    isActive: mockProgressTotal > 66.66
                )
            }
        }
        .padding(.top, 12)
    }

    // MARK: - State 4: Lipstick identified (info overlay)
    private var step1State4Content: some View {
        GeometryReader { geo in
            VStack(alignment: .center, spacing: 24) {
                ZStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 4) {
                        state3ImagePreview(url: lipstickImageURL1, image: lipstickImage1)
                        state3ImagePreview(url: lipstickImageURL2, image: lipstickImage2)
                    }
                    .frame(maxWidth: .infinity)
                    Color.black.opacity(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                state4InfoPanelOverlay(safeBottom: geo.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func state4InfoPanelOverlay(safeBottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Color.white
                    .frame(maxWidth: .infinity, maxHeight: 375)
                    .ignoresSafeArea(edges: .bottom)
                state4CardContent
            }
            .frame(maxWidth: .infinity)
            .frame(height: 375)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 32, x: 0, y: 0)
        }
    }

    private var state4CardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image("sparkles_ai_swatch")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(hex: "101828"))
                    Text("Lipstick identified")
                        .font(.custom("Overused Grotesk", size: 20).weight(.regular))
                        .foregroundColor(Color(hex: "101828"))
                }
                Text("Please confirm the details before we generate your swatch")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
            }
            VStack(spacing: 8) {
                state4InfoRowDisplayOnly(label: "Brand", value: step1State4Brand)
                state4InfoRowDisplayOnly(label: "Product", value: step1State4Product)
                state4InfoRowDisplayOnly(label: "Shade", value: step1State4Shade)
            }
            VStack(spacing: 12) {
                Button(action: {
                    onProceedToStep2?(lipstickImageURL1 ?? "", lipstickImageURL2 ?? "", step1State4Brand, step1State4Product, step1State4Shade)
                }) {
                    Text("Add face photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    step1State4ShowEditView = true
                }) {
                    HStack(spacing: 8) {
                        Image("step1_edit_pencil")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "101828"))
                        Text("Edit details")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                            .foregroundColor(Color(hex: "101828"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 9999)
                            .stroke(Color(hex: "101828"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(isPresented: $step1State4ShowEditView) {
            state4EditViewLikeImage3
        }
    }

    /// Giao diện edit như ảnh 3: 3 dòng có bút chì, Save and add face photo
    private var state4EditViewLikeImage3: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "F97316"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("We couldn’t identify this lipstick")
                        .font(.custom("Overused Grotesk", size: 20).weight(.regular))
                        .foregroundColor(Color(hex: "101828"))
                    Text("Don’t worries — you can enter the details manually to continue swatching.")
                        .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(Color(hex: "6A7282"))
                }
                // Spacer()
                // Button(action: { step1State4ShowEditView = false }) {
                //     Image(systemName: "xmark")
                //         .font(.system(size: 16, weight: .medium))
                //         .foregroundColor(Color(hex: "101828"))
                // }
            }
            VStack(spacing: 8) {
                state4InfoRow(label: "Brand", value: step1State4Brand, fieldKey: "Brand", editMode: true) {
                    step1State4EditSheetFieldKey = "Brand"
                    step1State4EditSheetValue = step1State4Brand
                    step1State4EditingField = "Brand"
                }
                state4InfoRow(label: "Product", value: step1State4Product, fieldKey: "Product", editMode: true) {
                    step1State4EditSheetFieldKey = "Product"
                    step1State4EditSheetValue = step1State4Product
                    step1State4EditingField = "Product"
                }
                state4InfoRow(label: "Shade", value: step1State4Shade, fieldKey: "Shade", editMode: true) {
                    step1State4EditSheetFieldKey = "Shade"
                    step1State4EditSheetValue = step1State4Shade
                    step1State4EditingField = "Shade"
                }
            }
            Spacer(minLength: 0)
            Button(action: {
                step1State4ShowEditView = false
                onProceedToStep2?(lipstickImageURL1 ?? "", lipstickImageURL2 ?? "", step1State4Brand, step1State4Product, step1State4Shade)
            }) {
                Text("Save and add face photo")
                    .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "F9FAFB"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color(hex: "030712"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.white)
        .sheet(isPresented: Binding(
            get: { step1State4EditingField != nil },
            set: { if !$0 { step1State4EditingField = nil } }
        )) {
            state4EditSheet(fieldKey: step1State4EditSheetFieldKey)
        }
    }

    private func state4InfoRowDisplayOnly(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "6A7282"))
            Spacer()
            Text(value)
                .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "101828"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(12)
    }

    private func state4EditSheet(fieldKey: String) -> some View {
        let title = "Edit lipstick information"
        let label = fieldKey == "Product" ? "Product Name" : fieldKey
        let placeholder = fieldKey == "Brand" ? "Enter brand" : (fieldKey == "Product" ? "Enter product name" : "Enter shade")
        return NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(label)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                TextField(placeholder, text: $step1State4EditSheetValue)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F9FAFB"))
                    .cornerRadius(12)
                Spacer()
                Button(action: {
                    switch fieldKey {
                    case "Brand": step1State4Brand = step1State4EditSheetValue
                    case "Product": step1State4Product = step1State4EditSheetValue
                    case "Shade": step1State4Shade = step1State4EditSheetValue
                    default: break
                    }
                    step1State4EditingField = nil
                }) {
                    Text("Save")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "99A1AF"))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { step1State4EditingField = nil }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "101828"))
                    }
                }
            }
        }
    }

    private func state4InfoRow(label: String, value: String, fieldKey: String, editMode: Bool, onPencilTap: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "6A7282"))
            Spacer()
            Text(value)
                .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "101828"))
            if editMode {
                Button(action: onPencilTap) {
                    Image("step1_edit_pencil")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(hex: "99A1AF"))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(12)
    }

    private func state3ImagePreview(url: String?, image: UIImage?) -> some View {
        Group {
            if let urlString = url, let u = URL(string: urlString) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        imagePreviewFallback(image: image)
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, maxHeight: 120)
                    @unknown default:
                        imagePreviewFallback(image: image)
                    }
                }
            } else if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Color(hex: "F3F4F6")
                    .frame(minHeight: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
    }

    private func imagePreviewFallback(image: UIImage?) -> some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Color(hex: "F3F4F6").frame(minHeight: 80)
            }
        }
    }

    private func state3ProgressRow(label: String, progress: CGFloat, isActive: Bool) -> some View {
        let stepPercent = min(100, Int(progress * 100))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(stepPercent)%")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "F3F4F6"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(isActive ? Color(hex: "101828") : Color(hex: "99A1AF"), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "030712"))
                        .frame(width: max(0, (geo.size.width - 4) * progress), height: 4)
                        .padding(.leading, 2)
                        .padding(.vertical, 2)
                        .opacity(progress > 0 ? 1 : 0)
                }
            }
            .frame(height: 8)
        }
    }
}
