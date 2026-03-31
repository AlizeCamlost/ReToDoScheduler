import Foundation

enum NornPreviewFixtures {
  static let taskPoolOrganization: TaskPoolOrganizationDocument = {
    let now = Date()
    return TaskPoolOrganizationDocument(
      directories: [
        TaskPoolDirectory(
          id: TaskPoolOrganizationDocument.defaultRootDirectoryID,
          name: TaskPoolOrganizationDocument.defaultRootDirectoryName,
          sortOrder: 0
        ),
        TaskPoolDirectory(
          id: TaskPoolOrganizationDocument.defaultInboxDirectoryID,
          name: TaskPoolOrganizationDocument.defaultInboxDirectoryName,
          parentDirectoryID: TaskPoolOrganizationDocument.defaultRootDirectoryID,
          sortOrder: 0
        ),
        TaskPoolDirectory(
          id: "dir-release",
          name: "版本发布",
          parentDirectoryID: TaskPoolOrganizationDocument.defaultRootDirectoryID,
          sortOrder: 1
        ),
        TaskPoolDirectory(
          id: "dir-docs",
          name: "文档整理",
          parentDirectoryID: "dir-release",
          sortOrder: 0
        )
      ],
      taskPlacements: [
        TaskPoolTaskPlacement(taskID: "task-1", parentDirectoryID: "dir-release", sortOrder: 0),
        TaskPoolTaskPlacement(taskID: "task-2", parentDirectoryID: TaskPoolOrganizationDocument.defaultInboxDirectoryID, sortOrder: 0),
        TaskPoolTaskPlacement(taskID: "task-3", parentDirectoryID: "dir-docs", sortOrder: 0),
        TaskPoolTaskPlacement(taskID: "task-4", parentDirectoryID: "dir-release", sortOrder: 1)
      ],
      updatedAt: now
    ).normalized()
  }()

  static let tasks: [Task] = {
    let calendar = Calendar.current
    let now = Date()
    let startedStep = TaskStepProgress(startedAt: now)
    let completedStep = TaskStepProgress(
      startedAt: calendar.date(byAdding: .hour, value: -2, to: now),
      completedAt: calendar.date(byAdding: .hour, value: -1, to: now)
    )

    return [
      Task(
        id: "task-1",
        title: "准备 TestFlight 发布",
        rawInput: "准备 TestFlight 发布 #ios #release",
        description: "整理截图、检查隐私说明并完成最后一轮自测。",
        status: .doing,
        estimatedMinutes: 90,
        minChunkMinutes: 15,
        dueAt: calendar.date(byAdding: .day, value: 1, to: now),
        tags: ["ios", "release"],
        steps: [
          TaskStep(id: "s1", title: "更新商店截图", estimatedMinutes: 30, minChunkMinutes: 15, progress: startedStep),
          TaskStep(id: "s2", title: "核对隐私配置", estimatedMinutes: 20, minChunkMinutes: 10, dependsOnStepIDs: ["s1"])
        ]
      ),
      Task(
        id: "task-2",
        title: "排查同步报错",
        rawInput: "排查同步报错 #backend",
        description: "检查 token、容器端口和 API 健康状态。",
        estimatedMinutes: 45,
        dueAt: calendar.date(byAdding: .day, value: 2, to: now),
        tags: ["backend"],
        scheduleValue: TaskScheduleValue(rewardOnTime: 12, penaltyMissed: 40)
      ),
      Task(
        id: "task-3",
        title: "整理产品文档",
        rawInput: "整理产品文档 #docs",
        description: "更新调度模型说明和数据结构图。",
        estimatedMinutes: 60,
        dueAt: calendar.date(byAdding: .day, value: 3, to: now),
        tags: ["docs"]
      ),
      Task(
        id: "task-4",
        title: "实现离线缓存逻辑",
        rawInput: "实现离线缓存逻辑 #ios #storage",
        description: "使用本地 JSON 做离线持久化，确保离线可读写。",
        estimatedMinutes: 120,
        minChunkMinutes: 30,
        dueAt: calendar.date(byAdding: .day, value: 4, to: now),
        tags: ["ios", "storage"],
        steps: [
          TaskStep(id: "s3", title: "设计 schema", estimatedMinutes: 30, minChunkMinutes: 15, progress: completedStep),
          TaskStep(id: "s4", title: "实现读写层", estimatedMinutes: 60, minChunkMinutes: 30, dependsOnStepIDs: ["s3"], progress: startedStep),
          TaskStep(id: "s5", title: "写集成测试", estimatedMinutes: 30, minChunkMinutes: 15, dependsOnStepIDs: ["s4"])
        ]
      )
    ]
  }()
}
