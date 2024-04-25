//
//  Tip.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import TipKit

struct DoubleTapTip: Tip {
	var options: [Option] {
		MaxDisplayCount(1)
	}

	var title: Text {
		Text("Long Press to Copy")
	}

	var message: Text? {
		Text("You can long press to copy details")
	}
}
