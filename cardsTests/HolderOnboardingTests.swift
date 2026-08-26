import Foundation
import XCTest
@testable import Holder

final class HolderOnboardingStoreTests: XCTestCase {
	private var defaults: UserDefaults!
	private var suiteName: String!

	override func setUp() {
		super.setUp()
		suiteName = "HolderOnboardingStoreTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suiteName)
		defaults.removePersistentDomain(forName: suiteName)
	}

	override func tearDown() {
		defaults.removePersistentDomain(forName: suiteName)
		defaults = nil
		suiteName = nil
		super.tearDown()
	}

	func testFreshInstallReceivesEvergreenWelcome() {
		let store = HolderOnboardingStore(defaults: defaults)

		XCTAssertEqual(store.automaticAudience(), .newUser)
	}

	func testLegacyCompletionReceivesUpdateWelcome() {
		defaults.set(true, forKey: HolderOnboardingStore.legacyCompletionKey)
		let store = HolderOnboardingStore(defaults: defaults)

		XCTAssertEqual(store.automaticAudience(), .update)
	}

	func testLegacyFirstLaunchMarkerReceivesUpdateWelcome() {
		defaults.set(false, forKey: HolderOnboardingStore.legacyFirstLaunchKey)
		let store = HolderOnboardingStore(defaults: defaults)

		XCTAssertEqual(store.automaticAudience(), .update)
	}

	func testCompletedCurrentReleaseDoesNotPresentAutomatically() {
		defaults.set(
			HolderOnboardingStore.currentRelease,
			forKey: HolderOnboardingStore.completedReleaseKey
		)
		let store = HolderOnboardingStore(defaults: defaults)

		XCTAssertNil(store.automaticAudience())
	}

	func testLaterCompletedReleaseDoesNotRegressAfterDowngrade() {
		defaults.set(
			HolderOnboardingStore.currentRelease + 1,
			forKey: HolderOnboardingStore.completedReleaseKey
		)
		let store = HolderOnboardingStore(defaults: defaults)

		XCTAssertNil(store.automaticAudience())
	}

	func testCompletionRecordsReleaseAndMigratesLegacyKey() {
		let store = HolderOnboardingStore(defaults: defaults)

		store.markAutomaticOnboardingComplete()

		XCTAssertEqual(
			defaults.integer(forKey: HolderOnboardingStore.completedReleaseKey),
			HolderOnboardingStore.currentRelease
		)
		XCTAssertTrue(defaults.bool(forKey: HolderOnboardingStore.legacyCompletionKey))
	}

	func testCompletionPreservesLaterRelease() {
		let laterRelease = HolderOnboardingStore.currentRelease + 1
		defaults.set(laterRelease, forKey: HolderOnboardingStore.completedReleaseKey)
		let store = HolderOnboardingStore(defaults: defaults)

		store.markAutomaticOnboardingComplete()

		XCTAssertEqual(
			defaults.integer(forKey: HolderOnboardingStore.completedReleaseKey),
			laterRelease
		)
	}
}

@MainActor
final class HolderAppFlowTests: XCTestCase {
	func testReplayDoesNotMarkAutomaticOnboardingComplete() {
		let suiteName = "HolderAppFlowTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(
			HolderOnboardingStore.currentRelease,
			forKey: HolderOnboardingStore.completedReleaseKey
		)
		let flow = HolderAppFlow(
			onboardingStore: HolderOnboardingStore(defaults: defaults)
		)

		flow.requestOnboardingReplay()
		flow.presentPendingOnboardingReplay(canPresent: true)
		flow.completeOnboarding(for: .replay)

		XCTAssertEqual(
			defaults.integer(forKey: HolderOnboardingStore.completedReleaseKey),
			HolderOnboardingStore.currentRelease
		)
		XCTAssertFalse(defaults.bool(forKey: HolderOnboardingStore.legacyCompletionKey))
		XCTAssertNil(flow.onboardingAudience)
	}

	func testReplayWaitsUntilAnotherPresentationFinishes() {
		let suiteName = "HolderAppFlowTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(
			HolderOnboardingStore.currentRelease,
			forKey: HolderOnboardingStore.completedReleaseKey
		)
		let flow = HolderAppFlow(
			onboardingStore: HolderOnboardingStore(defaults: defaults)
		)

		flow.requestOnboardingReplay()
		flow.presentPendingOnboardingReplay(canPresent: false)

		XCTAssertTrue(flow.isOnboardingReplayPending)
		XCTAssertNil(flow.onboardingAudience)

		flow.presentPendingOnboardingReplay(canPresent: true)

		XCTAssertFalse(flow.isOnboardingReplayPending)
		XCTAssertEqual(flow.onboardingAudience, .replay)
	}

	func testReplayDoesNotQueueItselfWhileAlreadyPresented() {
		let suiteName = "HolderAppFlowTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(
			HolderOnboardingStore.currentRelease,
			forKey: HolderOnboardingStore.completedReleaseKey
		)
		let flow = HolderAppFlow(
			onboardingStore: HolderOnboardingStore(defaults: defaults)
		)

		flow.requestOnboardingReplay()
		flow.presentPendingOnboardingReplay(canPresent: true)
		flow.requestOnboardingReplay()
		flow.completeOnboarding(for: .replay)
		flow.presentPendingOnboardingReplay(canPresent: true)

		XCTAssertFalse(flow.isOnboardingReplayPending)
		XCTAssertNil(flow.onboardingAudience)
	}
}
