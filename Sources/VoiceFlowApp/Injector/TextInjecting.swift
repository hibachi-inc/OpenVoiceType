import Foundation

@MainActor
protocol TextInjecting {
    func inject(_ text: String)
}
