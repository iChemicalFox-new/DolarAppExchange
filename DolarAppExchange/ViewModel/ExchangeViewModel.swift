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
    private(set) var selectedCurrency = "MXN"
    private(set) var usdcAmount = ""
    private(set) var currencyAmount = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isUSDCFirst = true

    var exchangeRateText: String {
        guard let rate = activeRate else { return "" }
        return "1 USDc = \(formatRate(rate)) \(selectedCurrency)"
    }

    private let repository: ExchangeRepositoryProtocol
    private var exchangeRate: ExchangeRate?
    private var lastEditedField: Field = .usdc
    private var requestID = UUID()

    // The upper field is what the user sells; editing either field keeps this direction.
    private var activeRate: Decimal? {
        guard let exchangeRate else { return nil }
        return isUSDCFirst ? exchangeRate.bid : exchangeRate.ask
    }

    init(repository: ExchangeRepositoryProtocol) {
        self.repository = repository
    }

    convenience init() {
        self.init(repository: ExchangeRepository())
    }

    func load() async {
        guard !Task.isCancelled else { return }
        let id = beginRequest()
        defer { finishRequest(id) }

        do {
            let fetchedCurrencies = try await repository.fetchCurrencies()
            try Task.checkCancellation()
            guard id == requestID else { return }

            currencies = fetchedCurrencies
            guard let first = currencies.first else {
                errorMessage = "Unable to load currencies."
                return
            }
            if !currencies.contains(selectedCurrency) {
                selectedCurrency = first
            }
            try await loadRate(for: selectedCurrency, requestID: id)
        } catch {
            handle(error, requestID: id)
        }
    }

    func selectCurrency(_ currency: String) async {
        guard !Task.isCancelled, currency != selectedCurrency, currencies.contains(currency) else { return }
        selectedCurrency = currency
        let id = beginRequest()
        defer { finishRequest(id) }

        do {
            try await loadRate(for: currency, requestID: id)
        } catch {
            handle(error, requestID: id)
        }
    }

    func updateUSDCAmount(_ value: String) {
        guard let input = normalizedInput(value) else { return }
        usdcAmount = input
        lastEditedField = .usdc
        recalculate()
    }

    func updateCurrencyAmount(_ value: String) {
        guard let input = normalizedInput(value) else { return }
        currencyAmount = input
        lastEditedField = .currency
        recalculate()
    }

    func swap() {
        isUSDCFirst.toggle()
        recalculate()
    }

    // Invalidate the whole operation, including the currencies request before the rate request.
    private func beginRequest() -> UUID {
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil
        exchangeRate = nil
        clearCalculatedAmount()
        return id
    }

    private func finishRequest(_ id: UUID) {
        if id == requestID {
            isLoading = false
        }
    }

    private func loadRate(for currency: String, requestID id: UUID) async throws {
        let rate = try await repository.fetchRate(for: currency)
        try Task.checkCancellation()
        guard id == requestID else { return }
        guard rate.currency == currency, !rate.bid.isNaN, !rate.ask.isNaN,
              rate.bid > 0, rate.ask >= rate.bid else {
            throw ExchangeRepositoryError.invalidRate
        }
        exchangeRate = rate
        recalculate()
    }

    private func handle(_ error: Error, requestID id: UUID) {
        guard id == requestID, !Task.isCancelled,
              !(error is CancellationError),
              (error as? URLError)?.code != .cancelled else { return }
        // Keep transport details in network logs, not in the interface.
        errorMessage = "Unable to load exchange rates. Check your connection and try again."
    }

    private func recalculate() {
        guard let rate = activeRate else {
            clearCalculatedAmount()
            return
        }
        switch lastEditedField {
        case .usdc:
            currencyAmount = decimal(usdcAmount).map { formatAmount($0 * rate) } ?? ""
        case .currency:
            usdcAmount = decimal(currencyAmount).map { formatAmount($0 / rate) } ?? ""
        }
    }

    private func clearCalculatedAmount() {
        switch lastEditedField {
        case .usdc: currencyAmount = ""
        case .currency: usdcAmount = ""
        }
    }

    // Amounts accept a dot or comma, up to 12 integer and 2 fractional digits.
    // Reject invalid edits rather than silently changing the numeric meaning of pasted text.
    private func normalizedInput(_ value: String) -> String? {
        var input = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard input.isEmpty || input.wholeMatch(of: /[0-9]*(\.[0-9]{0,2})?/) != nil else {
            return nil
        }
        if input.hasPrefix(".") { input = "0" + input }
        let integerPart = input.components(separatedBy: ".")[0]
        guard integerPart.count <= 12 else { return nil }
        return input
    }

    private func decimal(_ value: String) -> Decimal? {
        guard !value.isEmpty else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func formatAmount(_ value: Decimal) -> String {
        guard !value.isNaN else { return "" }
        return value.formatted(
            .number.locale(Locale(identifier: "en_US"))
                .grouping(.never).precision(.fractionLength(0...2))
        )
    }

    private func formatRate(_ value: Decimal) -> String {
        value.formatted(
            .number.locale(Locale(identifier: "en_US"))
                .grouping(.automatic).precision(.fractionLength(2...10))
        )
    }
}
