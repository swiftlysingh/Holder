//
//  WidgetsBundle.swift
//  Widgets
//
//  Created by Pushpinder on 1/5/26.
//

import WidgetKit
import SwiftUI

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmallCardWidget()
        MediumCardWidget()
        LockScreenCardWidget()

        if #available(iOS 18.0, *) {
            ControlCenterCardWidget()
        }
    }
}
