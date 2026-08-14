//
//  DocumentData.swift
//  Holder
//
//  Metadata for photo-first identity documents. Attachment bytes intentionally
//  live outside this Codable record so they are never written into Keychain JSON.
//

import Foundation

enum DocumentKind: String, CaseIterable, Identifiable, Codable, Hashable {
	case drivingLicence = "Driving licence"
	case passport = "Passport"
	case insurance = "Insurance"
	case nationalID = "National ID"
	case residencePermit = "Residence permit"
	case other = "Document"

	var id: Self { self }
}

enum DocumentFieldKind: String, CaseIterable, Identifiable, Codable, Hashable {
	case holderName = "Name"
	case documentNumber = "Document number"
	case dateOfBirth = "Date of birth"
	case issueDate = "Issued"
	case expiryDate = "Expires"
	case documentClass = "Classes"
	case issuer = "Issuer"
	case address = "Address"
	case notes = "Notes"
	case custom = "Custom"

	var id: Self { self }
}

struct DocumentField: Identifiable, Codable, Hashable {
	var id: UUID
	var kind: DocumentFieldKind
	var value: String
	/// Custom labels are useful for issuer-specific fields while retaining a
	/// typed field kind for accessible presentation and future migrations.
	var label: String?

	init(
		id: UUID = UUID(),
		kind: DocumentFieldKind,
		value: String,
		label: String? = nil
	) {
		self.id = id
		self.kind = kind
		self.value = value
		self.label = label
	}

	var displayLabel: String {
		guard let label = label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return kind.rawValue
		}
		return label
	}

	private enum CodingKeys: String, CodingKey {
		case id, kind, value, label
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
		kind = try container.decode(DocumentFieldKind.self, forKey: .kind)
		value = try container.decode(String.self, forKey: .value)
		label = try container.decodeIfPresent(String.self, forKey: .label)
	}
}

enum DocumentAttachmentSide: String, CaseIterable, Identifiable, Codable, Hashable {
	case front
	case back

	var id: Self { self }
}

struct DocumentData: Identifiable, Codable, Hashable {
	var id: UUID
	var title: String
	var kind: DocumentKind
	var fields: [DocumentField]
	var hasFrontImage: Bool
	var hasBackImage: Bool
	var isArchived: Bool
	/// Shared deck order. Older document records intentionally decode to `nil`
	/// and use their stable identifier as the display-order fallback.
	var sortIndex: Int?
	/// Presentation-only metadata. Documents remain encrypted and device-local
	/// regardless of whether they are marked as favorites.
	var isFavorite: Bool
	/// Optional to keep future visual treatment decoupled from sensitive fields.
	var palette: CardPalette?

	init(
		id: UUID = UUID(),
		title: String,
		kind: DocumentKind,
		fields: [DocumentField] = [],
		hasFrontImage: Bool = false,
		hasBackImage: Bool = false,
		isArchived: Bool = false,
		sortIndex: Int? = nil,
		isFavorite: Bool = false,
		palette: CardPalette? = nil
	) {
		self.id = id
		self.title = title
		self.kind = kind
		self.fields = fields
		self.hasFrontImage = hasFrontImage
		self.hasBackImage = hasBackImage
		self.isArchived = isArchived
		self.sortIndex = sortIndex
		self.isFavorite = isFavorite
		self.palette = palette
	}

	func hasImage(for side: DocumentAttachmentSide) -> Bool {
		switch side {
		case .front:
			hasFrontImage
		case .back:
			hasBackImage
		}
	}

	mutating func setHasImage(_ hasImage: Bool, for side: DocumentAttachmentSide) {
		switch side {
		case .front:
			hasFrontImage = hasImage
		case .back:
			hasBackImage = hasImage
		}
	}

	private enum CodingKeys: String, CodingKey {
		case id, title, kind, fields, hasFrontImage, hasBackImage, isArchived, sortIndex, isFavorite, palette
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		title = try container.decode(String.self, forKey: .title)
		kind = try container.decode(DocumentKind.self, forKey: .kind)
		fields = try container.decodeIfPresent([DocumentField].self, forKey: .fields) ?? []
		hasFrontImage = try container.decodeIfPresent(Bool.self, forKey: .hasFrontImage) ?? false
		hasBackImage = try container.decodeIfPresent(Bool.self, forKey: .hasBackImage) ?? false
		isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex)
		isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
		palette = try container.decodeIfPresent(CardPalette.self, forKey: .palette)
	}
}
