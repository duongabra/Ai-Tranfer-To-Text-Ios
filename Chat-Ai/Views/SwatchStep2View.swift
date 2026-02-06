//
//  SwatchStep2View.swift
//  Chat-Ai
//
//  Step 2: Take/upload face photo — State 1 (choose), State 2 (local preview), State 3 (Figma 55367-1481, applying)
//  Upload ảnh lên Storage chỉ khi bấm "Yes, use this photo".
//

import SwiftUI

struct SwatchStep2View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    private let progressCornerRadius: CGFloat = 20
    private let progressFillColor = Color(hex: "030712")
    private let progressEmptyColor = Color(hex: "F9FAFB")

    @State private var faceImage: UIImage?
    @State private var faceImageURL: String?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var isUploadingFace = false
    @State private var showFaceUploadErrorAlert = false
    @State private var faceUploadErrorMessage: String?
    @State private var step2ShowingState3 = false
    @State private var step2ShowingState4 = false
    @State private var step2MockProgress: CGFloat = 0
    private let step2ProgressDuration: TimeInterval = 10
    @State private var step2State4LikeDislike: Bool? = nil // true = like, false = dislike
    @State private var step2BeforeAfterSliderPosition: CGFloat = 0.5 // 0 = all After, 1 = all Before
    @State private var step2SliderDragStartPosition: CGFloat? = nil

    private var isState2: Bool { faceImage != nil && !step2ShowingState3 && !step2ShowingState4 }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                if step2ShowingState4 {
                    step2State4Header
                } else if !step2ShowingState3 {
                    step2ModalHeader
                }
                ScrollView {
                    if step2ShowingState4 {
                        step2State4Content
                    } else if step2ShowingState3 {
                        step2State3Content
                    } else if isState2 {
                        step2State2Content
                    } else {
                        step2State1Content
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(source: .camera, image: $faceImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingLibrary) {
            ImagePicker(source: .photoLibrary, image: $faceImage)
                .ignoresSafeArea()
        }
        .alert("Upload failed", isPresented: $showFaceUploadErrorAlert) {
            Button("OK", role: .cancel) {
                isUploadingFace = false
            }
        } message: {
            Text(faceUploadErrorMessage ?? "Could not upload face photo.")
        }
    }

    private func uploadFaceImageThenGoToState3(_ image: UIImage) {
        guard let userId = authViewModel.currentUser?.id,
              let data = image.jpegData(compressionQuality: 0.85) else {
            faceUploadErrorMessage = "Missing user or invalid image."
            showFaceUploadErrorAlert = true
            return
        }
        isUploadingFace = true
        Task {
            do {
                let url = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data)
                await MainActor.run {
                    faceImageURL = url
                    isUploadingFace = false
                    step2ShowingState3 = true
                    startStep2ProgressTimer()
                }
            } catch {
                await MainActor.run {
                    isUploadingFace = false
                    faceUploadErrorMessage = error.localizedDescription
                    showFaceUploadErrorAlert = true
                }
            }
        }
    }

    private func startStep2ProgressTimer() {
        step2MockProgress = 0
        let interval: TimeInterval = 0.05
        let increment = 100 * interval / step2ProgressDuration
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                step2MockProgress += increment
                if step2MockProgress >= 100 {
                    timer.invalidate()
                    step2ShowingState4 = true
                }
            }
        }
        .fire()
    }

    // MARK: - Header (state 1: back invisible; state 2/3: back visible)
    private var step2ModalHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            if isState2 || step2ShowingState3 {
                Button(action: {
                    if step2ShowingState3 {
                        step2ShowingState3 = false
                    } else {
                        faceImage = nil
                        faceImageURL = nil
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
                    .fill(progressFillColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

            Button(action: { dismiss() }) {
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
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - State 4 header (home left, close right)
    private var step2State4Header: some View {
        HStack(alignment: .center, spacing: 24) {
            Button(action: { dismiss() }) {
                Image("step2_home_swatch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 13)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F9FAFB"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
            Button(action: { dismiss() }) {
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
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - State 4: Result before/after (Figma 55367-46384, image 55382-52638)
    private static let step2BeforeURL = URL(string: "https://picsum.photos/335/446")
    private static let step2AfterURL = URL(string: "https://picsum.photos/seed/after2/335/446")

    private var step2State4Content: some View {
        VStack(alignment: .center, spacing: 20) {
            // Before / After swipe (mock 2 images, kéo sang 2 bên)
            step2State4BeforeAfterBlock
            // Action buttons: Reset, Download, Heart (order per design)
            HStack(spacing: 16) {
                Button(action: {
                    step2ShowingState4 = false
                    step2ShowingState3 = false
                    step2MockProgress = 0
                    step2ShowingState3 = true
                    startStep2ProgressTimer()
                }) {
                    Image("step2_reset_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 16)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(Circle().stroke(Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { /* TODO: download result image */ }) {
                    Image("step2_down_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { /* TODO: favorite */ }) {
                    Image("step2_heart_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 15)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(Circle().stroke(Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
            }
            // Score card
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(Color(hex: "30A159"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("8/10")
                        .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                        .foregroundColor(Color(hex: "030712"))
                }
                .frame(width: 56, height: 56)
                Text("Warm brick tones add definition to your lips while keeping a natural look.")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "F9FAFB"))
            .cornerRadius(16)
            // Like or dislike — centered, 12px gap between text and each button
            HStack(alignment: .center, spacing: 12) {
                Text("Do you like this swatch?")
                    .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "101828"))
                Button(action: { step2State4LikeDislike = true }) {
                    Image("step2_like_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(step2State4LikeDislike == true ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                        .frame(width: 13, height: 13)
                        .frame(width: 44, height: 44)
                        .background(step2State4LikeDislike == true ? Color(hex: "030712") : Color.white)
                        .overlay(Circle().stroke(step2State4LikeDislike == true ? Color.clear : Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { step2State4LikeDislike = false }) {
                    Image("step2_dislike_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(step2State4LikeDislike == false ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                        .frame(width: 16, height: 16)
                        .frame(width: 44, height: 44)
                        .background(step2State4LikeDislike == false ? Color(hex: "030712") : Color.white)
                        .overlay(Circle().stroke(step2State4LikeDislike == false ? Color.clear : Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private static let step2BeforeAfterAspectRatio: CGFloat = 335 / 446

    private var step2State4BeforeAfterBlock: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let dividerX = width * step2BeforeAfterSliderPosition
            ZStack(alignment: .leading) {
                // After (right side) — full area
                AsyncImage(url: Self.step2AfterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
                .frame(width: width, height: height)
                .clipped()
                // Before (left side) — clipped to left of divider
                AsyncImage(url: Self.step2BeforeURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
                .frame(width: width, height: height)
                .frame(width: dividerX, height: height, alignment: .leading)
                .clipped()
                // Badges
                Text("Before")
                    .font(.custom("Overused Grotesk", size: 12).weight(.medium))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Text("After")
                    .font(.custom("Overused Grotesk", size: 12).weight(.medium))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                // Divider line (white) + handle
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: dividerX - 1)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                    Spacer()
                }
                .frame(height: height)
                .overlay(alignment: .leading) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                        Image("step2_slider_handle_swatch")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 8)
                    }
                    .offset(x: dividerX - 16)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if step2SliderDragStartPosition == nil {
                                step2SliderDragStartPosition = step2BeforeAfterSliderPosition
                            }
                            let start = step2SliderDragStartPosition ?? 0.5
                            step2BeforeAfterSliderPosition = min(1, max(0, start + value.translation.width / width))
                        }
                        .onEnded { _ in
                            step2SliderDragStartPosition = nil
                        }
                )
            }
            .frame(width: width, height: height)
            .cornerRadius(16)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.step2BeforeAfterAspectRatio, contentMode: .fit)
    }

    // MARK: - State 1: Take a photo of your face (take / upload)
    private var step2State1Content: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Take a photo of your face")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            facePhotoArea

            VStack(alignment: .leading, spacing: 8) {
                ruleRow(icon: "checkmark.circle.fill", text: "Center your face within the oval area")
                ruleRow(icon: "checkmark.circle.fill", text: "Maintain a neutral expression")
                ruleRow(icon: "checkmark.circle.fill", text: "Ensure good lighting")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: { showingCamera = true }) {
                    HStack(spacing: 8) {
                        Image("camera_2_ai_swatch")
                            .renderingMode(Image.TemplateRenderingMode.template)
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
                            .renderingMode(Image.TemplateRenderingMode.template)
                            .foregroundColor(Color(hex: "101828"))
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
                            .stroke(Color(hex: "101828"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - State 2: Your photo looks good (Figma 55367-636) — preview from Storage
    private var step2State2Content: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Your photo looks good")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Group {
                if let img = faceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 165)
                        .overlay {
                            if isUploadingFace {
                                Color.black.opacity(0.3)
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Text("Uploading...")
                                        .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ruleRow(icon: "checkmark.circle.fill", text: "Face centered")
                ruleRow(icon: "checkmark.circle.fill", text: "Good lighting")
                ruleRow(icon: "checkmark.circle.fill", text: "Neutral expression")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: {
                    guard let img = faceImage else { return }
                    uploadFaceImageThenGoToState3(img)
                }) {
                    Text("Yes, use this photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUploadingFace)

                Button(action: {
                    faceImage = nil
                    faceImageURL = nil
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
                .disabled(isUploadingFace)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    /// State 3 image block per Figma 55367-46540: center 160x160 circle (100% round), 3 dashed rings, 3 icon buttons dịch vào
    private var step2State3ImageSection: some View {
        ZStack {
            // Center 160x160 image — bo tròn full 100% (Circle)
            if let img = faceImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            } else if let urlString = faceImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
            }
            // 3 concentric dashed rings (200, 240, 280) — stroke rgba(0,0,0,0.05), dash [4,4]
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 200, height: 200)
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 240, height: 240)
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 280, height: 280)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .overlay {
            GeometryReader { g in
                let cx = g.size.width / 2
                let cy = g.size.height / 2
                let r: CGFloat = 140 // radius of outer circle (280/2)
                // 3 icon đúng vị trí design: sparkle 1h (30°), lipstick 9h (180°), pencil 5h (150°)
                ZStack {
                    Image("step2_ai_sparkle_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(300 * .pi / 180), y: cy + r * sin(300 * .pi / 180))
                    Image("step2_lipstick_fill_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(180 * .pi / 180), y: cy + r * sin(180 * .pi / 180))
                    Image("step2_pencil_fill_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(60 * .pi / 180), y: cy + r * sin(60 * .pi / 180))
                }
            }
        }
    }

    // MARK: - State 3: Applying the shade... (Figma 55367-1481)
    private var step2State3Content: some View {
        VStack(alignment: .center, spacing: 24) {
            step2State3ImageSection

            VStack(alignment: .center, spacing: 16) {
                Text("Applying the shade...")
                    .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 24) {
                    step2State3ProgressRow(
                        label: "Detecting lips & shape",
                        progress: min(1, step2MockProgress / 25),
                        percent: min(100, Int(step2MockProgress)),
                        isActive: step2MockProgress > 0
                    )
                    step2State3ProgressRow(
                        label: "Applying the shade",
                        progress: min(1, max(0, (step2MockProgress - 25) / 25)),
                        percent: step2MockProgress > 25 ? min(100, Int(step2MockProgress)) : 0,
                        isActive: step2MockProgress > 25
                    )
                    step2State3ProgressRow(
                        label: "Blending for a natural finish",
                        progress: min(1, max(0, (step2MockProgress - 50) / 25)),
                        percent: step2MockProgress > 50 ? min(100, Int(step2MockProgress)) : 0,
                        isActive: step2MockProgress > 50
                    )
                    step2State3ProgressRow(
                        label: "Finalizing your swatch",
                        progress: min(1, max(0, (step2MockProgress - 75) / 25)),
                        percent: step2MockProgress > 75 ? min(100, Int(step2MockProgress)) : 0,
                        isActive: step2MockProgress > 75
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func step2State3ProgressRow(label: String, progress: CGFloat, percent: Int, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "F3F4F6"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(isActive ? Color(hex: "E5E7EB") : Color(hex: "E5E7EB"), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 16)
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

    // MARK: - Face photo area (sample or selected image + oval dashed, border 12px) — 165x220 fit
    private var facePhotoArea: some View {
        ZStack {
            Group {
                if let img = faceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image("FacePhotoSample")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 165, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Ellipse()
                .stroke(Color(hex: "F3F4F6"), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: 165, height: 220)
        }
        .frame(width: 165, height: 220)
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "30A159"))
            Text(text)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "364153"))
        }
    }
}

#Preview {
    SwatchStep2View()
        .environmentObject(AuthViewModel())
}
