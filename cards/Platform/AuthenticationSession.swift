//
//  AuthenticationSession.swift
//  cards
//
//  Shared vault and sensitive-access authentication state.
//

import LocalAuthentication
import SwiftUI

protocol DeviceAuthenticating: AnyObject {
    func canEvaluateDeviceOwnerAuthentication() -> Bool
    func evaluateDeviceOwnerAuthentication(reason: String, reply: @escaping (Bool) -> Void)
    func invalidate()
}

protocol DeviceAuthenticatorFactory {
    func makeAuthenticator() -> DeviceAuthenticating
}

protocol AsyncSleeper {
    func sleep(for duration: Duration) async throws
}

struct TaskAsyncSleeper: AsyncSleeper {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

final class LADeviceAuthenticator: DeviceAuthenticating {
    private let context = LAContext()

    func canEvaluateDeviceOwnerAuthentication() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func evaluateDeviceOwnerAuthentication(reason: String, reply: @escaping (Bool) -> Void) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            reply(success)
        }
    }

    func invalidate() {
        context.invalidate()
    }
}

struct DefaultDeviceAuthenticatorFactory: DeviceAuthenticatorFactory {
    func makeAuthenticator() -> DeviceAuthenticating {
        LADeviceAuthenticator()
    }
}

@MainActor
final class AuthenticationSession: ObservableObject {
    static let vaultGracePeriod: Duration = .seconds(60)
    static let sensitiveAccessDuration: Duration = .seconds(60)

    @Published private(set) var isVaultUnlocked = false
    @Published private(set) var isSensitiveAccessFresh = false
    @Published private(set) var isPrivacyCurtainVisible = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authenticationMessage: String?

    private let authenticatorFactory: DeviceAuthenticatorFactory
    private let sleeper: AsyncSleeper
    private var activeAuthenticator: DeviceAuthenticating?
    private var authenticationAttemptID: UInt64 = 0
    private var backgroundedAt: ContinuousClock.Instant?
    private var sensitiveExpiryTask: Task<Void, Never>?

    init(
        authenticatorFactory: DeviceAuthenticatorFactory = DefaultDeviceAuthenticatorFactory(),
        sleeper: AsyncSleeper = TaskAsyncSleeper()
    ) {
        self.authenticatorFactory = authenticatorFactory
        self.sleeper = sleeper
    }

    deinit {
        activeAuthenticator?.invalidate()
        sensitiveExpiryTask?.cancel()
    }

    func coverForPrivacy() {
        isPrivacyCurtainVisible = true
    }

    func didEnterBackground(at now: ContinuousClock.Instant = ContinuousClock().now) {
        backgroundedAt = now
        isPrivacyCurtainVisible = true
        revokeSensitiveAccess()
        invalidateAuthenticationAttempt()
    }

    func didBecomeActive(
        vaultLockEnabled: Bool,
        at now: ContinuousClock.Instant = ContinuousClock().now
    ) {
        if !vaultLockEnabled {
            backgroundedAt = nil
            isVaultUnlocked = true
            isPrivacyCurtainVisible = false
            return
        }

        isPrivacyCurtainVisible = false
        guard !isAuthenticating else { return }

        if let backgroundedAt {
            let elapsed = backgroundedAt.duration(to: now)
            self.backgroundedAt = nil

            if isVaultUnlocked && elapsed <= Self.vaultGracePeriod {
                isPrivacyCurtainVisible = false
                return
            }

            isVaultUnlocked = false
        }

        if !isVaultUnlocked {
            authenticateToUnlockVault()
        }
    }

    func vaultLockSettingChanged(isEnabled: Bool) {
        if isEnabled {
            lockVault()
        } else {
            invalidateAuthenticationAttempt()
            backgroundedAt = nil
            isVaultUnlocked = true
            isPrivacyCurtainVisible = false
        }
    }

    func authenticateToUnlockVault() {
        authenticate(reason: "Authenticate to open Holder.") { [weak self] success in
            guard let self else { return }
            if success {
                isVaultUnlocked = true
                beginSensitiveAccessWindow()
            }
            isPrivacyCurtainVisible = false
        }
    }

    func authenticateForSensitiveAccess(
        reason: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        if isSensitiveAccessFresh {
            completion?(true)
            return
        }

        authenticate(reason: reason) { [weak self] success in
            guard let self else { return }
            if success {
                beginSensitiveAccessWindow()
            }
            completion?(success)
        }
    }

    func lockVault() {
        backgroundedAt = nil
        isVaultUnlocked = false
        revokeSensitiveAccess()
        invalidateAuthenticationAttempt()
    }

    func revokeSensitiveAccess() {
        sensitiveExpiryTask?.cancel()
        sensitiveExpiryTask = nil
        isSensitiveAccessFresh = false
    }

    private func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        invalidateAuthenticationAttempt()
        authenticationMessage = nil

        let authenticator = authenticatorFactory.makeAuthenticator()
        activeAuthenticator = authenticator
        isAuthenticating = true
        let attemptID = authenticationAttemptID

        guard authenticator.canEvaluateDeviceOwnerAuthentication() else {
            authenticator.invalidate()
            activeAuthenticator = nil
            isAuthenticating = false
            authenticationMessage = "Authentication isn’t available on this device."
            completion(false)
            return
        }

        authenticator.evaluateDeviceOwnerAuthentication(reason: reason) { [weak self] success in
            Task { @MainActor in
                guard let self, attemptID == self.authenticationAttemptID else { return }
                self.activeAuthenticator = nil
                self.isAuthenticating = false
                self.authenticationMessage = success ? nil : "Authentication wasn’t completed. Try again when you’re ready."
                completion(success)
            }
        }
    }

    private func beginSensitiveAccessWindow() {
        sensitiveExpiryTask?.cancel()
        isSensitiveAccessFresh = true
        let sleeper = self.sleeper
        sensitiveExpiryTask = Task { @MainActor [weak self, sleeper] in
            do {
                try await sleeper.sleep(for: Self.sensitiveAccessDuration)
            } catch {
                guard !Task.isCancelled else { return }
                self?.revokeSensitiveAccess()
                return
            }
            guard !Task.isCancelled else { return }
            self?.revokeSensitiveAccess()
        }
    }

    private func invalidateAuthenticationAttempt() {
        authenticationAttemptID &+= 1
        activeAuthenticator?.invalidate()
        activeAuthenticator = nil
        isAuthenticating = false
    }
}

struct VaultProtectedView<Content: View>: View {
    @ObservedObject var session: AuthenticationSession
    @AppStorage("isAuthEnabled") private var isVaultLockEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(
        session: AuthenticationSession,
        @ViewBuilder content: () -> Content
    ) {
        self.session = session
        self.content = content()
    }

    var body: some View {
        ZStack {
            if isContentVisible {
                content
                    .allowsHitTesting(!session.isPrivacyCurtainVisible)
                    .accessibilityHidden(session.isPrivacyCurtainVisible)
            } else {
                lockView
            }

            if session.isPrivacyCurtainVisible {
                privacyCurtain
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            guard scenePhase == .active else { return }
            session.didBecomeActive(vaultLockEnabled: isVaultLockEnabled)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                session.didBecomeActive(vaultLockEnabled: isVaultLockEnabled)
            case .inactive:
                session.coverForPrivacy()
                #if os(macOS)
                if !session.isAuthenticating {
                    session.didEnterBackground()
                }
                #endif
            case .background:
                session.didEnterBackground()
            @unknown default:
                session.coverForPrivacy()
            }
        }
        .onChange(of: isVaultLockEnabled) { _, isEnabled in
            session.vaultLockSettingChanged(isEnabled: isEnabled)
        }
    }

    private var isContentVisible: Bool {
        session.isVaultUnlocked || !isVaultLockEnabled
    }

    private var lockView: some View {
        ZStack {
            platformBackground
                .ignoresSafeArea()

            blurredHomeBackdrop

            Button {
                session.authenticateToUnlockVault()
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Holder is locked")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(44)
            }
            .buttonStyle(.plain)
            .disabled(session.isAuthenticating)
            .accessibilityLabel(lockAccessibilityLabel)
            .accessibilityHint("Tap to authenticate and open Holder")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockAccessibilityLabel: String {
        if session.isAuthenticating {
            return "Authenticating"
        }
        if session.authenticationMessage != nil {
            return "Authentication failed. Holder is locked"
        }
        return "Holder is locked"
    }

    private var blurredHomeBackdrop: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Cards")
                    .font(.largeTitle.bold())
                Spacer()
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }

            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.26))
                            .frame(width: 44, height: 34)

                        VStack(alignment: .leading, spacing: 8) {
                            Capsule()
                                .fill(Color.primary.opacity(0.3))
                                .frame(width: index.isMultiple(of: 2) ? 132 : 164, height: 12)
                            Capsule()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 92, height: 10)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(
                        Color.primary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 620, maxHeight: .infinity, alignment: .top)
        .blur(radius: 6)
        .opacity(0.9)
        .scaleEffect(1.04)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var privacyCurtain: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Holder")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(platformBackground)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Holder is protected")
    }

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}
