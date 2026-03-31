import SwiftUI

struct TaskPoolCanvasView: View {
  let tasks: [Task]
  let organization: TaskPoolOrganizationDocument
  let onTaskTap: (Task) -> Void
  let onUpdateNode: (String, TaskPoolCanvasNodeLayout.NodeKind, Double, Double, Bool) -> Void

  @State private var dragTranslations: [String: CGSize] = [:]

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

  var body: some View {
    ScrollView([.horizontal, .vertical], showsIndicators: false) {
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
              Path(ellipseIn: CGRect(x: end.x - 3.5, y: end.y - 3.5, width: 7, height: 7)),
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
      .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
      .padding(28)
    }
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(NornTheme.cardSurface.opacity(0.32))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
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
        dragTranslations[node.id] = value.translation
      }
      .onEnded { value in
        dragTranslations[node.id] = nil
        let nextPosition = clampedPosition(
          CGPoint(
            x: node.position.x + value.translation.width,
            y: node.position.y + value.translation.height
          )
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
    return clampedPosition(
      CGPoint(
        x: node.position.x + translation.width,
        y: node.position.y + translation.height
      )
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
    let offset = max(48, abs(end.x - start.x) * 0.35)
    return CGPoint(
      x: start.x + offset * direction,
      y: start.y
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

  private func clampedPosition(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, 120), canvasSize.width - 120),
      y: min(max(point.y, 90), canvasSize.height - 90)
    )
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

#Preview {
  TaskPoolCanvasView(
    tasks: NornPreviewFixtures.tasks,
    organization: NornPreviewFixtures.taskPoolOrganization,
    onTaskTap: { _ in },
    onUpdateNode: { _, _, _, _, _ in }
  )
  .padding()
  .background(NornScreenBackground())
}
