import SwiftUI

struct TaskPoolCanvasView: View {
  let tasks: [Task]
  let organization: TaskPoolOrganizationDocument
  let onTaskTap: (Task) -> Void
  let onUpdateNode: (String, TaskPoolCanvasNodeLayout.NodeKind, Double, Double, Bool) -> Void
  let onResetLayout: () -> Void

  @AppStorage("norn.taskPool.canvasZoomScale") private var storedZoomScale = Double(TaskPoolCanvasZoom.defaultScale)
  @State private var dragTranslations: [String: CGSize] = [:]
  @State private var pinchZoomScale: CGFloat = 1

  private let canvasSize = CGSize(width: 1_600, height: 1_200)

  private var mindMap: TaskPoolCanvasMindMap {
    TaskPoolCanvasMindMap(tasks: tasks, organization: organization)
  }

  private var nodePresentations: [TaskPoolCanvasNodePresentation] {
    mindMap.nodes.map { node in
      TaskPoolCanvasNodePresentation(
        nodeID: node.key.nodeID,
        nodeKind: node.key.nodeKind,
        title: node.title,
        subtitle: node.subtitle,
        detail: node.detail,
        position: node.position,
        isCollapsed: node.isCollapsed,
        hasChildren: node.hasChildren,
        accent: accent(for: node.accent),
        task: node.task
      )
    }
  }

  private var visibleEdges: [TaskPoolCanvasMindMap.Edge] {
    mindMap.edges
  }

  private var nodePresentationByID: [String: TaskPoolCanvasNodePresentation] {
    Dictionary(uniqueKeysWithValues: nodePresentations.map { ($0.id, $0) })
  }

  private var parentNodeIDByChildID: [String: String] {
    Dictionary(uniqueKeysWithValues: visibleEdges.map { ($0.child.stableID, $0.parent.stableID) })
  }

  private var effectiveZoomScale: CGFloat {
    TaskPoolCanvasZoom.clamped(CGFloat(storedZoomScale) * pinchZoomScale)
  }

  private var scaledCanvasSize: CGSize {
    TaskPoolCanvasZoom.scaledCanvasSize(for: canvasSize, scale: effectiveZoomScale)
  }

  var body: some View {
    ScrollView([.horizontal, .vertical], showsIndicators: false) {
      canvasContent
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .scaleEffect(effectiveZoomScale, anchor: .topLeading)
        .frame(width: scaledCanvasSize.width, height: scaledCanvasSize.height, alignment: .topLeading)
        .padding(28)
    }
    .simultaneousGesture(canvasZoomGesture)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(NornTheme.cardSurface.opacity(0.32))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 8) {
        Button(action: onResetLayout) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
              Capsule(style: .continuous)
                .fill(NornTheme.cardSurface.opacity(0.94))
            )
            .overlay(
              Capsule(style: .continuous)
                .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)

        TaskPoolCanvasZoomControls(
          zoomLabel: TaskPoolCanvasZoom.percentLabel(for: effectiveZoomScale),
          canZoomOut: effectiveZoomScale > TaskPoolCanvasZoom.minScale + 0.001,
          canZoomIn: effectiveZoomScale < TaskPoolCanvasZoom.maxScale - 0.001,
          canReset: abs(effectiveZoomScale - TaskPoolCanvasZoom.defaultScale) > 0.001,
          onZoomOut: { stepZoom(by: -TaskPoolCanvasZoom.step) },
          onReset: resetZoom,
          onZoomIn: { stepZoom(by: TaskPoolCanvasZoom.step) }
        )
      }
      .padding(16)
    }
  }

  private var canvasContent: some View {
    ZStack(alignment: .topLeading) {
      TaskPoolCanvasGridBackground()
        .frame(width: canvasSize.width, height: canvasSize.height)

      Canvas { context, _ in
        for edge in visibleEdges {
          guard
            let parent = nodePresentationByID[edge.parent.stableID],
            let child = nodePresentationByID[edge.child.stableID]
          else {
            continue
          }

          let start = connectorStartPoint(from: parent, to: child)
          let end = connectorEndPoint(from: parent, to: child)
          var path = Path()
          path.move(to: start)
          path.addCurve(
            to: end,
            control1: connectorControlPoint(from: start, to: end, direction: start.x <= end.x ? 1 : -1),
            control2: connectorControlPoint(from: end, to: start, direction: start.x <= end.x ? -1 : 1)
          )

          let color = connectorColor(for: parent)
          context.stroke(
            path,
            with: .color(color.opacity(0.50)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          context.fill(
            Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)),
            with: .color(color.opacity(0.85))
          )
        }
      }
      .frame(width: canvasSize.width, height: canvasSize.height)
      .allowsHitTesting(false)

      ForEach(nodePresentations) { node in
        TaskPoolCanvasNodeCard(
          node: node,
          onToggleCollapse: {
            onUpdateNode(
              node.nodeID,
              node.nodeKind,
              node.position.x,
              node.position.y,
              !node.isCollapsed
            )
          },
          onTap: {
            if let task = node.task {
              onTaskTap(task)
            }
          }
        )
        .position(position(for: node))
        .gesture(dragGesture(for: node))
      }
    }
  }

  private func accent(for accent: TaskPoolCanvasMindMap.AccentKind) -> TaskPoolCanvasNodePresentation.Accent {
    switch accent {
    case .directory:
      return .directory
    case .inbox:
      return .inbox
    case .task(let status):
      return .task(status)
    }
  }

  private func dragGesture(for node: TaskPoolCanvasNodePresentation) -> some Gesture {
    DragGesture()
      .onChanged { value in
        dragTranslations[node.id] = normalizedTranslation(value.translation)
      }
      .onEnded { value in
        dragTranslations[node.id] = nil
        let translation = normalizedTranslation(value.translation)
        let nextPosition = CGPoint(
          x: node.position.x + translation.width,
          y: node.position.y + translation.height
        )
        onUpdateNode(
          node.nodeID,
          node.nodeKind,
          nextPosition.x,
          nextPosition.y,
          node.isCollapsed
        )
      }
  }

  private func position(for node: TaskPoolCanvasNodePresentation) -> CGPoint {
    let translation = accumulatedDragTranslation(for: node)
    return CGPoint(
      x: node.position.x + translation.width,
      y: node.position.y + translation.height
    )
  }

  private func connectorStartPoint(
    from parent: TaskPoolCanvasNodePresentation,
    to child: TaskPoolCanvasNodePresentation
  ) -> CGPoint {
    let parentCenter = position(for: parent)
    let attachesToRight = parentCenter.x <= position(for: child).x
    let x = parentCenter.x + (attachesToRight ? parent.cardWidth / 2 - 18 : -parent.cardWidth / 2 + 18)
    return CGPoint(x: x, y: parentCenter.y)
  }

  private func connectorEndPoint(
    from parent: TaskPoolCanvasNodePresentation,
    to child: TaskPoolCanvasNodePresentation
  ) -> CGPoint {
    let childCenter = position(for: child)
    let attachesToRight = position(for: parent).x <= childCenter.x
    let x = childCenter.x + (attachesToRight ? -child.cardWidth / 2 + 18 : child.cardWidth / 2 - 18)
    return CGPoint(x: x, y: childCenter.y)
  }

  private func connectorControlPoint(from start: CGPoint, to end: CGPoint, direction: CGFloat) -> CGPoint {
    let horizontalOffset = max(60, abs(end.x - start.x) * 0.4)
    let verticalBlend = (end.y - start.y) * 0.15 * direction
    return CGPoint(
      x: start.x + horizontalOffset * direction,
      y: start.y + verticalBlend
    )
  }

  private func connectorColor(for node: TaskPoolCanvasNodePresentation) -> Color {
    switch node.accent {
    case .directory:
      return .orange
    case .inbox:
      return .blue
    case .task(let status):
      return TaskDisplayFormatter.statusColor(for: status)
    }
  }

  private func accumulatedDragTranslation(for node: TaskPoolCanvasNodePresentation) -> CGSize {
    var total = CGSize.zero
    var currentNodeID: String? = node.id

    while let current = currentNodeID {
      total.width += dragTranslations[current]?.width ?? 0
      total.height += dragTranslations[current]?.height ?? 0
      currentNodeID = parentNodeIDByChildID[current]
    }

    return total
  }

  private var canvasZoomGesture: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        pinchZoomScale = value
      }
      .onEnded { value in
        storedZoomScale = Double(TaskPoolCanvasZoom.clamped(CGFloat(storedZoomScale) * value))
        pinchZoomScale = 1
      }
  }

  private func normalizedTranslation(_ translation: CGSize) -> CGSize {
    TaskPoolCanvasZoom.normalizedTranslation(translation, scale: effectiveZoomScale)
  }

  private func stepZoom(by delta: CGFloat) {
    storedZoomScale = Double(TaskPoolCanvasZoom.stepped(from: CGFloat(storedZoomScale), delta: delta))
    pinchZoomScale = 1
  }

  private func resetZoom() {
    storedZoomScale = Double(TaskPoolCanvasZoom.defaultScale)
    pinchZoomScale = 1
  }
}

private struct TaskPoolCanvasGridBackground: View {
  private let spacing: CGFloat = 64

  var body: some View {
    Canvas { context, size in
      var path = Path()
      stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }
      stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }

      context.stroke(
        path,
        with: .color(NornTheme.borderStrong.opacity(0.16)),
        style: StrokeStyle(lineWidth: 1)
      )
    }
  }
}

private struct TaskPoolCanvasZoomControls: View {
  let zoomLabel: String
  let canZoomOut: Bool
  let canZoomIn: Bool
  let canReset: Bool
  let onZoomOut: () -> Void
  let onReset: () -> Void
  let onZoomIn: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: onZoomOut) {
        Image(systemName: "minus.magnifyingglass")
          .font(.subheadline.weight(.semibold))
      }
      .disabled(!canZoomOut)

      Button(action: onReset) {
        Text(zoomLabel)
          .font(.caption.weight(.semibold))
          .monospacedDigit()
      }
      .disabled(!canReset)

      Button(action: onZoomIn) {
        Image(systemName: "plus.magnifyingglass")
          .font(.subheadline.weight(.semibold))
      }
      .disabled(!canZoomIn)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      Capsule(style: .continuous)
        .fill(NornTheme.cardSurface.opacity(0.94))
    )
    .overlay(
      Capsule(style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
    .foregroundStyle(.primary)
  }
}

#Preview {
  TaskPoolCanvasView(
    tasks: NornPreviewFixtures.tasks,
    organization: NornPreviewFixtures.taskPoolOrganization,
    onTaskTap: { _ in },
    onUpdateNode: { _, _, _, _, _ in },
    onResetLayout: {}
  )
  .padding()
  .background(NornScreenBackground())
}
