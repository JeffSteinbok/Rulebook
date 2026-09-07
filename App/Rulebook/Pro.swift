import Foundation
import StoreKit

/// What the user was trying to do when the paywall appeared.
///
/// Carried so the sheet can name the blocked action. "Unlock editing" with no
/// context reads as a toll booth; "Turning a rule off needs Rulebook Pro" reads
/// as an answer to what just happened.
enum PaywallTrigger: String, Identifiable {
    case editing, toggle, delete, reorder, duplicate, bulk

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .editing:   return "Editing rules needs Pro"
        case .toggle:    return "Turning rules on and off needs Pro"
        case .delete:    return "Deleting rules needs Pro"
        case .reorder:   return "Reordering rules needs Pro"
        case .duplicate: return "Duplicating rules needs Pro"
        case .bulk:      return "Changing several rules needs Pro"
        }
    }
}

/// The one entitlement Rulebook sells: everything that writes to the mailbox.
///
/// Reading stays free on purpose. Seeing your real rules in plain language —
/// and being told which ones quietly stopped working — is the thing worth
/// having before anyone pays, and an app whose free tier shows only canned
/// sample data is a paywall with a screenshot behind it.
@MainActor
@Observable
final class ProStore {

    static let productID = "net.steinbok.Rulebook.pro"

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var isWorking = false
    var errorMessage: String?

    /// Nothing was bought — the entitlement is simply not enforced. Used by the
    /// demo seed and previews, where StoreKit isn't running at all.
    private let alwaysUnlocked: Bool

    private var updatesTask: Task<Void, Never>?

    init(alwaysUnlocked: Bool = false) {
        self.alwaysUnlocked = alwaysUnlocked
        self.isPro = alwaysUnlocked
    }

    // No deinit cancelling `updatesTask`: the store lives for the life of the
    // app, and under Swift 6 a nonisolated deinit can't touch main-actor state
    // anyway. `stop()` exists for tests that need to tear one down.
    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    var displayPrice: String { product?.displayPrice ?? "" }

    func start() async {
        guard !alwaysUnlocked else { return }

        // Started before the first refresh so a purchase completing elsewhere —
        // Ask to Buy approved later, or a restore on another device — is seen.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.refresh()
            }
        }

        await loadProduct()
        await refresh()
    }

    func loadProduct() async {
        guard !alwaysUnlocked else { return }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Not surfaced: a missing product means the buy button stays out of
            // the way, and the app is still fully useful for reading.
            product = nil
        }
    }

    /// Recomputed from StoreKit rather than cached in defaults. `currentEntitlements`
    /// is served from the on-device receipt, so this works with no network —
    /// which matters, because a paid user opening the app on a plane must not
    /// find their app locked.
    func refresh() async {
        guard !alwaysUnlocked else { return }
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    func purchase() async {
        guard let product, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "That purchase couldn't be verified. Nothing was charged."
                    return
                }
                await transaction.finish()
                await refresh()
            case .userCancelled:
                break                       // not an error; say nothing
            case .pending:
                // Ask to Buy, or a payment needing approval. The updates task
                // above is what eventually unlocks it.
                errorMessage = "This purchase is waiting for approval. Rulebook will unlock once it goes through."
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Required by App Store guideline 3.1.1, and the most common reason an
    /// in-app purchase is rejected.
    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refresh()
            if !isPro {
                errorMessage = "No previous purchase found for this Apple Account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
