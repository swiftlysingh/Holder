import Foundation
import SinghDevKit
import SwiftUI

enum HolderOnboardingAudience: String, Identifiable, Sendable {
	case newUser = "new_user"
	case update
	case replay

	var id: String { rawValue }

	var usesUpdateCopy: Bool {
		self == .update
	}
}

struct HolderOnboardingStore {
	static let currentRelease = 203
	static let completedReleaseKey = "holder.onboarding.completedRelease"
	static let legacyCompletionKey = "sdk.onboarding.completed"
	static let legacyFirstLaunchKey = "isFirstLaunch"

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func automaticAudience() -> HolderOnboardingAudience? {
		guard defaults.integer(forKey: Self.completedReleaseKey) < Self.currentRelease else {
			return nil
		}

		let hasLaunchedAnOlderVersion = defaults.bool(forKey: Self.legacyCompletionKey)
			|| defaults.object(forKey: Self.legacyFirstLaunchKey) != nil
		return hasLaunchedAnOlderVersion ? .update : .newUser
	}

	func markAutomaticOnboardingComplete() {
		let latestCompletedRelease = max(
			defaults.integer(forKey: Self.completedReleaseKey),
			Self.currentRelease
		)
		defaults.set(latestCompletedRelease, forKey: Self.completedReleaseKey)
		// Preserve SinghDevKit's established key for users who move between app versions.
		defaults.set(true, forKey: Self.legacyCompletionKey)
	}
}

@MainActor
final class HolderAppFlow: ObservableObject {
	@Published var onboardingAudience: HolderOnboardingAudience?
	@Published private(set) var isOnboardingReplayPending = false

	private let onboardingStore: HolderOnboardingStore

	init(onboardingStore: HolderOnboardingStore = HolderOnboardingStore()) {
		self.onboardingStore = onboardingStore
		self.onboardingAudience = onboardingStore.automaticAudience()
	}

	func completeOnboarding(for audience: HolderOnboardingAudience) {
		if audience != .replay {
			onboardingStore.markAutomaticOnboardingComplete()
		}
		onboardingAudience = nil
	}

	func requestOnboardingReplay() {
		guard onboardingAudience != .replay, !isOnboardingReplayPending else { return }
		isOnboardingReplayPending = true
	}

	func presentPendingOnboardingReplay(canPresent: Bool) {
		guard canPresent, isOnboardingReplayPending, onboardingAudience == nil else { return }
		isOnboardingReplayPending = false
		onboardingAudience = .replay
	}
}

struct HolderOnboardingReplayAction {
	private let action: () -> Void

	init(action: @escaping () -> Void = {}) {
		self.action = action
	}

	func callAsFunction() {
		action()
	}
}

private struct HolderOnboardingReplayActionKey: EnvironmentKey {
	static let defaultValue = HolderOnboardingReplayAction()
}

extension EnvironmentValues {
	var holderOnboardingReplayAction: HolderOnboardingReplayAction {
		get { self[HolderOnboardingReplayActionKey.self] }
		set { self[HolderOnboardingReplayActionKey.self] = newValue }
	}
}

extension View {
	func onboardingPresentation(
		audience: Binding<HolderOnboardingAudience?>,
		hasStoredCards: Bool?,
		privacyPolicyURL: URL?,
		onPresented: @escaping (HolderOnboardingAudience) -> Void,
		onSkip: @escaping (HolderOnboardingAudience) -> Void,
		onStartAddingCard: @escaping (HolderOnboardingAudience, CardEditorStartMode) -> Void,
		onDismiss: @escaping () -> Void
	) -> some View {
		modifier(
			HolderOnboardingPresentationModifier(
				audience: audience,
				hasStoredCards: hasStoredCards,
				privacyPolicyURL: privacyPolicyURL,
				onPresented: onPresented,
				onSkip: onSkip,
				onStartAddingCard: onStartAddingCard,
				onDismiss: onDismiss
			)
		)
	}
}

private struct HolderOnboardingPresentationModifier: ViewModifier {
	@Binding var audience: HolderOnboardingAudience?
	let hasStoredCards: Bool?
	let privacyPolicyURL: URL?
	let onPresented: (HolderOnboardingAudience) -> Void
	let onSkip: (HolderOnboardingAudience) -> Void
	let onStartAddingCard: (HolderOnboardingAudience, CardEditorStartMode) -> Void
	let onDismiss: () -> Void

	func body(content: Content) -> some View {
		#if os(iOS)
		content.fullScreenCover(item: $audience, onDismiss: onDismiss) { presentedAudience in
			onboardingView(for: presentedAudience)
				.interactiveDismissDisabled()
		}
		#else
		content.sheet(item: $audience, onDismiss: onDismiss) { presentedAudience in
			onboardingView(for: presentedAudience)
				.frame(minWidth: 560, minHeight: 680)
				.interactiveDismissDisabled()
		}
		#endif
	}

	private func onboardingView(for presentedAudience: HolderOnboardingAudience) -> some View {
		HolderOnboardingView(
			audience: presentedAudience,
			hasStoredCards: hasStoredCards,
			privacyPolicyURL: privacyPolicyURL,
			onPresented: { onPresented(presentedAudience) },
			onSkip: { onSkip(presentedAudience) },
			onStartAddingCard: { mode in
				onStartAddingCard(presentedAudience, mode)
			}
		)
	}
}

struct HolderOnboardingView: View {
	let audience: HolderOnboardingAudience
	let hasStoredCards: Bool?
	let privacyPolicyURL: URL?
	let onPresented: () -> Void
	let onSkip: () -> Void
	let onStartAddingCard: (CardEditorStartMode) -> Void

	private enum Page: Int, Equatable {
		case welcome
		case getStarted
	}

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@AccessibilityFocusState private var isPageHeadingFocused: Bool
	@State private var page = Self.initialPage
	@State private var didReportPresentation = false

	private static var initialPage: Page {
		#if DEBUG
		// The scanner CTA is hardware-gated, so Simulator captures need a stable second-page state.
		if ProcessInfo.processInfo.arguments.contains("-holderShowOnboardingGetStarted") {
			return .getStarted
		}
		#endif
		return .welcome
	}

	var body: some View {
		ZStack {
			background
			VStack(spacing: 0) {
				OnboardingProgressIndicator(
					progress: page == .welcome ? 0.5 : 1
				)
				.padding(.horizontal, 24)
				.padding(.top, 16)

				if dynamicTypeSize.isAccessibilitySize {
					ScrollView {
						VStack(spacing: 0) {
							pageContent
								.frame(maxWidth: 560)
								.frame(maxWidth: .infinity)
								.padding(.horizontal, 24)
								.padding(.vertical, 12)

							actions
						}
					}
					.scrollBounceBehavior(.basedOnSize)
				} else {
					GeometryReader { proxy in
						ScrollView {
							pageContent
								.frame(maxWidth: 560)
								.frame(maxWidth: .infinity)
								.padding(.horizontal, 24)
								.padding(.vertical, 12)
								.frame(minHeight: proxy.size.height, alignment: .center)
						}
						.scrollBounceBehavior(.basedOnSize)
					}

					actions
				}
			}
		}
		#if os(iOS)
		.sensoryFeedback(.selection, trigger: page)
		#endif
		.onAppear {
			guard !didReportPresentation else { return }
			didReportPresentation = true
			onPresented()
		}
	}

	private var background: some View {
		LinearGradient(
			colors: [
				Color.accentColor.opacity(0.08),
				Color.accentColor.opacity(0.02),
				Color.clear
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
		.ignoresSafeArea()
	}

	private var pageContent: some View {
		VStack(spacing: 20) {
			if !dynamicTypeSize.isAccessibilitySize {
				OnboardingCardArtwork(
					showsScanner: page == .getStarted && supportsScanner
				)
			}

			Group {
				switch page {
				case .welcome:
					welcomePage
						.sdkScreen(AppAnalyticsScreen.onboardingWelcome)
				case .getStarted:
					getStartedPage
						.sdkScreen(AppAnalyticsScreen.onboardingGetStarted)
				}
			}
			.id(page)
			.transition(pageTransition)
		}
	}

	private var welcomePage: some View {
		VStack(spacing: 16) {
			VStack(spacing: 8) {
				if let welcomeEyebrow {
					Text(welcomeEyebrow)
						.font(.caption.weight(.semibold))
						.foregroundStyle(Color.accentColor)
				}
				Text(welcomeTitle)
					.font(.title2.bold())
					.multilineTextAlignment(.center)
					.accessibilityAddTraits(.isHeader)
					.accessibilityFocused($isPageHeadingFocused)
				Text(welcomeSubtitle)
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private var getStartedPage: some View {
		VStack(spacing: 14) {
			Text(getStartedTitle)
				.font(.title2.bold())
				.multilineTextAlignment(.center)
				.accessibilityAddTraits(.isHeader)
				.accessibilityFocused($isPageHeadingFocused)
			Text(getStartedSubtitle)
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private var actions: some View {
		VStack(spacing: 10) {
			if page == .welcome {
				Button {
					move(to: .getStarted)
				} label: {
					HStack {
						Text("Continue")
						Spacer()
						Image(systemName: "arrow.right")
					}
					.frame(maxWidth: .infinity)
				}
				.controlSize(.large)
				.onboardingGlassButtonStyle()
				.tint(Color.accentColor)
				.fontWeight(.semibold)
				.accessibilityHint("Shows ways to add a card")

				welcomeReassurance
			} else {
				if supportsScanner {
					Button {
						onStartAddingCard(.scanner)
					} label: {
						Label("Scan a Card", systemImage: "camera.viewfinder")
							.frame(maxWidth: .infinity)
					}
					.controlSize(.large)
					.onboardingProminentGlassButtonStyle()
					.tint(Color.accentColor)
				} else {
					Button {
						onStartAddingCard(.manual)
					} label: {
						Label("Enter Card Details", systemImage: "square.and.pencil")
							.frame(maxWidth: .infinity)
					}
					.controlSize(.large)
					.onboardingProminentGlassButtonStyle()
					.tint(Color.accentColor)
				}

				Button(action: onSkip) {
					Text("Skip")
						.frame(maxWidth: .infinity)
				}
				.controlSize(.large)
				.onboardingGlassButtonStyle()
				.tint(Color.accentColor)

				reviewReassurance
			}
		}
		.frame(maxWidth: 560)
		.padding(.horizontal, 24)
		.padding(.top, 8)
		.padding(.bottom, 12)
		.frame(maxWidth: .infinity)
	}

	private var welcomeReassurance: some View {
		VStack(spacing: 0) {
			Label(welcomeSecurityMessage, systemImage: welcomeSecuritySymbol)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)

			if let privacyPolicyURL {
				Link(destination: privacyPolicyURL) {
					Text("Privacy Policy")
						.frame(minHeight: 44)
						.contentShape(Rectangle())
				}
				.fontWeight(.semibold)
			}
		}
		.font(.footnote.weight(.medium))
		.frame(maxWidth: 420)
	}

	private var reviewReassurance: some View {
		Label(reviewMessage, systemImage: "checkmark.shield.fill")
			.font(.footnote.weight(.medium))
			.foregroundStyle(.secondary)
			.multilineTextAlignment(.center)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: 420)
	}

	private var pageTransition: AnyTransition {
		guard !reduceMotion else { return .opacity }
		return .asymmetric(
			insertion: .offset(y: 12).combined(with: .opacity),
			removal: .opacity
		)
	}

	private func move(to newPage: Page) {
		isPageHeadingFocused = false
		withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.4)) {
			page = newPage
		}
		Task { @MainActor in
			await Task.yield()
			isPageHeadingFocused = true
		}
	}

	private var supportsScanner: Bool {
		CardScanningEngineFactory.isScanningAvailable
	}

	private var welcomeEyebrow: String? {
		switch audience {
		case .newUser:
			return nil
		case .update:
			return "New in Holder 2.3"
		case .replay:
			return "Holder introduction"
		}
	}

	private var welcomeTitle: String {
		switch audience {
		case .newUser:
			return "Your cards, close at hand"
		case .update:
			return supportsScanner
				? "A faster way to add a card"
				: "A simpler way to add a card"
		case .replay:
			return "A quick look at Holder"
		}
	}

	private var welcomeSubtitle: String {
		switch audience {
		case .newUser:
			return "Keep payment, membership, and ID cards together, ready when you need them."
		case .update:
			return supportsScanner
				? "Scan a card, check the details, then save only what you want."
				: "Enter and review card details in one simple flow."
		case .replay:
			return "Keep the card details you use together, private, and easy to find."
		}
	}

	private var welcomeSecurityMessage: String {
		if audience.usesUpdateCopy {
			return supportsScanner
				? "Recognition stays on this device."
				: "Scanning works on supported devices."
		}
		return "Stored in Apple's Keychain."
	}

	private var welcomeSecuritySymbol: String {
		if audience.usesUpdateCopy && !supportsScanner {
			return "iphone.gen3"
		}
		return audience.usesUpdateCopy ? "checkmark.shield.fill" : "lock.shield.fill"
	}

	private var getStartedTitle: String {
		if audience.usesUpdateCopy && supportsScanner {
			return "Try the new card scanner"
		}
		if hasStoredCards == true {
			return "Add another card"
		}
		if hasStoredCards == false {
			return "Add your first card"
		}
		return "Add a card"
	}

	private var getStartedSubtitle: String {
		if supportsScanner {
			return "Point your camera at the front. Holder fills what it can, then opens every field for review."
		}
		return "Enter the details you want, then review and save."
	}

	private var reviewMessage: String {
		supportsScanner
			? "Nothing is saved until you tap Done."
			: "Nothing is saved until you finish editing."
	}
}

private struct OnboardingProgressIndicator: View {
	let progress: CGFloat
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		GeometryReader { proxy in
			ZStack(alignment: .leading) {
				Capsule()
					.fill(Color.accentColor.opacity(0.14))
				Capsule()
					.fill(Color.accentColor)
					.frame(width: proxy.size.width * min(max(progress, 0), 1))
			}
		}
		.frame(height: 3)
		.animation(
			reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.35),
			value: progress
		)
		.accessibilityElement()
		.accessibilityLabel("Introduction progress")
		.accessibilityValue(progress < 1 ? "Step 1 of 2" : "Step 2 of 2")
	}
}

private struct OnboardingCardArtwork: View {
	let showsScanner: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ViewThatFits(in: .horizontal) {
			artwork
			artwork
				.scaleEffect(0.82)
				.frame(width: 230, height: 124)
		}
		.animation(
			reduceMotion ? .easeOut(duration: 0.18) : .snappy(duration: 0.42),
			value: showsScanner
		)
		.accessibilityHidden(true)
	}

	private var artwork: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 21, style: .continuous)
				.fill(Color.accentColor.opacity(0.12))
				.frame(width: 202, height: 126)
				.rotationEffect(.degrees(-6))

			RoundedRectangle(cornerRadius: 21, style: .continuous)
				.fill(.background)
				.overlay {
					RoundedRectangle(cornerRadius: 21, style: .continuous)
						.stroke(Color.primary.opacity(0.08), lineWidth: 1)
				}
				.shadow(color: .black.opacity(0.11), radius: 15, y: 8)
				.frame(width: 202, height: 126)
				.overlay(alignment: .topLeading) {
					Image(systemName: "creditcard.fill")
						.font(.title3)
						.foregroundStyle(Color.accentColor)
						.padding(17)
				}
				.overlay(alignment: .bottomLeading) {
					VStack(alignment: .leading, spacing: 5) {
						Text("•••• 4821")
							.font(.system(size: 16, weight: .semibold, design: .monospaced))
						Text("YOUR CARD")
							.font(.system(size: 9, weight: .bold))
							.tracking(1)
							.foregroundStyle(.secondary)
					}
					.padding(17)
				}
				.offset(x: showsScanner && !reduceMotion ? -7 : 0)

			if showsScanner {
				Image(systemName: "camera.viewfinder")
					.font(.system(size: 50, weight: .light))
					.foregroundStyle(Color.accentColor)
					.padding(11)
					.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
					.shadow(color: .black.opacity(0.09), radius: 10, y: 5)
					.offset(x: 78, y: 46)
					.transition(
						reduceMotion
							? .opacity
							: .scale(scale: 0.82).combined(with: .opacity)
					)
			}
		}
		.frame(width: 280, height: 150)
	}
}

private extension View {
	@ViewBuilder
	func onboardingGlassButtonStyle() -> some View {
		if #available(iOS 26.0, macOS 26.0, *) {
			buttonStyle(.glass)
		} else {
			buttonStyle(.bordered)
		}
	}

	@ViewBuilder
	func onboardingProminentGlassButtonStyle() -> some View {
		if #available(iOS 26.0, macOS 26.0, *) {
			buttonStyle(.glassProminent)
		} else {
			buttonStyle(.borderedProminent)
		}
	}
}
