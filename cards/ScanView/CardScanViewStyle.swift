//
//  CardScanViewStyle.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 03/02/24.
//
#if os(iOS)

import SharkCardScan
import UIKit

struct CardScanViewStyle: CardScanStyling {
	public var instructionLabelStyling: LabelStyling
	public var cardNumberLabelStyling: LabelStyling
	public var expiryLabelStyling: LabelStyling
	public var holderLabelStyling: LabelStyling
	public var backgroundColor: UIColor

	public init () {
		self.instructionLabelStyling = (font: UIFont.boldSystemFont(ofSize: 14), color: .secondaryLabel)
		self.cardNumberLabelStyling = (font: UIFont.systemFont(ofSize: 28), color: .white)
		self.expiryLabelStyling = (font: UIFont.systemFont(ofSize: 14), color: .white)
		self.holderLabelStyling = (font: UIFont.systemFont(ofSize: 14), color: .white)
		self.backgroundColor = .systemBackground
	}
}
#endif
