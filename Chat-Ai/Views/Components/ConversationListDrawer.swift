//
//  ConversationListDrawer.swift
//  Chat-Ai
//
//  Side drawer hiển thị danh sách conversations theo design Figma
//

import SwiftUI
import AVFoundation

struct ConversationListDrawer: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = ConversationListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var searchText = ""
    @State private var showingSettings = false
    
    var onConversationSelected: ((Conversation) -> Void)?
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background overlay với blur
            if isPresented {
                Color.white
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
            }
            
            // Drawer content
            if isPresented {
                drawerContent
                    .transition(.move(edge: .leading))
            }
        }
        .task {
            await viewModel.loadConversations()
        }
    }
    
    // MARK: - Drawer Content
    
    private var drawerContent: some View {
        VStack(spacing: 0) {
            // Header với search và edit button
            drawerHeader
            
            // History title
            historyTitle
            
            // Conversations list - sẽ expand để fill space
            conversationsList
            
            Spacer(minLength: 0)
            
            // Footer với user profile - sát dưới
            drawerFooter
        }
        .frame(width: 360)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .ignoresSafeArea(edges: .vertical)
        .shadow(color: .black.opacity(0.1), radius: 32, x: 0, y: 0)
    }
    
    // MARK: - Drawer Header
    
    private var drawerHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.custom("Overused Grotesk", size: 16))
                        .foregroundColor(Color(hex: "#717171")) // .textTertiary hardcoded
                        .frame(width: 16, height: 16)
                    
                    ZStack(alignment: .leading) {
                        if searchText.isEmpty {
                            Text("Search")
                                .font(.custom("Overused Grotesk", size: 14))
                                .foregroundColor(Color(hex: "#717171")) // placeholder color
                                .fontWeight(.regular)
                                .lineSpacing(6) // (20-14) from design
                        }
                        TextField("", text: $searchText)
                            .font(.custom("Overused Grotesk", size: 14))
                            .foregroundColor(.textPrimary)
                            .fontWeight(.regular)
                            .lineSpacing(6) // (20-14)
                }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 9999)
                        .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
                )
                .cornerRadius(9999)
                
                // Edit button
                Button(action: {
                    // TODO: Edit mode
                }) {
                    Image("edit_button_drawer")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 80)
        .padding(.bottom, 24)
    }
    
    // MARK: - History Title
    
    private var historyTitle: some View {
        HStack {
            Text("History")
                .font(.custom("Overused Grotesk", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#020202"))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredConversations) { conversation in
                        ConversationListItem(conversation: conversation)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                                // Navigate to ChatView
                                onConversationSelected?(conversation)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Filtered Conversations
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        } else {
            return viewModel.conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.custom("Overused Grotesk", size: 60))
                .foregroundColor(.textTertiary)
            
            Text("No conversations yet")
                .font(.custom("Overused Grotesk", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text("Start a new conversation to see it here")
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Drawer Footer
    
    private var drawerFooter: some View {
        VStack(spacing: 0) {
            // Border top
            Rectangle()
                .fill(Color(hex: "000000").opacity(0.05))
                .frame(height: 1)
            
            // Content
            HStack(alignment: .center, spacing: 8) {
                // User avatar
                AsyncImage(url: URL(string: authViewModel.currentUser?.avatarURL ?? "")) { phase in
                    switch phase {
                    case .empty, .failure:
                        Circle()
                            .fill(Color(hex: "D9D9D9"))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(formatUserName(authViewModel.currentUser?.displayName ?? authViewModel.currentUser?.email ?? "U").prefix(1).uppercased())
                                    .font(.custom("Overused Grotesk", size: 14))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // User name - max 10 characters
                Text(formatUserName(authViewModel.currentUser?.displayName ?? authViewModel.currentUser?.email ?? "User"))
                    .font(.custom("Overused Grotesk", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image("settings_button_drawer")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 32, trailing: 16))
        }
        .background(Color.white)
        .sheet(isPresented: $showingSettings) {
            // TODO: Settings view
            Text("Settings")
        }
    }
    
    // MARK: - Format User Name
    
    /// Format user name: max 10 characters, add "..." if longer
    private func formatUserName(_ name: String) -> String {
        if name.count <= 10 {
            return name
        } else {
            return String(name.prefix(10)) + "..."
        }
    }
}

// MARK: - Conversation List Item

struct ConversationListItem: View {
    let conversation: Conversation
    @State private var firstMessageAttachment: FileAttachment?
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Icon/Thumbnail
            iconView
                .frame(width: 40, height: 40)
                .background(iconBackgroundColor)
                .cornerRadius(8)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "#020202"))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // File type
                    Text(fileTypeText)
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(Color(hex: "#717171"))
                        .fontWeight(.regular)
                    
                    // Dot separator
                    Circle()
                        .fill(Color.primaryOrange.opacity(0.2))
                        .frame(width: 4, height: 4)
                    
                    // Time
                    Text(formatTime(conversation.updatedAt))
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(Color(hex: "#717171"))
                        .fontWeight(.regular)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .task {
            await loadFirstMessageAttachment()
        }
    }
    
    // MARK: - Icon View
    
    @ViewBuilder
    private var iconView: some View {
        if let attachment = firstMessageAttachment {
            switch attachment.type {
            case .video:
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "video.fill")
                        .foregroundColor(.textTertiary)
                        .frame(width: 40, height: 40)
                        .onAppear {
                            extractVideoThumbnail(from: attachment.url)
                        }
                }
            case .audio:
                Image("audio_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            case .image:
                AsyncImage(url: URL(string: attachment.url)) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "photo.fill")
                            .foregroundColor(.textTertiary)
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo.fill")
                            .foregroundColor(.textTertiary)
                            .frame(width: 40, height: 40)
                    @unknown default:
                        EmptyView()
                    }
                }
            case .other:
                Image(systemName: "doc.fill")
                    .foregroundColor(.textTertiary)
                    .frame(width: 40, height: 40)
            }
        } else {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(.textTertiary)
                .frame(width: 40, height: 40)
        }
    }
    
    // MARK: - Icon Background Color
    
    private var iconBackgroundColor: Color {
        // Nếu có attachment và là video/image thì không cần background (thumbnail sẽ fill)
        if let attachment = firstMessageAttachment {
            switch attachment.type {
            case .video, .image:
                return Color.clear
            default:
                return Color.white
            }
        }
        return Color.white
    }
    
    // MARK: - File Type Text
    
    private var fileTypeText: String {
        guard let attachment = firstMessageAttachment else {
            return "Chat"
        }
        
        switch attachment.type {
        case .video:
            // Check if URL contains youtube.com or x.com/twitter.com
            if attachment.url.contains("youtube.com") || attachment.url.contains("youtu.be") {
                return "Youtube"
            } else if attachment.url.contains("x.com") || attachment.url.contains("twitter.com") {
                return "X"
            } else {
                return "MP4"
            }
        case .audio:
            let ext = (attachment.name as NSString).pathExtension.uppercased()
            return ext.isEmpty ? "MP3" : ext
        case .image:
            return "Image"
        case .other:
            return "File"
        }
    }
    
    // MARK: - Load First Message Attachment
    
    private func loadFirstMessageAttachment() async {
        do {
            let messages = try await SupabaseService.shared.fetchMessages(conversationId: conversation.id)
            if let firstMessage = messages.first, let attachment = firstMessage.attachment {
                await MainActor.run {
                    firstMessageAttachment = attachment
                }
            }
        } catch {
            print("❌ Error loading first message: \(error)")
        }
    }
    
    // MARK: - Extract Video Thumbnail
    
    private func extractVideoThumbnail(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid video URL: \(urlString)")
            return
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    videoThumbnail = uiImage
                }
            } catch {
                print("❌ Failed to extract video thumbnail: \(error)")
                await MainActor.run {
                    videoThumbnail = nil
                }
            }
        }
    }
    
    // MARK: - Format Time
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let hoursAgo = calendar.dateComponents([.hour], from: date, to: now).hour ?? 0
            if hoursAgo < 1 {
                let minutesAgo = calendar.dateComponents([.minute], from: date, to: now).minute ?? 0
                if minutesAgo < 1 {
                    return "Just now"
                } else {
                    return "\(minutesAgo) \(minutesAgo == 1 ? "minute" : "minutes") ago"
                }
            } else {
                return "\(hoursAgo) \(hoursAgo == 1 ? "hour" : "hours") ago"
            }
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if daysAgo < 7 {
                return "\(daysAgo) \(daysAgo == 1 ? "day" : "days") ago"
            } else {
                let weeksAgo = daysAgo / 7
                if weeksAgo < 4 {
                    return "\(weeksAgo) \(weeksAgo == 1 ? "week" : "weeks") ago"
                } else {
                    let monthsAgo = calendar.dateComponents([.month], from: date, to: now).month ?? 0
                    if monthsAgo < 12 {
                        return "\(monthsAgo) \(monthsAgo == 1 ? "month" : "months") ago"
                    } else {
                        let yearsAgo = calendar.dateComponents([.year], from: date, to: now).year ?? 0
                        return "\(yearsAgo) \(yearsAgo == 1 ? "year" : "years") ago"
                    }
                }
            }
        }
    }
}

