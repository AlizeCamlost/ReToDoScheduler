import SwiftUI

struct TaskBundleBadge: View {
  let metadata: TaskBundleMetadata

  var body: some View {
    Label {
      Text(labelText)
        .lineLimit(1)
    } icon: {
      Image(systemName: "square.stack.3d.down.forward")
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(NornTheme.pillSurface, in: Capsule())
  }

  private var labelText: String {
    let baseTitle = metadata.title ?? "任务序列"
    guard metadata.count > 1 else {
      return baseTitle
    }
    return "\(baseTitle) \(metadata.position + 1)/\(metadata.count)"
  }
}
