//
//  HolderWidgetsBundle.swift
//  HolderWidgets
//
//  Widget bundle entry point
//

import WidgetKit
import SwiftUI

@main
struct HolderWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmallCardWidget()
        MediumCardWidget()
        LockScreenCardWidget()

        if #available(iOS 18.0, *) {
            ControlCenterCardWidget()
        }
    }
}
