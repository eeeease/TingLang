import AppKit
import SwiftUI

struct CaptionLine: Identifiable, Equatable {
  let id: String
  var text: String
  var translation: String?
  var isFinal: Bool
}

/// The panel's look, mirrored from Dart's CaptionStyle (colours 0xAARRGGBB).
struct PanelStyle: Equatable, Codable {
  var fontSize: Double = 22
  var backgroundOpacity: Double = 0.78
  var showTranslation = true
  var clickThrough = false
  var mode = "card"
  var background = "glass"
  var backgroundColor: Int64 = 0xFF1E_1E1D
  var textColor: Int64 = 0xFFF7_F7F6
  var translationColor: Int64 = 0xFFB9_B9B5
  var accentColor: Int64 = 0xFFFF_8A4C
  var fontWeight: Int64 = 500
  var outline = true
  var maxLines: Int64 = 2
  var alignment = "center"
  var layout = "stacked"
  var scrollbackLines: Int64 = 100

  init() {}

  init(_ config: OverlayConfig) {
    fontSize = config.fontSize
    backgroundOpacity = config.backgroundOpacity
    showTranslation = config.showTranslation
    clickThrough = config.clickThrough
    mode = config.mode
    background = config.background
    backgroundColor = config.backgroundColor
    textColor = config.textColor
    translationColor = config.translationColor
    accentColor = config.accentColor
    fontWeight = config.fontWeight
    outline = config.outline
    maxLines = config.maxLines
    alignment = config.alignment
    layout = config.layout
    scrollbackLines = config.scrollbackLines
  }

  var isTextOnly: Bool { mode == "text" }
  var isSideBySide: Bool { layout == "sideBySide" }

  var json: String {
    guard let data = try? JSONEncoder().encode(self) else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
  }
}

/// Lines of the current session kept for scrolling back, newest last. The
/// engine sends its newest lines (at most 30) at up to 10 Hz; lines beyond
/// [limit] leave the panel (the database keeps everything).
struct CaptionBuffer {
  private(set) var lines: [CaptionLine] = []
  var limit = 100 {
    didSet { trim() }
  }

  mutating func merge(_ snapshot: [CaptionLine]) {
    for line in snapshot {
      if let index = lines.lastIndex(where: { $0.id == line.id }) {
        if lines[index] != line { lines[index] = line }
      } else {
        lines.append(line)
      }
    }
    trim()
  }

  private mutating func trim() {
    if lines.count > limit { lines.removeFirst(lines.count - limit) }
  }
}

enum PanelPhase: String {
  case idle, preparing, needsSetup, listening, stopping, saved, error, notice
}

/// What a control under the pointer is for, shown above the panel after a
/// moment (see CaptionOverlayController's hints).
struct PanelHint: Equatable {
  let id: String
  let text: String
  /// The control's frame in the panel's content, top-left origin.
  let frame: CGRect
}

/// Everything the panel draws. Captions and level arrive from the engine at
/// up to 10 Hz; state, style and strings arrive from Dart.
@MainActor
@Observable
final class PanelModel {
  /// The lines drawn. While the reader scrolls back ([following] is false)
  /// this list stops growing, so nothing moves under them; lines already shown
  /// still get their translations, and [pendingLines] counts the new ones.
  var lines: [CaptionLine] = []
  var following = true
  var pendingLines = 0
  @ObservationIgnored private var buffer = CaptionBuffer()
  var awaitingTranslation = false
  var level: Double = 0

  var phase: PanelPhase = .idle
  var source = "system"
  var startedAt: Date?
  var message: String?
  var action: String?
  var actionLabel: String?
  var progress: Double?
  var dueCount = 0
  var newRecordings = 0
  var sessionId: String?
  var summary: String?
  var canStart = true

  var style = PanelStyle()
  var strings: [String: String] = [:]
  var translatingLabel = "…"

  var isDropTarget = false
  var showAppearance = false
  /// The pointer is over a locked panel (which cannot see hover itself).
  var pointerInside = false
  /// Width of the caption area while listening; the user drags its edge.
  /// Side by side keeps its own, wider one.
  var captionWidth: CGFloat = 640
  var sideBySideWidth: CGFloat = 880
  /// The pointer entered a control (its hint) or left the control with this id
  /// (nil). Set by the controller, which shows the hint.
  @ObservationIgnored var onHint: (PanelHint?, String) -> Void = { _, _ in }

  func text(_ key: String, _ fallback: String) -> String { strings[key] ?? fallback }

  var isListening: Bool { phase == .listening || phase == .stopping }

  var width: CGFloat {
    get { style.isSideBySide ? sideBySideWidth : captionWidth }
    set {
      if style.isSideBySide { sideBySideWidth = newValue } else { captionWidth = newValue }
    }
  }
  /// Clicks pass through to the window below; only while captions run, so
  /// the idle pill can always start them.
  var isLocked: Bool { style.clickThrough && isListening }

  func receive(_ snapshot: [CaptionLine]) {
    buffer.merge(snapshot)
    if following {
      if lines != buffer.lines { lines = buffer.lines }
      return
    }
    var shown = lines
    for line in snapshot {
      if let index = shown.lastIndex(where: { $0.id == line.id }), shown[index] != line { shown[index] = line }
    }
    if shown != lines { lines = shown }
    let ids = Set(lines.map(\.id))
    pendingLines = buffer.lines.reduce(0) { $0 + (ids.contains($1.id) ? 0 : 1) }
  }

  func setScrollback(_ limit: Int64) {
    // Never below the engine's 30, or a trimmed line could come back.
    buffer.limit = Int(max(30, min(1000, limit)))
    if following { lines = buffer.lines }
  }

  func follow() {
    following = true
    pendingLines = 0
    lines = buffer.lines
  }

  func stopFollowing() {
    following = false
  }

  func clearCaptions() {
    let limit = buffer.limit
    buffer = CaptionBuffer()
    buffer.limit = limit
    lines = []
    following = true
    pendingLines = 0
  }
}

extension Color {
  init(argb: Int64) {
    let value = UInt32(truncatingIfNeeded: argb)
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: Double((value >> 24) & 0xFF) / 255)
  }
}

extension Font.Weight {
  init(css: Int64) {
    switch css {
    case ..<450: self = .regular
    case ..<550: self = .medium
    case ..<650: self = .semibold
    default: self = .bold
    }
  }
}

/// Root view: a pill while idle, captions while listening.
struct CapturePanelView: View {
  @Bindable var model: PanelModel
  let send: (String, String?) -> Void
  let changeStyle: (PanelStyle) -> Void
  /// Moves the window with the pointer by the drag so far; nil when it ends.
  let moveWindow: (CGSize?) -> Void
  @State private var hovering = false

  var body: some View {
    Group {
      if model.isListening {
        // A locked panel sees no hover events; the controller tracks the pointer.
        ListeningView(
          model: model, hovering: model.isLocked ? model.pointerInside : hovering, send: send,
          changeStyle: changeStyle)
      } else {
        PillView(model: model, send: send, changeStyle: changeStyle)
      }
    }
    .overlay {
      if model.isDropTarget {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .strokeBorder(Color(argb: model.style.accentColor), lineWidth: 2)
          .overlay {
            Text(model.text("dropHint", "Drop to import and transcribe"))
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(Color(argb: model.style.accentColor))
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(Capsule().fill(.black.opacity(0.75)))
          }
      }
    }
    .onHover { hovering = $0 }
    // Drag anywhere that is not a control to move the panel. (A borderless
    // window's "movable by background" does not reach SwiftUI content.) The
    // captions' scroll view is handled by CapturePanelWindow.sendEvent.
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .global)
        .onChanged { value in moveWindow(value.translation) }
        .onEnded { _ in moveWindow(nil) }
    )
    .environment(\.colorScheme, .dark)
    .fixedSize()
  }
}

// MARK: - Idle pill

private struct PillView: View {
  @Bindable var model: PanelModel
  let send: (String, String?) -> Void
  let changeStyle: (PanelStyle) -> Void

  private var accent: Color { Color(argb: model.style.accentColor) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        RecordButton(model: model, size: 36) { send("toggle", nil) }
        if model.message == nil || model.phase == .saved {
          SourceMenu(model: model, send: send)
        }
        if model.newRecordings > 0 {
          Button {
            send("showRecordings", nil)
          } label: {
            Text(
              model.text("newRecordings", "{n} new recordings")
                .replacingOccurrences(of: "{n}", with: "\(model.newRecordings)")
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(accent.opacity(0.16)))
          }
          .buttonStyle(.plain)
        }
        Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 22)
        HistoryButton(model: model) { send("openHistory", nil) }
        BrandMenu(model: model, send: send)
          .popover(isPresented: $model.showAppearance, arrowEdge: .top) {
            AppearanceControls(model: model, changeStyle: changeStyle, send: send)
          }
      }
      // The two round buttons at the ends sit concentric with the pill's corners.
      .padding(.horizontal, 8)
      .frame(height: 52)
      if let message = model.message, model.phase != .idle {
        StatusRow(model: model, message: message, send: send)
          .padding(.horizontal, 14)
          .padding(.bottom, 12)
      }
    }
    .frame(minWidth: 300, alignment: .leading)
    .background(PanelBackground(style: model.style, forceVisible: true, cornerRadius: 26))
    .animation(.snappy(duration: 0.22), value: model.phase)
  }
}

/// Setup, error and "saved" messages with at most two buttons.
private struct StatusRow: View {
  @Bindable var model: PanelModel
  let message: String
  let send: (String, String?) -> Void

  private var accent: Color { Color(argb: model.style.accentColor) }

  var body: some View {
    HStack(spacing: 10) {
      if model.phase == .error {
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
      } else if model.phase == .saved {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
      } else if model.phase == .preparing {
        ProgressView(value: model.progress).progressViewStyle(.circular).controlSize(.small)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(message).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.92))
        if let summary = model.summary {
          Text(summary).font(.system(size: 12).monospacedDigit()).foregroundStyle(.white.opacity(0.6))
        }
      }
      .frame(maxWidth: 320, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      if model.phase == .saved, let id = model.sessionId {
        PillButton(title: model.text("view", "View"), prominent: false, accent: accent) {
          send("openSession", id)
        }
        PillButton(title: model.text("makeCourse", "Make course"), prominent: true, accent: accent) {
          send("makeCourse", id)
        }
      } else if let action = model.action, let label = model.actionLabel {
        PillButton(title: label, prominent: true, accent: accent) { send(action, nil) }
      }
    }
  }
}

// MARK: - Listening

private struct ListeningView: View {
  @Bindable var model: PanelModel
  let hovering: Bool
  let send: (String, String?) -> Void
  let changeStyle: (PanelStyle) -> Void

  private var style: PanelStyle { model.style }
  private var showsChrome: Bool { !style.isTextOnly || hovering || model.showAppearance }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ListeningHeader(model: model, send: send, changeStyle: changeStyle)
        .opacity(showsChrome ? 1 : 0)
        .allowsHitTesting(showsChrome)
      // Why there is no translation, or why macOS may ask for screen
      // recording; shown with the chrome.
      if let notice = model.message, model.phase == .listening {
        Text(notice)
          .font(.system(size: 11.5, weight: .medium))
          .foregroundStyle(.white.opacity(0.62))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .opacity(showsChrome ? 1 : 0)
      }
      CaptionsView(model: model)
    }
    .padding(.horizontal, 18)
    .padding(.top, 10)
    .padding(.bottom, 14)
    .frame(width: model.width, alignment: .leading)
    .background(
      PanelBackground(
        style: style,
        forceVisible: showsChrome,
        cornerRadius: 22)
    )
    .overlay(alignment: .trailing) { WidthGrip(model: model) }
    .animation(.easeOut(duration: 0.18), value: showsChrome)
  }
}

private struct ListeningHeader: View {
  @Bindable var model: PanelModel
  let send: (String, String?) -> Void
  let changeStyle: (PanelStyle) -> Void

  private var accent: Color { Color(argb: model.style.accentColor) }

  var body: some View {
    HStack(spacing: 10) {
      LiveDot(color: accent, active: model.phase == .listening)
      Text(
        model.phase == .stopping
          ? model.text("saving", "Saving…")
          : "\(model.text("listening", "Listening")) · \(model.text(model.source == "microphone" ? "sourceMic" : "sourceSystem", model.source))"
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.white.opacity(0.75))
      .lineLimit(1)
      if let startedAt = model.startedAt {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
          Text(elapsed(from: startedAt, to: context.date))
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      LevelBars(level: model.level, color: accent)
      Spacer(minLength: 12)
      if model.isLocked {
        // Nothing here can be clicked while locked: say so instead. The
        // unlock chip appears above the panel when the pointer rests on it.
        Label(model.text("locked", "Locked · clicks pass through"), systemImage: "lock.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accent)
          .lineLimit(1)
      } else {
        IconButton(systemName: "paintpalette", help: model.text("appearance", "Appearance"), model: model) {
          model.showAppearance.toggle()
        }
        .popover(isPresented: $model.showAppearance, arrowEdge: .top) {
          AppearanceControls(model: model, changeStyle: changeStyle, send: send)
        }
        IconButton(systemName: "lock.open", help: model.text("lock", "Lock and click through"), model: model) {
          var next = model.style
          next.clickThrough = true
          changeStyle(next)
        }
        IconButton(
          systemName: "clock.arrow.circlepath", help: model.text("history", "History and review"), model: model
        ) {
          send("openHistory", nil)
        }
        RecordButton(model: model, size: 28) { send("toggle", nil) }
      }
    }
    .frame(height: 28)
  }

  private func elapsed(from start: Date, to now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
  }
}

/// A caption area of fixed height ([PanelStyle.maxLines] rows at the current
/// size) that scrolls. It follows the newest line until the reader scrolls
/// back; then it stays put and offers "back to latest".
private struct CaptionsView: View {
  @Bindable var model: PanelModel

  private static let rowSpacing: CGFloat = 8
  private var style: PanelStyle { model.style }
  private var accent: Color { Color(argb: style.accentColor) }

  /// Height of the caption area. Rows that wrap need more room and scroll.
  static func height(for style: PanelStyle) -> CGFloat {
    let rows = CGFloat(max(1, min(3, style.maxLines)))
    let line = style.fontSize * 1.3
    let row = style.isSideBySide || !style.showTranslation ? line : line + line * 0.72 + 2
    return rows * row + (rows - 1) * rowSpacing
  }

  var body: some View {
    let alignment: HorizontalAlignment = style.alignment == "center" && !style.isSideBySide ? .center : .leading
    let content = VStack(alignment: alignment, spacing: Self.rowSpacing) {
      if model.lines.isEmpty {
        CaptionText(
          string: model.text("waiting", "Waiting for speech…"), style: style, size: style.fontSize * 0.8,
          emphasis: 0.45)
      }
      let newestId = model.lines.last?.id
      ForEach(model.lines) { line in
        CaptionRow(
          line: line, style: style,
          emphasis: line.id == newestId ? (line.isFinal ? 1 : 0.88) : (model.following ? 0.62 : 0.85),
          translating: line.isFinal && model.awaitingTranslation ? model.translatingLabel : nil
        )
        .equatable()
        .id(line.id)
      }
    }
    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))

    Group {
      if #available(macOS 15, *) {
        FollowingScrollView(model: model) { content }
      } else {
        // Live captions need macOS 26; this only keeps older systems building.
        ScrollViewReader { proxy in
          ScrollView(.vertical) { content }
            .onChange(of: model.lines) { _, lines in
              if let id = lines.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
      }
    }
    .scrollIndicators(style.isTextOnly ? .never : .automatic)
    .frame(height: Self.height(for: style))
    // Lines leaving at the top fade out instead of being cut.
    .mask {
      VStack(spacing: 0) {
        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 10)
        Color.black
      }
    }
    .overlay {
      if style.isSideBySide {
        Rectangle().fill(.white.opacity(0.14)).frame(width: 1).allowsHitTesting(false)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if !model.following { jumpButton }
    }
    .transaction { $0.animation = nil }
  }

  private var jumpButton: some View {
    Button {
      model.follow()
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "arrow.down")
        Text(
          model.pendingLines > 0
            ? "\(model.text("jumpToLatest", "Back to latest")) · \(model.text("newLines", "{n} new").replacingOccurrences(of: "{n}", with: "\(model.pendingLines)"))"
            : model.text("jumpToLatest", "Back to latest"))
      }
      .font(.system(size: 12, weight: .semibold))
      .lineLimit(1)
      .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0.03))
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(Capsule().fill(accent))
      .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }
    .buttonStyle(.plain)
    .padding(4)
  }
}

/// How far the captions are scrolled, as far as following is concerned.
private struct CaptionScroll: Equatable {
  var contentHeight: CGFloat
  /// Content below the visible area (≤ 0 at the bottom).
  var below: CGFloat
}

/// Scrolls to the newest line whenever the content grows while following. A
/// move without the content changing size is the reader scrolling: away from
/// the bottom stops following, back to the bottom resumes it.
@available(macOS 15, *)
private struct FollowingScrollView<Content: View>: View {
  @Bindable var model: PanelModel
  @ViewBuilder let content: () -> Content
  @State private var position = ScrollPosition(edge: .bottom)

  var body: some View {
    ScrollView(.vertical) { content() }
      .scrollPosition($position)
      .defaultScrollAnchor(.bottom)
      .onScrollGeometryChange(for: CaptionScroll.self) { geometry in
        CaptionScroll(
          contentHeight: geometry.contentSize.height,
          below: geometry.contentSize.height - geometry.visibleRect.maxY)
      } action: { old, new in
        if abs(new.contentHeight - old.contentHeight) > 0.5 {
          if model.following { position.scrollTo(edge: .bottom) }
          return
        }
        let atBottom = new.below <= 6
        if atBottom && !model.following {
          model.follow()
        } else if !atBottom && model.following {
          model.stopFollowing()
        }
      }
      .onChange(of: model.following) { _, following in
        if following { position.scrollTo(edge: .bottom) }
      }
      .modifier(NoScrollEdgeEffect())
  }
}

/// macOS 26 fades scroll edges with a visible band; captions sit on their own
/// background and do not need it.
private struct NoScrollEdgeEffect: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 26, *) {
      content.scrollEdgeEffectHidden(true, for: .all)
    } else {
      content
    }
  }
}

/// One line: the translation below it, or beside it in the side-by-side layout.
private struct CaptionRow: View, Equatable {
  let line: CaptionLine
  let style: PanelStyle
  let emphasis: Double
  /// Placeholder while a final line waits for its translation.
  let translating: String?

  var body: some View {
    let translationColor = Color(argb: style.translationColor)
    if style.isSideBySide {
      SideBySideRow(spacing: 28) {
        CaptionText(string: line.text, style: style, size: style.fontSize, emphasis: emphasis)
        if let translation = line.translation {
          CaptionText(
            string: translation, style: style, size: style.fontSize * 0.86, emphasis: max(emphasis, 0.7),
            color: translationColor)
        } else if let translating {
          CaptionText(string: translating, style: style, size: style.fontSize * 0.86, emphasis: 0.4)
        } else {
          Color.clear.frame(height: 1)
        }
      }
    } else {
      let alignment: HorizontalAlignment = style.alignment == "center" ? .center : .leading
      VStack(alignment: alignment, spacing: 2) {
        CaptionText(string: line.text, style: style, size: style.fontSize, emphasis: emphasis)
        if style.showTranslation {
          if let translation = line.translation {
            CaptionText(
              string: translation, style: style, size: style.fontSize * 0.72, emphasis: max(emphasis, 0.7),
              color: translationColor)
          } else if let translating {
            CaptionText(string: translating, style: style, size: style.fontSize * 0.72, emphasis: 0.4)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }
  }
}

/// Recognised text left, translation right, in two equal columns. A
/// translation no taller than its line sits on the line's last baseline, so a
/// short Chinese line is read next to the end of a long English one; a taller
/// one starts at the top and the row grows to fit it. The recognised text
/// never moves when its translation arrives.
private struct SideBySideRow: Layout {
  let spacing: CGFloat

  private struct Placement {
    var column: CGFloat?
    var size: CGSize
    var translationY: CGFloat
  }

  private func placement(width: CGFloat?, subviews: Subviews) -> Placement {
    guard subviews.count == 2 else { return Placement(column: nil, size: .zero, translationY: 0) }
    let column = width.flatMap { $0.isFinite ? max(0, ($0 - spacing) / 2) : nil }
    let proposal = ProposedViewSize(width: column, height: nil)
    let text = subviews[0].dimensions(in: proposal)
    let translation = subviews[1].dimensions(in: proposal)
    let y =
      translation.height <= text.height
      ? max(0, text[VerticalAlignment.lastTextBaseline] - translation[VerticalAlignment.lastTextBaseline]) : 0
    return Placement(
      column: column,
      size: CGSize(
        width: column.map { $0 * 2 + spacing } ?? text.width + spacing + translation.width,
        height: max(text.height, y + translation.height)),
      translationY: y)
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    placement(width: proposal.width, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let layout = placement(width: bounds.width, subviews: subviews)
    guard let column = layout.column else { return }
    let columnProposal = ProposedViewSize(width: column, height: nil)
    subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: columnProposal)
    subviews[1].place(
      at: CGPoint(x: bounds.minX + column + spacing, y: bounds.minY + layout.translationY), anchor: .topLeading,
      proposal: columnProposal)
  }
}

private struct CaptionText: View {
  let string: String
  let style: PanelStyle
  let size: Double
  let emphasis: Double
  var color: Color?

  var body: some View {
    let text = Text(string)
      .font(.system(size: size, weight: Font.Weight(css: style.fontWeight)))
      .foregroundStyle((color ?? Color(argb: style.textColor)).opacity(emphasis))
      .multilineTextAlignment(style.alignment == "center" && !style.isSideBySide ? .center : .leading)
      .fixedSize(horizontal: false, vertical: true)
    if style.outline {
      text
        .shadow(color: .black.opacity(0.85), radius: 0.6)
        .shadow(color: .black.opacity(0.85), radius: 0.6)
        .shadow(color: .black.opacity(0.45), radius: 3)
    } else {
      text
    }
  }
}

/// Drag the right edge to make the caption area wider or narrower.
private struct WidthGrip: View {
  @Bindable var model: PanelModel
  @State private var startWidth: CGFloat?

  var body: some View {
    Color.clear
      .frame(width: 10)
      .contentShape(Rectangle())
      .onHover { inside in
        (inside ? NSCursor.resizeLeftRight : NSCursor.arrow).set()
      }
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { value in
            let base = startWidth ?? model.width
            startWidth = base
            model.width = min(1400, max(360, base + value.translation.width * 2))
          }
          .onEnded { _ in
            startWidth = nil
            UserDefaults.standard.set(
              Double(model.width),
              forKey: model.style.isSideBySide
                ? CaptionOverlayController.sideBySideWidthKey : CaptionOverlayController.widthKey)
          }
      )
  }
}

// MARK: - Appearance

/// Desktop-lyrics style controls: mode, background, colours, size, lines.
private struct AppearanceControls: View {
  @Bindable var model: PanelModel
  let changeStyle: (PanelStyle) -> Void
  let send: (String, String?) -> Void

  private static let backgroundSwatches: [Int64] = [
    0xFF1E_1E1D, 0xFF2B_2A28, 0xFF14_202E, 0xFF3A_1F12, 0xFFF7_F7F6,
  ]
  private static let textSwatches: [Int64] = [
    0xFFF7_F7F6, 0xFF17_1716, 0xFFFF_B98A, 0xFF9C_EAC8, 0xFFFF_E16B,
  ]
  private static let translationSwatches: [Int64] = [
    0xFFB9_B9B5, 0xFFFF_B98A, 0xFF9C_EAC8, 0xFF8F_C8FF, 0xFFF7_F7F6,
  ]

  private var style: PanelStyle { model.style }

  private func update(_ change: (inout PanelStyle) -> Void) {
    var next = model.style
    change(&next)
    changeStyle(next)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      row(model.text("display", "Display")) {
        Picker("", selection: binding(\.mode)) {
          Text(model.text("modeCard", "Card")).tag("card")
          Text(model.text("modeText", "Text only")).tag("text")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      row(model.text("layout", "Layout")) {
        Picker("", selection: binding(\.layout)) {
          Text(model.text("layoutStacked", "Stacked")).tag("stacked")
          Text(model.text("layoutSideBySide", "Side by side")).tag("sideBySide")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      row(model.text("background", "Background")) {
        Picker("", selection: binding(\.background)) {
          Text(model.text("bgGlass", "Glass")).tag("glass")
          Text(model.text("bgSolid", "Solid")).tag("solid")
          Text(model.text("bgClear", "None")).tag("clear")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      if style.background != "clear" {
        row(model.text("opacity", "Opacity")) {
          Slider(value: binding(\.backgroundOpacity), in: 0.2...1)
        }
      }
      if style.background == "solid" {
        row(model.text("backgroundColor", "Colour")) {
          Swatches(colors: Self.backgroundSwatches, selected: style.backgroundColor) { color in
            update { $0.backgroundColor = color }
          }
        }
      }
      row(model.text("textColor", "Text")) {
        Swatches(colors: Self.textSwatches, selected: style.textColor) { color in
          update { $0.textColor = color }
        }
      }
      row(model.text("translationColor", "Translation")) {
        Swatches(colors: Self.translationSwatches, selected: style.translationColor) { color in
          update { $0.translationColor = color }
        }
      }
      row(model.text("fontSize", "Size")) {
        HStack(spacing: 8) {
          IconButton(systemName: "textformat.size.smaller", help: "") {
            update { $0.fontSize = max(14, $0.fontSize - 2) }
          }
          Text("\(Int(style.fontSize))").font(.system(size: 13).monospacedDigit()).frame(width: 26)
          IconButton(systemName: "textformat.size.larger", help: "") {
            update { $0.fontSize = min(48, $0.fontSize + 2) }
          }
          Spacer()
          Picker("", selection: binding(\.fontWeight)) {
            Text(model.text("weightRegular", "Regular")).tag(Int64(400))
            Text(model.text("weightMedium", "Medium")).tag(Int64(500))
            Text(model.text("weightBold", "Bold")).tag(Int64(700))
          }
          .labelsHidden()
          .frame(width: 96)
        }
      }
      row(model.text("lines", "Lines")) {
        Picker("", selection: binding(\.maxLines)) {
          Text("1").tag(Int64(1))
          Text("2").tag(Int64(2))
          Text("3").tag(Int64(3))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      VStack(alignment: .leading, spacing: 8) {
        // Side by side always shows the translation column.
        Toggle(model.text("showTranslation", "Show translation"), isOn: binding(\.showTranslation))
          .disabled(style.isSideBySide)
        Toggle(model.text("outline", "Outline text"), isOn: binding(\.outline))
        Toggle(
          model.text("center", "Centre lines"),
          isOn: Binding(
            get: { style.alignment == "center" },
            set: { on in update { $0.alignment = on ? "center" : "leading" } }))
        .disabled(style.isSideBySide)
        Toggle(
          model.text("lockToggle", "Lock while captioning (clicks pass through)"),
          isOn: Binding(
            get: { style.clickThrough },
            set: { on in
              // A locked panel cannot use this popover any more.
              if on && model.isListening { model.showAppearance = false }
              update { $0.clickThrough = on }
            }))
      }
      .toggleStyle(.switch)
      .controlSize(.small)
      Divider()
      HStack {
        Button(model.text("resetPosition", "Reset position")) { send("resetPosition", nil) }
        Spacer()
      }
      .buttonStyle(.borderless)
      .font(.system(size: 12))
    }
    .font(.system(size: 13))
    .padding(16)
    .frame(width: 320)
    .tint(Color(argb: model.style.accentColor))
  }

  private func binding<Value>(_ path: WritableKeyPath<PanelStyle, Value>) -> Binding<Value> {
    Binding(get: { model.style[keyPath: path] }, set: { value in update { $0[keyPath: path] = value } })
  }

  private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
      content()
    }
  }
}

private struct Swatches: View {
  let colors: [Int64]
  let selected: Int64
  let pick: (Int64) -> Void

  var body: some View {
    HStack(spacing: 8) {
      ForEach(colors, id: \.self) { color in
        Button {
          pick(color)
        } label: {
          Circle()
            .fill(Color(argb: color))
            .frame(width: 20, height: 20)
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .overlay(
              Circle().strokeBorder(.white, lineWidth: 2).padding(-3).opacity(color == selected ? 1 : 0))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 2)
  }
}

// MARK: - Controls

/// The one big button: start (mic glyph), preparing (ring), stop (square).
private struct RecordButton: View {
  @Bindable var model: PanelModel
  let size: CGFloat
  let action: () -> Void
  @State private var hovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var accent: Color { Color(argb: model.style.accentColor) }

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .fill(model.isListening ? Color.white.opacity(hovering ? 0.18 : 0.12) : accent)
          .brightness(!model.isListening && hovering ? 0.06 : 0)
        if model.phase == .preparing {
          Circle()
            .trim(from: 0, to: model.progress ?? 0.25)
            .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(4)
        }
        if model.isListening {
          RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
            .fill(accent)
            .frame(width: size * 0.34, height: size * 0.34)
        } else {
          Image(systemName: "mic.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0.03))
        }
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleStyle(reduceMotion: reduceMotion))
    .disabled(!model.canStart || model.phase == .stopping)
    .opacity(model.canStart ? 1 : 0.5)
    .onHover { hovering = $0 }
    .panelHint(
      model.isListening
        ? model.text("hintStop", "Stop live captions (⌘⇧T)")
        : model.canStart
          ? model.text("hintRecord", "Start live captions (⌘⇧T)")
          : model.text("unavailable", "Live captions need macOS 26"),
      model: model)
  }
}

private struct PressScaleStyle: ButtonStyle {
  let reduceMotion: Bool
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
      .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

private struct SourceMenu: View {
  @Bindable var model: PanelModel
  let send: (String, String?) -> Void

  var body: some View {
    Menu {
      Button {
        send("useSystemAudio", nil)
      } label: {
        Label(model.text("sourceSystem", "System audio"), systemImage: "speaker.wave.2")
      }
      Button {
        send("useMicrophone", nil)
      } label: {
        Label(model.text("sourceMic", "Microphone"), systemImage: "mic")
      }
    } label: {
      HStack(spacing: 5) {
        Image(systemName: model.source == "microphone" ? "mic" : "speaker.wave.2")
        Text(model.text(model.source == "microphone" ? "sourceMic" : "sourceSystem", model.source))
        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).opacity(0.6)
      }
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.white.opacity(0.82))
      .padding(.horizontal, 8).padding(.vertical, 5)
      .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.0001)))
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
    .disabled(model.isListening)
  }
}

private struct HistoryButton: View {
  @Bindable var model: PanelModel
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Image(systemName: "clock.arrow.circlepath").font(.system(size: 15, weight: .medium))
        if model.dueCount > 0 {
          Text("\(model.dueCount)")
            .font(.system(size: 11, weight: .bold).monospacedDigit())
            .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0.03))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(Color(argb: model.style.accentColor)))
        }
      }
      .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
      .padding(.horizontal, 8).padding(.vertical, 6)
      .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hovering ? 0.1 : 0)))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .panelHint(model.text("history", "History and review"), model: model)
  }
}

/// The mark at the right end of the idle pill; it opens the app menu. Drawn
/// like the app icon (the mark on paper) and as big as the record button at
/// the other end, so both ends of the pill read as buttons.
private struct BrandMenu: View {
  @Bindable var model: PanelModel
  let send: (String, String?) -> Void
  @State private var hovering = false
  /// The menu opens on mouse-down, so the button never looks pressed by
  /// itself; it stays pressed while its menu is open instead.
  @State private var menuOpen = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The app icon's paper: brighter under the pointer, darker while pressed.
  private var paper: [Color] {
    if menuOpen { return [Color(argb: 0xFFEA_E6DE), Color(argb: 0xFFDC_D7CD)] }
    return hovering ? [.white, Color(argb: 0xFFF6_F4EF)] : [Color(argb: 0xFFFB_FAF7), Color(argb: 0xFFEF_ECE5)]
  }

  private func isOwnMenu(_ note: Notification) -> Bool {
    guard let menu = note.object as? NSMenu else { return false }
    let titles = Set(menu.items.map(\.title))
    return titles.contains(model.text("openApp", "Open main window"))
      && titles.contains(model.text("hidePanel", "Hide floating window"))
  }

  var body: some View {
    Menu {
      Button(model.text("appearance", "Appearance…")) { model.showAppearance = true }
      Button(model.text("openApp", "Open main window")) { send("openHistory", nil) }
      Button(model.text("settings", "Settings…")) { send("openSettings", nil) }
      Divider()
      Button(model.text("hidePanel", "Hide floating window")) { send("hide", nil) }
      Button(model.text("quit", "Quit")) { send("quit", nil) }
    } label: {
      ZStack {
        Circle().fill(LinearGradient(colors: paper, startPoint: .top, endPoint: .bottom))
        // Under the pointer: a ring in the record button's colour.
        Circle().strokeBorder(Color(argb: model.style.accentColor), lineWidth: 2).opacity(hovering ? 1 : 0)
        BrandMark(onDark: false).frame(width: 24, height: 18)
      }
      .frame(width: 36, height: 36)
      // Raised off the glass; lifted a little more under the pointer.
      .shadow(color: .black.opacity(hovering ? 0.45 : 0.3), radius: hovering ? 3 : 1.5, y: hovering ? 1.5 : 1)
      .scaleEffect(menuOpen && !reduceMotion ? 0.92 : 1)
      .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6), value: menuOpen)
      .contentShape(Circle())
    }
    .menuStyle(.button)
    .buttonStyle(PressScaleStyle(reduceMotion: reduceMotion))
    .menuIndicator(.hidden)
    .fixedSize()
    .onHover { hovering = $0 }
    .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { note in
      if isOwnMenu(note) { menuOpen = true }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { note in
      if isOwnMenu(note) { menuOpen = false }
    }
    .accessibilityLabel(Text(model.text("appName", "TingLang")))
    .panelHint(model.text("hintMenu", "TingLang menu: open the app, appearance, settings"), model: model)
  }
}

/// Names a control after the pointer rests on it. SwiftUI's `.help` uses AppKit
/// tooltips, which do not appear while the app is in the background, and the
/// non-activating panel is mostly used while another app is in front; so the
/// panel shows its own hint window (CaptionOverlayController). Hover itself
/// works there: SwiftUI's tracking area is active always.
private struct PanelHintModifier: ViewModifier {
  let text: String
  let model: PanelModel
  @State private var id = UUID().uuidString
  @State private var frame = CGRect.zero
  @State private var inside = false

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
      .onHover { inside in
        self.inside = inside
        model.onHint(inside ? PanelHint(id: id, text: text, frame: frame) : nil, id)
      }
      .onChange(of: text) { _, text in
        if inside { model.onHint(PanelHint(id: id, text: text, frame: frame), id) }
      }
      .onDisappear {
        if inside { model.onHint(nil, id) }
        inside = false
      }
      .accessibilityHint(Text(text))
  }
}

extension View {
  fileprivate func panelHint(_ text: String, model: PanelModel) -> some View {
    modifier(PanelHintModifier(text: text, model: model))
  }
}

private struct IconButton: View {
  let systemName: String
  let help: String
  /// On the panel itself: [help] shows as the panel's hint. In the Appearance
  /// popover (its own window): an AppKit tooltip.
  var model: PanelModel?
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    let button = Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(hovering ? 1 : 0.75))
        .frame(width: 26, height: 26)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(hovering ? 0.12 : 0)))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    if let model {
      button.panelHint(help, model: model)
    } else {
      button.help(help)
    }
  }
}

private struct PillButton: View {
  let title: String
  let prominent: Bool
  let accent: Color
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .foregroundStyle(prominent ? Color(red: 0.1, green: 0.06, blue: 0.03) : .white.opacity(0.9))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(prominent ? accent : .white.opacity(hovering ? 0.18 : 0.12)))
        .brightness(prominent && hovering ? 0.06 : 0)
    }
    .buttonStyle(PressScaleStyle(reduceMotion: false))
    .onHover { hovering = $0 }
  }
}

private struct LiveDot: View {
  let color: Color
  let active: Bool
  @State private var pulse = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 8, height: 8)
      .opacity(active && pulse && !reduceMotion ? 0.35 : 1)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
      }
  }
}

private struct LevelBars: View {
  let level: Double
  let color: Color
  private static let shape: [Double] = [0.55, 0.9, 0.7, 1.0, 0.6]

  var body: some View {
    HStack(alignment: .center, spacing: 2) {
      ForEach(0..<Self.shape.count, id: \.self) { index in
        Capsule()
          .fill(color.opacity(0.9))
          .frame(width: 3, height: max(3, 14 * min(1, level * 3) * Self.shape[index]))
      }
    }
    .frame(height: 14)
    .animation(.linear(duration: 0.1), value: level)
  }
}

/// Glass, solid colour or nothing behind the content; [forceVisible] keeps a
/// faint tint so a "clear" panel still shows its bounds while hovered.
private struct PanelBackground: View {
  let style: PanelStyle
  let forceVisible: Bool
  let cornerRadius: CGFloat

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    ZStack {
      switch style.background {
      case "solid":
        shape.fill(Color(argb: style.backgroundColor).opacity(style.backgroundOpacity))
      case "clear":
        // Nearly invisible so the panel still receives hover and drops.
        shape.fill(Color.black.opacity(forceVisible ? 0.42 : 0.004))
      default:
        VisualEffectBlur().clipShape(shape)
        shape.fill(Color(argb: style.backgroundColor).opacity(style.backgroundOpacity * 0.7))
      }
      if style.background != "clear" || forceVisible {
        shape.strokeBorder(.white.opacity(0.1), lineWidth: 1)
      }
    }
  }
}

private struct VisualEffectBlur: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
