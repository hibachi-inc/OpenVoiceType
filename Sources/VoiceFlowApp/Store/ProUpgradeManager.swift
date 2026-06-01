import StoreKit
import os

private let logger = Logger(subsystem: "com.hibachi.voiceflow", category: "ProUpgrade")

@MainActor
@Observable
final class ProUpgradeManager {
    static let shared = ProUpgradeManager()

    static let productID = "com.hibachi.openvoicetext.pro"

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var purchaseState: PurchaseState = .unknown
    private var updatesTask: Task<Void, Never>?

    enum PurchaseState {
        case unknown, loading, available, purchased, failed(String)
    }

    private init() {
        updatesTask = Task {
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    await refreshPurchaseState()
                    await transaction.finish()
                case .unverified(_, let error):
                    logger.warning("Unverified transaction: \(error.localizedDescription)")
                    await refreshPurchaseState()
                }
            }
        }
        Task {
            await loadProduct()
            await refreshPurchaseState()
        }
    }

    func loadProduct() async {
        purchaseState = .loading
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if product != nil && !isPro {
                purchaseState = .available
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func purchase() async {
        guard let product else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await refreshPurchaseState()
                await transaction.finish()
                logger.info("Purchase successful")
            case .userCancelled:
                logger.info("Purchase cancelled by user")
            case .pending:
                logger.info("Purchase pending approval")
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseState = .failed(error.localizedDescription)
            await refreshPurchaseState()
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseState()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }

    func refreshPurchaseState() async {
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue,
               transaction.productID == Self.productID {
                isPro = true
                purchaseState = .purchased
                logger.info("Pro entitlement verified")
                return
            }
        }
        isPro = false
        if product != nil {
            purchaseState = .available
        }
    }
}
