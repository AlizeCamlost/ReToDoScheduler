import SwiftUI

struct TaskPoolTreeBrowser: View {
  let tasks: [Task]
  let organization: TaskPoolOrganizationDocument
  let onTaskTap: (Task) -> Void
  let onCreateDirectory: (String, String?) -> Void
  let onRenameDirectory: (String, String) -> Void
  let onDeleteDirectory: (String) -> Void
  let onMoveDirectory: (String, String?) -> Void
  let onMoveTask: (String, String?) -> Void

  @State private var selectedDirectoryID = TaskPoolOrganizationDocument.defaultInboxDirectoryID
  @State private var expandedDirectoryIDs: Set<String> = [
    TaskPoolOrganizationDocument.defaultRootDirectoryID,
    TaskPoolOrganizationDocument.defaultInboxDirectoryID
  ]
  @State private var directoryEditor: DirectoryEditorContext?

  private var normalizedOrganization: TaskPoolOrganizationDocument {
    organization.normalized()
  }

  private var normalizedTasks: [Task] {
    tasks.filter { $0.status != .archived }
  }

  private var rootDirectory: TaskPoolDirectory {
    normalizedOrganization.directory(for: normalizedOrganization.rootDirectoryID)
      ?? TaskPoolDirectory(
        id: normalizedOrganization.rootDirectoryID,
        name: TaskPoolOrganizationDocument.defaultRootDirectoryName
      )
  }

  private var selectedDirectory: TaskPoolDirectory {
    normalizedOrganization.directory(for: selectedDirectoryID)
      ?? normalizedOrganization.directory(for: normalizedOrganization.inboxDirectoryID)
      ?? rootDirectory
  }

  private var selectedDirectoryPath: [TaskPoolDirectory] {
    directoryPath(for: selectedDirectory.id)
  }

  private var selectedDirectoryChildren: [TaskPoolDirectory] {
    childDirectories(of: selectedDirectory.id)
  }

  private var selectedDirectoryTasks: [Task] {
    tasks(in: selectedDirectory.id)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        summaryCard
        directoryOutlineCard
        directoryDetailCard
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity)
    }
    .onAppear(perform: syncLocalSelectionState)
    .onChange(of: organization) { _, _ in
      syncLocalSelectionState()
    }
    .sheet(item: $directoryEditor) { editor in
      TaskPoolDirectoryEditorSheet(
        title: editor.title,
        message: editor.message,
        initialName: editor.initialName,
        submitLabel: editor.submitLabel
      ) { name in
        switch editor.mode {
        case .create(let parentDirectoryID):
          onCreateDirectory(name, parentDirectoryID)
          expandedDirectoryIDs.insert(parentDirectoryID ?? normalizedOrganization.rootDirectoryID)
        case .rename(let directoryID):
          onRenameDirectory(directoryID, name)
        }
      }
    }
  }

  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("目录树")
        .font(.headline.weight(.semibold))

      Text("任务池现在以目录树浏览全量任务。目录组织会和画布共享同一份同步文档。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        summaryPill(title: "目录", value: "\(normalizedOrganization.directories.count - 1)")
        summaryPill(title: "任务", value: "\(normalizedTasks.count)")
        summaryPill(title: "当前", value: displayName(for: selectedDirectory))
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private func summaryPill(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(NornTheme.pillSurface)
    )
  }

  private var directoryOutlineCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("目录导航")
            .font(.headline.weight(.semibold))
          Text("点击目录查看内容，长按目录行可新建子目录、重命名、移动或删除。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Button {
          directoryEditor = .create(parentDirectoryID: normalizedOrganization.rootDirectoryID)
        } label: {
          Label("新建目录", systemImage: "folder.badge.plus")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
      }

      DirectoryOutlineNode(
        directory: rootDirectory,
        organization: normalizedOrganization,
        selectedDirectoryID: selectedDirectoryID,
        expandedDirectoryIDs: $expandedDirectoryIDs,
        taskCountProvider: taskCount(in:),
        displayNameProvider: displayName(for:),
        onSelect: selectDirectory,
        onCreateChild: { parentDirectoryID in
          directoryEditor = .create(parentDirectoryID: parentDirectoryID)
        },
        onRename: { directory in
          directoryEditor = .rename(directoryID: directory.id, currentName: directory.name)
        },
        onMove: onMoveDirectory,
        onDelete: onDeleteDirectory
      )
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private var directoryDetailCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(displayName(for: selectedDirectory))
            .font(.title3.weight(.bold))

          Text(selectedDirectoryPath.map(displayName(for:)).joined(separator: " / "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()

        Menu {
          Button {
            directoryEditor = .create(parentDirectoryID: selectedDirectory.id)
          } label: {
            Label("新建子目录", systemImage: "folder.badge.plus")
          }

          if canEdit(directory: selectedDirectory) {
            Button {
              directoryEditor = .rename(directoryID: selectedDirectory.id, currentName: selectedDirectory.name)
            } label: {
              Label("重命名", systemImage: "pencil")
            }

            directoryMoveMenu(for: selectedDirectory)

            Button(role: .destructive) {
              onDeleteDirectory(selectedDirectory.id)
            } label: {
              Label("删除目录", systemImage: "trash")
            }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.title3)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
      }

      if !selectedDirectoryChildren.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          sectionLabel("子目录")

          ForEach(selectedDirectoryChildren) { directory in
            Button {
              selectDirectory(directory.id)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                  .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                  Text(displayName(for: directory))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                  Text("\(childDirectories(of: directory.id).count) 个子目录 · \(taskCount(in: directory.id)) 个任务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.tertiary)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(NornTheme.cardSurfaceMuted)
              )
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button {
                directoryEditor = .create(parentDirectoryID: directory.id)
              } label: {
                Label("新建子目录", systemImage: "folder.badge.plus")
              }

              if canEdit(directory: directory) {
                Button {
                  directoryEditor = .rename(directoryID: directory.id, currentName: directory.name)
                } label: {
                  Label("重命名", systemImage: "pencil")
                }

                directoryMoveMenu(for: directory)

                Button(role: .destructive) {
                  onDeleteDirectory(directory.id)
                } label: {
                  Label("删除目录", systemImage: "trash")
                }
              }
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        sectionLabel("任务")

        if selectedDirectoryTasks.isEmpty {
          Text("这个目录下还没有任务。你可以从任务卡片的长按菜单把任务移到这里。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
        } else {
          ForEach(selectedDirectoryTasks) { task in
            TaskCard(task: task, dimmed: task.status == .done) {
              onTaskTap(task)
            }
            .contextMenu {
              Menu("移动到目录") {
                ForEach(moveTargets(forMovingTaskID: task.id), id: \.id) { directory in
                  Button(displayName(for: directory)) {
                    onMoveTask(task.id, directory.id)
                  }
                }
              }
            }
          }
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private func sectionLabel(_ title: String) -> some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
  }

  private func selectDirectory(_ directoryID: String) {
    selectedDirectoryID = directoryID
    expandedDirectoryIDs.insert(directoryID)
    for directory in directoryPath(for: directoryID) {
      expandedDirectoryIDs.insert(directory.id)
    }
  }

  private func syncLocalSelectionState() {
    let normalized = normalizedOrganization
    if normalized.directory(for: selectedDirectoryID) == nil {
      selectedDirectoryID = normalized.inboxDirectoryID
    }
    expandedDirectoryIDs.insert(normalized.rootDirectoryID)
    expandedDirectoryIDs.insert(normalized.inboxDirectoryID)
  }

  private func directoryPath(for directoryID: String) -> [TaskPoolDirectory] {
    var result: [TaskPoolDirectory] = []
    var currentID: String? = directoryID

    while let current = currentID, let directory = normalizedOrganization.directory(for: current) {
      result.insert(directory, at: 0)
      currentID = directory.parentDirectoryID
    }

    return result
  }

  private func childDirectories(of parentDirectoryID: String?) -> [TaskPoolDirectory] {
    normalizedOrganization.directories
      .filter { $0.parentDirectoryID == parentDirectoryID }
      .sorted(by: directorySortComparator)
  }

  private func tasks(in targetDirectoryID: String) -> [Task] {
    normalizedTasks
      .filter { directoryID(for: $0.id) == targetDirectoryID }
      .sorted(by: taskSortComparator)
  }

  private func directoryID(for taskID: String) -> String {
    normalizedOrganization.taskPlacement(for: taskID)?.parentDirectoryID ?? normalizedOrganization.inboxDirectoryID
  }

  private func taskCount(in directoryID: String) -> Int {
    tasks(in: directoryID).count
  }

  private func moveTargets(forMovingTaskID taskID: String) -> [TaskPoolDirectory] {
    let currentDirectoryID = directoryID(for: taskID)
    return normalizedOrganization.directories
      .filter { $0.id != currentDirectoryID }
      .sorted(by: directorySortComparator)
  }

  private func canEdit(directory: TaskPoolDirectory) -> Bool {
    directory.id != normalizedOrganization.rootDirectoryID && directory.id != normalizedOrganization.inboxDirectoryID
  }

  @ViewBuilder
  private func directoryMoveMenu(for directory: TaskPoolDirectory) -> some View {
    Menu("移动到目录") {
      ForEach(moveTargets(forMovingDirectory: directory), id: \.id) { target in
        Button(displayName(for: target)) {
          onMoveDirectory(directory.id, target.id)
        }
      }
      Button("移到根目录") {
        onMoveDirectory(directory.id, normalizedOrganization.rootDirectoryID)
      }
    }
  }

  private func moveTargets(forMovingDirectory directory: TaskPoolDirectory) -> [TaskPoolDirectory] {
    let invalidParentIDs = descendantDirectoryIDs(of: directory.id).union([directory.id])

    return normalizedOrganization.directories
      .filter {
        $0.id != normalizedOrganization.inboxDirectoryID &&
        !invalidParentIDs.contains($0.id) &&
        $0.id != directory.parentDirectoryID
      }
      .sorted(by: directorySortComparator)
  }

  private func descendantDirectoryIDs(of directoryID: String) -> Set<String> {
    let childIDs = childDirectories(of: directoryID).map(\.id)
    guard !childIDs.isEmpty else {
      return []
    }

    var descendants = Set(childIDs)
    for childID in childIDs {
      descendants.formUnion(descendantDirectoryIDs(of: childID))
    }
    return descendants
  }

  private func displayName(for directory: TaskPoolDirectory) -> String {
    switch directory.id {
    case normalizedOrganization.rootDirectoryID:
      return "全部任务"
    case normalizedOrganization.inboxDirectoryID:
      return "待整理"
    default:
      return directory.name
    }
  }

  private var directorySortComparator: (TaskPoolDirectory, TaskPoolDirectory) -> Bool {
    { lhs, rhs in
      if lhs.sortOrder != rhs.sortOrder {
        return lhs.sortOrder < rhs.sortOrder
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  private var taskSortComparator: (Task, Task) -> Bool {
    { lhs, rhs in
      switch (lhs.dueAt, rhs.dueAt) {
      case let (left?, right?) where left != right:
        return left < right
      case (.some, .none):
        return true
      case (.none, .some):
        return false
      default:
        let leftSortOrder = normalizedOrganization.taskPlacement(for: lhs.id)?.sortOrder ?? .max
        let rightSortOrder = normalizedOrganization.taskPlacement(for: rhs.id)?.sortOrder ?? .max
        if leftSortOrder != rightSortOrder {
          return leftSortOrder < rightSortOrder
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
    }
  }
}

private extension TaskPoolTreeBrowser {
  struct DirectoryEditorContext: Identifiable {
    enum Mode {
      case create(parentDirectoryID: String?)
      case rename(directoryID: String)
    }

    let mode: Mode
    let initialName: String

    var id: String {
      switch mode {
      case .create(let parentDirectoryID):
        return "create:\(parentDirectoryID ?? TaskPoolOrganizationDocument.defaultRootDirectoryID)"
      case .rename(let directoryID):
        return "rename:\(directoryID)"
      }
    }

    var title: String {
      switch mode {
      case .create:
        return "新建目录"
      case .rename:
        return "重命名目录"
      }
    }

    var message: String {
      switch mode {
      case .create:
        return "新目录会立即写入任务池组织文档，并参与多端同步。"
      case .rename:
        return "目录名称修改后，树视图和画布会共享同一份新名称。"
      }
    }

    var submitLabel: String {
      switch mode {
      case .create:
        return "创建"
      case .rename:
        return "保存"
      }
    }

    static func create(parentDirectoryID: String?) -> Self {
      DirectoryEditorContext(mode: .create(parentDirectoryID: parentDirectoryID), initialName: "")
    }

    static func rename(directoryID: String, currentName: String) -> Self {
      DirectoryEditorContext(mode: .rename(directoryID: directoryID), initialName: currentName)
    }
  }
}

private struct DirectoryOutlineNode: View {
  let directory: TaskPoolDirectory
  let organization: TaskPoolOrganizationDocument
  let selectedDirectoryID: String
  @Binding var expandedDirectoryIDs: Set<String>
  let taskCountProvider: (String) -> Int
  let displayNameProvider: (TaskPoolDirectory) -> String
  let onSelect: (String) -> Void
  let onCreateChild: (String) -> Void
  let onRename: (TaskPoolDirectory) -> Void
  let onMove: (String, String?) -> Void
  let onDelete: (String) -> Void

  private var childDirectories: [TaskPoolDirectory] {
    organization.directories
      .filter { $0.parentDirectoryID == directory.id }
      .sorted {
        if $0.sortOrder != $1.sortOrder {
          return $0.sortOrder < $1.sortOrder
        }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
  }

  private var isExpanded: Bool {
    expandedDirectoryIDs.contains(directory.id)
  }

  private var canEdit: Bool {
    directory.id != organization.rootDirectoryID && directory.id != organization.inboxDirectoryID
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        if childDirectories.isEmpty {
          Color.clear
            .frame(width: 18, height: 18)
        } else {
          Button {
            toggleExpanded()
          } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(width: 18, height: 18)
          }
          .buttonStyle(.plain)
        }

        Button {
          onSelect(directory.id)
        } label: {
          HStack(spacing: 10) {
            Image(systemName: selectedDirectoryID == directory.id ? "folder.fill" : "folder")
              .foregroundStyle(directory.id == organization.inboxDirectoryID ? .blue : .orange)

            Text(displayNameProvider(directory))
              .font(.subheadline.weight(selectedDirectoryID == directory.id ? .semibold : .regular))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(taskCountProvider(directory.id))")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                Capsule(style: .continuous)
                  .fill(NornTheme.pillSurface)
              )
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(selectedDirectoryID == directory.id ? NornTheme.pillSurfaceStrong : Color.clear)
          )
        }
        .buttonStyle(.plain)
      }
      .contextMenu {
        Button {
          onCreateChild(directory.id)
        } label: {
          Label("新建子目录", systemImage: "folder.badge.plus")
        }

        if canEdit {
          Button {
            onRename(directory)
          } label: {
            Label("重命名", systemImage: "pencil")
          }

          Menu("移动到目录") {
            ForEach(moveTargets, id: \.id) { target in
              Button(displayNameProvider(target)) {
                onMove(directory.id, target.id)
              }
            }
            Button("移到根目录") {
              onMove(directory.id, organization.rootDirectoryID)
            }
          }

          Button(role: .destructive) {
            onDelete(directory.id)
          } label: {
            Label("删除目录", systemImage: "trash")
          }
        }
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(childDirectories) { childDirectory in
            DirectoryOutlineNode(
              directory: childDirectory,
              organization: organization,
              selectedDirectoryID: selectedDirectoryID,
              expandedDirectoryIDs: $expandedDirectoryIDs,
              taskCountProvider: taskCountProvider,
              displayNameProvider: displayNameProvider,
              onSelect: onSelect,
              onCreateChild: onCreateChild,
              onRename: onRename,
              onMove: onMove,
              onDelete: onDelete
            )
          }
        }
        .padding(.leading, 18)
      }
    }
  }

  private func toggleExpanded() {
    if isExpanded {
      expandedDirectoryIDs.remove(directory.id)
    } else {
      expandedDirectoryIDs.insert(directory.id)
    }
  }

  private var moveTargets: [TaskPoolDirectory] {
    let invalidParentIDs = descendantDirectoryIDs(of: directory.id).union([directory.id])

    return organization.directories
      .filter {
        $0.id != organization.inboxDirectoryID &&
        $0.id != directory.parentDirectoryID &&
        !invalidParentIDs.contains($0.id)
      }
      .sorted {
        if $0.sortOrder != $1.sortOrder {
          return $0.sortOrder < $1.sortOrder
        }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
  }

  private func descendantDirectoryIDs(of directoryID: String) -> Set<String> {
    let childIDs = organization.directories
      .filter { $0.parentDirectoryID == directoryID }
      .map(\.id)

    guard !childIDs.isEmpty else {
      return []
    }

    var descendants = Set(childIDs)
    for childID in childIDs {
      descendants.formUnion(descendantDirectoryIDs(of: childID))
    }
    return descendants
  }
}
