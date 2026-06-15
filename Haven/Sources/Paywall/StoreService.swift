import Foundation
import StoreKit

@MainActor
@Observable
final class StoreService {
    static let productIDs = ["haven.yearly", "haven.weekly"]
    private(set) var products: [Product] = []
    private(set) var purchasing = false

    func load() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
        products.sort { $0.id < $1.id }   // weekly < yearly alphabetically? ensure stable; reorder in UI
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Returns the transaction id on success, nil on cancel/failure.
    func purchase(_ id: String) async -> String? {
        guard let product = product(id) else { return nil }
        purchasing = true; defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return String(transaction.id)
                }
                return nil
            default: return nil
            }
        } catch { return nil }
    }

    func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified = result { return true }
        }
        return false
    }
}
