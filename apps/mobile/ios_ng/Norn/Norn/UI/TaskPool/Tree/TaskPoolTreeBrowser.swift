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
  @State private var isNavigationExpanded = true
  @State private var isDestinationChildrenExpanded = true
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

  private var selectedParentDirectory: TaskPoolDirectory? {
    guard let parentDirectoryID = selectedDirectory.parentDirectoryID else {
      return nil
    }
    return normalizedOrganization.directory(for: parentDirectoryID)
  }

  private var selectedDirectoryTasks: [Task] {
    tasks(in: selectedDirectory.id)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        navigationSection

        Divider()
          .overlay(NornTheme.divider)

        destinationSection
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
      .frame(maxWidth: .infinity, alignment: .leading)
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

  private var navigationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 5) {
          Text("目录")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Text("已选")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)

            Text(displayName(for: selectedDirectory))
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(
                Capsule(style: .continuous)
                  .fill(NornTheme.pillSurface)
              )
          }
        }

        Spacer()

        Button {
          withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
            isNavigationExpanded.toggle()
          }
        } label: {
          Image(systemName: isNavigationExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      if isNavigationExpanded {
        Text("\(normalizedOrganization.directories.count - 1) 个目录 · \(normalizedTasks.count) 个任务")
          .font(.caption2)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 2) {
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
            onDelete: onDeleteDirectory,
            depth: 0
          )
        }
        .padding(.top, 2)
      }
    }
  }

  private var destinationSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(displayName(for: selectedDirectory))
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)

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

      if selectedParentDirectory != nil || !selectedDirectoryChildren.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Button {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
              isDestinationChildrenExpanded.toggle()
            }
          } label: {
            HStack(spacing: 8) {
              sectionLabel("子目录")
              Spacer(minLength: 8)
              Image(systemName: isDestinationChildrenExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)

          if isDestinationChildrenExpanded {
            VStack(alignment: .leading, spacing: 2) {
              if let parentDirectory = selectedParentDirectory {
                Button {
                  selectDirectory(parentDirectory.id)
                } label: {
                  HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.up.left")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 1) {
                      Text("..")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                      Text(displayName(for: parentDirectory))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 6)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }

              ForEach(selectedDirectoryChildren) { directory in
                Button {
                  selectDirectory(directory.id)
                } label: {
                  HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                      .font(.caption2)
                      .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 1) {
                      Text(displayName(for: directory))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                      Text("\(childDirectories(of: directory.id).count) 个子目录 · \(taskCount(in: directory.id)) 个任务")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(.tertiary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(selectedDirectoryID == directory.id ? NornTheme.pillSurfaceStrong.opacity(0.52) : Color.clear)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .strokeBorder(
                        selectedDirectoryID == directory.id ? NornTheme.borderStrong.opacity(0.7) : Color.clear,
                        lineWidth: 1
                      )
                  )
                  .contentShape(Rectangle())
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
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        sectionLabel("任务")

        if selectedDirectoryTasks.isEmpty {
          Text("这个目录下还没有任务。你可以从任务卡片的长按菜单把任务移到这里。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          VStack(alignment: .leading, spacing: 2) {
            ForEach(selectedDirectoryTasks) { task in
              DirectoryTaskRow(task: task, onTap: {
                onTaskTap(task)
              })
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
    }
  }

  private func sectionLabel(_ title: String) -> some View {
    Text(title)
      .font(.caption2.weight(.semibold))
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

  private func directoryDepth(of directoryID: String) -> Int {
    directoryPath(for: directoryID).count - 1
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
      ""
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
  let depth: Int

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
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .center, spacing: 2) {
        disclosureControl

        HStack(spacing: 2) {
          Image(systemName: selectedDirectoryID == directory.id ? "folder.fill" : "folder")
            .font(.caption2)
            .foregroundStyle(directory.id == organization.inboxDirectoryID ? .blue : .orange)

          Text(displayNameProvider(directory))
            .font(.callout.weight(selectedDirectoryID == directory.id ? .semibold : .regular))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Spacer(minLength: 6)

          Text("\(taskCountProvider(directory.id))")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 20, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(selectedDirectoryID == directory.id ? NornTheme.pillSurfaceStrong.opacity(0.52) : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            selectedDirectoryID == directory.id ? NornTheme.borderStrong.opacity(0.7) : Color.clear,
            lineWidth: 1
          )
      )
      .contentShape(Rectangle())
      .padding(.leading, CGFloat(depth) * 18)
      .onTapGesture {
        onSelect(directory.id)
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
        VStack(alignment: .leading, spacing: 2) {
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
              onDelete: onDelete,
              depth: depth + 1
            )
          }
        }
        .padding(.leading, 2)
      }
    }
  }

  @ViewBuilder
  private var disclosureControl: some View {
    if childDirectories.isEmpty {
      Color.clear
        .frame(width: 10, height: 10)
    } else {
      Button {
        toggleExpanded()
      } label: {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 10, height: 10)
      }
      .buttonStyle(.plain)
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

private struct DirectoryTaskRow: View {
  let task: Task
  let onTap: () -> Void

  private var bundleMetadata: TaskBundleMetadata? {
    TaskBundleMetadata.metadata(for: task)
  }

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 7) {
        Circle()
          .fill(TaskDisplayFormatter.statusColor(for: task.status).opacity(task.status == .done ? 0.45 : 0.85))
          .frame(width: 7, height: 7)
          .padding(.top, 6)

        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(task.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(2)

            Spacer(minLength: 4)

            if let label = RelativeDueDateFormatter.label(for: task.dueAt) {
              Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }

          if let bundleMetadata {
            TaskBundleBadge(metadata: bundleMetadata)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
