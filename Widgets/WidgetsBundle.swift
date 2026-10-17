import WidgetKit
import SwiftUI

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmallCardWidget()
        MediumCardWidget()

        #if os(iOS)
        LockScreenCardWidget()

        if #available(iOS 18.0, *) {
            ControlCenterCardWidget()
        }
        #endif
    }
}
