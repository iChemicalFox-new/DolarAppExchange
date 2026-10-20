import Foundation
import Observation

@MainActor
@Observable
final class ExchangeViewModel {
    private enum Field {
        case usdc
        case currency
    }

    private(set) var currencies: [String] = []
    private(set) var selectedCurrency: String = "MXN"

    private(set) var usdcAmount: String = ""
    private(set) var currencyAmount: String = ""

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isUSDCFirst = true

    var exchangeRateText: String {
        guard let exchangeRate else { return "" }

        let rate = isUSDCFirst ? exchangeRate.bid : exchangeRate.ask

        return "1 USDc = \(formatRate(rate)) \(selectedCurrency)"
    }

    private let repository: ExchangeRepositoryProtocol

    private var exchangeRate: ExchangeRate?
    private var lastEditedField: Field = .usdc
    private var rateRequestID = UUID()

    init(repository: ExchangeRepositoryProtocol) {
        self.repository = repository
    }

    convenience init() {
        self.init(repository: ExchangeRepository())
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        let fetchedCurrencies = await repository.fetchCurrencies()
        currencies = fetchedCurrencies

        guard let firstCurrency = fetchedCurrencies.first else {
            errorMessage = "Unable to load currencies."
            isLoading = false
            return
        }

        if !fetchedCurrencies.contains(selectedCurrency) {
            selectedCurrency = firstCurrency
        }

        await loadRate(for: selectedCurrency)
    }

    func selectCurrency(_ currency: String) async {
        guard
            currency != selectedCurrency,
            currencies.contains(currency)
        else {
            return
        }

        selectedCurrency = currency

        await loadRate(for: currency)
    }

    func updateUSDCAmount(_ value: String) {
        usdcAmount = value
        lastEditedField = .usdc

        guard
            let amount = decimal(from: value),
            let exchangeRate
        else {
            currencyAmount = ""
            return
        }

        if isUSDCFirst {
            // Selling USDc → receiving fiat
            currencyAmount = formatAmount(amount * exchangeRate.bid)
        } else {
            // Buying USDc → paying fiat
            currencyAmount = formatAmount(amount * exchangeRate.ask)
        }
    }

    func updateCurrencyAmount(_ value: String) {
        currencyAmount = value
        lastEditedField = .currency

        guard
            let amount = decimal(from: value),
            let exchangeRate
        else {
            usdcAmount = ""
            return
        }

        if isUSDCFirst {
            // Selling USDc → receiving fiat
            guard exchangeRate.bid != 0 else {
                usdcAmount = ""
                return
            }

            usdcAmount = formatAmount(amount / exchangeRate.bid)
        } else {
            // Buying USDc → paying fiat
            guard exchangeRate.ask != 0 else {
                usdcAmount = ""
                return
            }

            usdcAmount = formatAmount(amount / exchangeRate.ask)
        }
    }

    func swap() {
        isUSDCFirst.toggle()
        recalculate()
    }

    // MARK: - Private

    private func loadRate(for currency: String) async {
        let requestID = UUID()
        rateRequestID = requestID

        isLoading = true
        errorMessage = nil

        exchangeRate = nil
        clearCalculatedAmount()

        defer {
            if requestID == rateRequestID {
                isLoading = false
            }
        }

        do {
            let rate = try await repository.fetchRate(for: currency)

            guard requestID == rateRequestID else {
                return
            }

            exchangeRate = rate
            recalculate()
        } catch is CancellationError {
            return
        } catch {
            guard requestID == rateRequestID else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    private func recalculate() {
        switch lastEditedField {
        case .usdc:
            updateUSDCAmount(usdcAmount)

        case .currency:
            updateCurrencyAmount(currencyAmount)
        }
    }

    private func clearCalculatedAmount() {
        switch lastEditedField {
        case .usdc:
            currencyAmount = ""

        case .currency:
            usdcAmount = ""
        }
    }

    private func decimal(from value: String) -> Decimal? {
        let normalized = value
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")

        guard normalized.wholeMatch(of: /\d+(\.\d*)?|\.\d+/) != nil else {
            return nil
        }

        return Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func formatAmount(_ value: Decimal) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .grouping(.never)
                .precision(.fractionLength(0...2))
        )
    }

    private func formatRate(_ value: Decimal) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .grouping(.automatic)
                .precision(.fractionLength(2...6))
        )
    }
}
