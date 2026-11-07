import AppKit
import SwiftUI

struct ExpandedLyricsView: View {
  @ObservedObject var mediaManager = MediaManager.shared
  let mediaAccentColor: Color

  @State private var hoveredLineId: UUID? = nil
  @State private var isUserInteracting = false
  @State private var interactionResetTask: Task<Void, Never>? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      headerBar

      switch mediaManager.lyricsStatus {
      case .loading:
        loadingView
      case .instrumental:
        instrumentalView
      case .synced:
        if !mediaManager.syncedLyrics.isEmpty {
          syncedLyricsStream
        } else {
          unavailableLyricsView
        }
      case .unsynced:
        if !mediaManager.unsyncedLyrics.isEmpty {
          unsyncedLyricsStream
        } else {
          unavailableLyricsView
        }
      case .unavailable:
        unavailableLyricsView
      case .idle:
        if mediaManager.isLoadingLyrics {
          loadingView
        } else if !mediaManager.syncedLyrics.isEmpty {
          syncedLyricsStream
        } else if !mediaManager.unsyncedLyrics.isEmpty {
          unsyncedLyricsStream
        } else {
          unavailableLyricsView
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private var headerBar: some View {
    HStack(spacing: 4) {
      Image(systemName: "quote.bubble.fill")
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(mediaAccentColor)

      Text(L10n.Media.syncedLyricsTitle.uppercased())
        .font(.system(size: 8.5, weight: .bold, design: .rounded))
        .tracking(0.4)
        .foregroundColor(AppTheme.textSecondary)

      statusBadge

      Spacer(minLength: 4)
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    switch mediaManager.lyricsStatus {
    case .synced:
      HStack(spacing: 3) {
        Circle()
          .fill(mediaAccentColor)
          .frame(width: 4.5, height: 4.5)
        Text(L10n.Media.syncedLyricsBadge.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(mediaAccentColor)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(mediaAccentColor.opacity(0.12))
      .clipShape(Capsule())

    case .unsynced:
      HStack(spacing: 3) {
        Image(systemName: "text.alignleft")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.unsyncedLyricsBadge.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.accentAmber)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.accentAmber.opacity(0.14))
      .clipShape(Capsule())

    case .instrumental:
      HStack(spacing: 3) {
        Image(systemName: "music.quarternote.3")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.instrumental.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.accentCyan)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.accentCyan.opacity(0.12))
      .clipShape(Capsule())

    case .unavailable:
      HStack(spacing: 3) {
        Image(systemName: "nosign")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.noLyricsFound.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.textTertiary)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.badgeBackground)
      .clipShape(Capsule())

    default:
      EmptyView()
    }
  }

  private var syncedLyricsStream: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(alignment: .leading, spacing: 3) {
          ForEach(Array(mediaManager.syncedLyrics.enumerated()), id: \.element.id) { index, line in
            let isActive = index == mediaManager.currentLyricIndex
            let isPast = index < mediaManager.currentLyricIndex
            let isHovered = hoveredLineId == line.id

            lyricLineRow(
              line: line,
              index: index,
              isActive: isActive,
              isPast: isPast,
              isHovered: isHovered
            )
            .id(line.id)
          }
        }
        .padding(.vertical, 8)
      }
      .frame(height: 120)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.16),
            .init(color: .black, location: 0.84),
            .init(color: .clear, location: 1.0)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 1)
          .onChanged { _ in
            markUserInteraction()
          }
      )
      .onChange(of: mediaManager.currentLyricIndex) { _, newIndex in
        guard !isUserInteracting,
              newIndex >= 0 && newIndex < mediaManager.syncedLyrics.count else { return }
        let targetId = mediaManager.syncedLyrics[newIndex].id
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
          proxy.scrollTo(targetId, anchor: .center)
        }
      }
      .onAppear {
        if mediaManager.currentLyricIndex >= 0 && mediaManager.currentLyricIndex < mediaManager.syncedLyrics.count {
          let targetId = mediaManager.syncedLyrics[mediaManager.currentLyricIndex].id
          proxy.scrollTo(targetId, anchor: .center)
        }
      }
    }
  }

  private func markUserInteraction() {
    isUserInteracting = true
    interactionResetTask?.cancel()
    interactionResetTask = Task {
      try? await Task.sleep(nanoseconds: 4_500_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          isUserInteracting = false
        }
      }
    }
  }

  private func lyricLineRow(
    line: LyricLine,
    index: Int,
    isActive: Bool,
    isPast: Bool,
    isHovered: Bool
  ) -> some View {
    Button(action: {
      isUserInteracting = false
      interactionResetTask?.cancel()
      mediaManager.seek(to: line.time)
    }) {
      HStack(alignment: .center, spacing: 8) {
        if isActive {
          Capsule()
            .fill(mediaAccentColor)
            .frame(width: 3, height: 14)
            .transition(.scale.combined(with: .opacity))
        } else {
          Color.clear
            .frame(width: 3, height: 14)
        }

        Text(line.text)
          .font(.system(
            size: isActive ? 13 : 11.5,
            weight: isActive ? .bold : (isPast ? .medium : .semibold),
            design: .rounded
          ))
          .foregroundColor(
            isActive
              ? AppTheme.textPrimary
              : (isHovered
                ? AppTheme.textPrimary
                : (isPast ? AppTheme.textTertiary : AppTheme.textSecondary))
          )
          .multilineTextAlignment(.leading)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        if isHovered {
          Text(formatTimestamp(line.time))
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .foregroundColor(mediaAccentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(mediaAccentColor.opacity(0.14))
            .cornerRadius(4)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, isActive ? 3 : 2)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(
            isActive
              ? AppTheme.badgeBackground
              : (isHovered ? AppTheme.badgeBackground.opacity(0.6) : Color.clear)
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        hoveredLineId = line.id
        NSCursor.pointingHand.push()
      } else {
        if hoveredLineId == line.id {
          hoveredLineId = nil
        }
        NSCursor.pop()
      }
    }
  }

  private func formatTimestamp(_ time: TimeInterval) -> String {
    TimeFormatting.clock(time, includeHours: false)
  }

  private var loadingView: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
      Text(L10n.Media.loadingLyrics)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
      Spacer(minLength: 4)
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var unsyncedLyricsStream: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "info.circle.fill")
          .font(.system(size: 8.5))
          .foregroundColor(AppTheme.accentAmber)
        Text(L10n.Media.unsyncedLyricsNotice)
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }
      .padding(.vertical, 2)

      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(mediaManager.unsyncedLyrics.enumerated()), id: \.offset) { _, line in
            Text(line)
              .font(.system(size: 11.5, weight: .regular, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.vertical, 2)
      }
      .frame(height: 130)
    }
  }

  private var instrumentalView: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.accentCyan.opacity(0.12))
          .frame(width: 28, height: 28)

        Image(systemName: "music.quarternote.3")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.accentCyan)
      }

      VStack(alignment: .leading, spacing: 1.5) {
        Text(L10n.Media.instrumental)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)

        Text(L10n.Media.instrumentalDesc)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(2)
      }

      Spacer(minLength: 4)
    }
    .padding(.vertical, 6)
  }

  private var unavailableLyricsView: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .frame(width: 28, height: 28)

        Image(systemName: "quote.bubble")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.textTertiary)
      }

      VStack(alignment: .leading, spacing: 1.5) {
        Text(L10n.Media.lyricsUnavailable)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)

        Text(L10n.Media.lyricsUnavailableDesc)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(2)
      }

      Spacer(minLength: 4)

      Button(action: {
        mediaManager.refetchLyrics()
      }) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(mediaAccentColor)
          .frame(width: 24, height: 24)
          .background(mediaAccentColor.opacity(0.12))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .help("Retry lyrics fetch")
    }
    .padding(.vertical, 6)
  }
}
