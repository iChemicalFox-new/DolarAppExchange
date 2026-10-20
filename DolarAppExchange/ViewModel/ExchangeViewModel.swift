import Foundation
import Observation

@MainActor
@Observable
final class ExchangeViewModel {
    private(set) var currencies: [String] = []
    private(set) var selectedCurrency: String = "MXN"
    
    var exchangeRateText: String {
        guard let exchangeRate else {
            return ""
        }

        return "1 USDc = \(formatRate(exchangeRate.bid)) \(selectedCurrency)"
    }

    var usdcAmount: String = ""
    var currencyAmount: String = ""

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isUSDCFirst = true

    private let repository: ExchangeRepositoryProtocol

    private var exchangeRate: ExchangeRate?

    init(repository: ExchangeRepositoryProtocol) {
        self.repository = repository
    }

    convenience init() {
        self.init(repository: ExchangeRepository())
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        currencies = await repository.fetchCurrencies()

        if !currencies.contains(selectedCurrency),
           let firstCurrency = currencies.first {
            selectedCurrency = firstCurrency
        }

        do {
            exchangeRate = try await repository.fetchRate(
                for: selectedCurrency
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectCurrency(_ currency: String) async {
        guard currency != selectedCurrency else { return }

        selectedCurrency = currency
        isLoading = true
        errorMessage = nil

        do {
            exchangeRate = try await repository.fetchRate(for: currency)
            recalculate()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateUSDCAmount(_ value: String) {
        usdcAmount = value

        guard let amount = decimal(from: value), let bid = exchangeRate?.bid else {
            currencyAmount = ""
            
            return
        }

        currencyAmount = formatAmount(amount * bid)
    }

    func updateCurrencyAmount(_ value: String) {
        currencyAmount = value

        guard let amount = decimal(from: value), let ask = exchangeRate?.ask, ask != 0 else {
            usdcAmount = ""
            
            return
        }

        usdcAmount = formatAmount(amount / ask)
    }

    func swap() {
        isUSDCFirst.toggle()
    }

    private func recalculate() {
        if !usdcAmount.isEmpty {
            updateUSDCAmount(usdcAmount)
        } else if !currencyAmount.isEmpty {
            updateCurrencyAmount(currencyAmount)
        }
    }

    private func decimal(from value: String) -> Decimal? {
        Decimal(string: value.replacingOccurrences(of: ",", with: "."))
    }

    private func format(_ value: Decimal) -> String { // not used
        NSDecimalNumber(decimal: value)
            .rounding(accordingToBehavior: nil)
            .stringValue
    }
    
    private func formatAmount(_ value: Decimal) -> String {
        print("*** print FORMAT VALUE:", value)
        
        return value.formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .grouping(.automatic)
                .precision(.fractionLength(0...2))
        )
    }

    
    private func formatRate(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
