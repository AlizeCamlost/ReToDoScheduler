import SwiftUI

enum PoolViewMode: String, CaseIterable, Identifiable {
  case list, quadrant, cluster
  var id: String { rawValue }
  var label: String {
    switch self {
    case .list:     return "列表"
    case .quadrant: return "四象限"
    case .cluster:  return "聚类"
    }
  }
}

struct TaskPoolTab: View {
  @State private var viewMode: PoolViewMode = .list

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().opacity(0.5)
      placeholder
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("任务池")
        .font(.title2.weight(.bold))

      Picker("", selection: $viewMode) {
        ForEach(PoolViewMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 16)
    .background(.regularMaterial)
  }

  private var placeholder: some View {
    ScrollView {
      VStack {
        Spacer(minLength: 120)
        Text("任务池视图开发中")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
        Spacer(minLength: 120)
      }
      .frame(maxWidth: .infinity)
    }
  }
}

#Preview {
  TaskPoolTab()
}
