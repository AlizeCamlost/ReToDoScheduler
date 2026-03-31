import Foundation

struct TaskPoolCanvasNodeLayout: Hashable, Codable {
  enum NodeKind: String, Hashable, Codable {
    case directory
    case task
  }

  var nodeID: String
  var nodeKind: NodeKind
  var x: Double
  var y: Double
  var isCollapsed: Bool

  init(
    nodeID: String,
    nodeKind: NodeKind,
    x: Double = 0,
    y: Double = 0,
    isCollapsed: Bool = false
  ) {
    self.nodeID = nodeID
    self.nodeKind = nodeKind
    self.x = x
    self.y = y
    self.isCollapsed = isCollapsed
  }
}
