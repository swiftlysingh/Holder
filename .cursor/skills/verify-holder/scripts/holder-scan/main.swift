import Foundation

struct Fixture: Decodable {
	var now: Date
	var editor: EditorState?
	var frames: [[FixtureItem]]
	var still: [FixtureItem]?
	var expect: Expectation
}

struct FixtureItem: Decodable {
	struct Box: Decodable {
		var x: Double
		var y: Double
		var width: Double
		var height: Double
	}

	var text: String
	var candidates: [String]?
	var box: Box?

	var ocrItem: OCRTextItem {
		OCRTextItem(
			text: text,
			candidates: candidates ?? [],
			boundingBox: box.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
		)
	}
}

struct EditorState: Decodable {
	var number: String?
	var cvv: String?
	var expiration: String?
	var name: String?
	var description: String?
	var type: CardType?

	var card: CardData {
		CardData(
			id: UUID(),
			number: number ?? "",
			cvv: cvv ?? "",
			expiration: expiration ?? "",
			name: name ?? "",
			description: description ?? "",
			type: type ?? .credit
		)
	}
}

struct Expectation: Decodable {
	var verified: Bool
	var editor: [String: String]?
}

func editorFields(_ card: CardData) -> [(String, String)] {
	[
		("number", card.number),
		("network", card.network.rawValue),
		("expiration", card.expiration),
		("name", card.name),
		("description", card.description),
		("type", card.type.rawValue),
		("cvv", card.cvv),
	]
}

func describe(_ observation: CardFrameObservation) -> String {
	let pan = observation.pan.map { "lastFour=\(CardScanSession.lastFour(of: $0)) network=\(CardPAN.network(for: $0).rawValue)" } ?? "pan=none"
	return "\(pan) expiry=\(observation.expiry ?? "none") name=\"\(observation.cardholderName ?? "")\""
}

func run(_ fixture: Fixture, name: String) -> Bool {
	print("HOLDER-SCAN fixture=\(name) now=\(ISO8601DateFormatter().string(from: fixture.now)) frames=\(fixture.frames.count) still=\(fixture.still != nil)")

	var card = (fixture.editor ?? EditorState()).card
	var voter = TemporalPANVoter()
	var attempt = CardScanAttempt()
	var stablePAN: String?

	for (index, frame) in fixture.frames.enumerated() {
		if stablePAN != nil {
			print("FRAME \(index + 1) ignored reason=verifying")
			continue
		}
		let observation = CardCandidateEngine.observe(frame.map(\.ocrItem), now: fixture.now)
		attempt.record(observation)
		print("FRAME \(index + 1) items=\(frame.count) \(describe(observation))")

		guard let pan = observation.pan else { continue }
		print("UPDATE candidate lastFour=\(CardScanSession.lastFour(of: pan)) network=\(CardPAN.network(for: pan).rawValue)")

		guard let winner = voter.record(pan) else { continue }
		stablePAN = winner
		print("UPDATE scanning guidance=\"Card number found. Checking the photo…\"")
	}

	var result: CardScanResult?
	if let livePAN = stablePAN {
		// VisionCardScanningEngine.verifyCurrentCandidate() and merge(still:livePAN:) are private
		// and iOS-only, so this mirrors them. doctor fails on glue drift.
		let stillItems = (fixture.still ?? []).map(\.ocrItem)
		if stillItems.isEmpty {
			print("STILL unavailable")
			result = CardScanSession.result(from: CardFrameObservation(
				pan: livePAN,
				expiry: attempt.latestObservation.expiry,
				cardholderName: nil
			))
		} else {
			let still = CardCandidateEngine.observe(stillItems, now: fixture.now)
			print("STILL items=\(stillItems.count) \(describe(still))")
			if (still.pan == nil || still.pan == livePAN), CardPAN.validatedDigits(livePAN) != nil {
				result = CardScanResult(
					pan: livePAN,
					expiry: still.expiry ?? attempt.latestObservation.expiry,
					cardholderName: still.cardholderName,
					network: CardPAN.network(for: livePAN)
				)
			}
		}

		if let result {
			print("UPDATE verified lastFour=\(result.lastFour) network=\(result.network.rawValue) expiry=\(result.expiry ?? "none") name=\"\(result.cardholderName ?? "")\"")
			CardScanSession.apply(result, to: &card)
		} else {
			print("UPDATE retryableFailure message=\"Could not confirm the card number. Try again.\"")
		}
	} else {
		print("UPDATE none reason=no-stable-pan")
	}

	let fields = editorFields(card)
	print("EDITOR " + fields.map { "\($0.0)=\"\($0.0 == "cvv" ? String(repeating: "•", count: $0.1.count) : $0.1)\"" }.joined(separator: " "))

	var passed = true
	let verified = result != nil
	print("ASSERT verified expected=\(fixture.expect.verified) actual=\(verified) \(verified == fixture.expect.verified ? "ok" : "FAIL")")
	passed = passed && verified == fixture.expect.verified

	let actual = Dictionary(uniqueKeysWithValues: fields)
	for (field, expected) in (fixture.expect.editor ?? [:]).sorted(by: { $0.key < $1.key }) {
		guard let value = actual[field] else {
			print("ASSERT \(field) FAIL reason=unknown-field")
			passed = false
			continue
		}
		let shown = field == "cvv" ? "len=\(value.count)" : "\"\(value)\""
		let want = field == "cvv" ? "len=\(expected.count)" : "\"\(expected)\""
		print("ASSERT \(field) expected=\(want) actual=\(shown) \(value == expected ? "ok" : "FAIL")")
		passed = passed && value == expected
	}

	print("RESULT \(passed ? "pass" : "fail") fixture=\(name)")
	return passed
}

let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "--ready" {
	print("READY holder-scan")
	exit(0)
}
guard arguments.count == 1, let path = arguments.first else {
	FileHandle.standardError.write(Data("usage: holder-scan <fixture.json> | --ready\n".utf8))
	exit(2)
}

do {
	let decoder = JSONDecoder()
	decoder.dateDecodingStrategy = .iso8601
	let fixture = try decoder.decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
	let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
	exit(run(fixture, name: name) ? 0 : 1)
} catch {
	print("RESULT error reason=bad-fixture detail=\"\(error)\"")
	exit(2)
}
