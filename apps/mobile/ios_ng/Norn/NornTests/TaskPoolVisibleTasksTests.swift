import XCTest
@testable import Norn

final class TaskPoolVisibleTasksTests: XCTestCase {
  func testHideCompletedRemovesDoneTasksButKeepsTodoAndDoing() {
    let visible = TaskPoolVisibleTasks.filtered(
      [
        makeTask(id: "todo", title: "Todo", status: .todo),
        makeTask(id: "doing", title: "Doing", status: .doing),
        makeTask(id: "done", title: "Done", status: .done)
      ],
      hideCompleted: true
    )

    XCTAssertEqual(visible.map(\.id), ["todo", "doing"])
  }

  func testArchivedTasksStayHiddenEvenWhenCompletedFilterIsOff() {
    let visible = TaskPoolVisibleTasks.filtered(
      [
        makeTask(id: "todo", title: "Todo", status: .todo),
        makeTask(id: "archived", title: "Archived", status: .archived)
      ],
      hideCompleted: false
    )

    XCTAssertEqual(visible.map(\.id), ["todo"])
  }
}
