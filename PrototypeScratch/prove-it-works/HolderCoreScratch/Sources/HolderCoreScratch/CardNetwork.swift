enum CardNetwork: String, CaseIterable, Identifiable, Codable {
	var id: Self { self }

	case visa = "Visa"
	case master = "Mastercard"
	case amex = "Amex"
	case diners = "Diners"
	case rupay = "Rupay"
	case discover = "Discover"
	case jcb = "JCB"
	case unionPay = "UnionPay"
	case other = "Unknown"
}
