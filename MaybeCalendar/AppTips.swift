import SwiftUI
import TipKit

/// Shown once, the first time there are plans on screen: plans respond to touch.
struct MovePlanTip: Tip {
    var title: Text { Text("Move a plan") }
    var message: Text? {
        Text("Press and hold a plan, then drag it to a new time. Drag its bottom edge to change how long it is.")
    }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}
