import Foundation

protocol ExchangeRepositoryProtocol {
    func fetchCurrencies() async throws -> [String]
    func fetchRate(for currency: String) async throws -> ExchangeRate
}

final class ExchangeRepository: ExchangeRepositoryProtocol {
    private let apiManager: APIManagingProtocol
    private let fallbackCurrencies = ["MXN", "ARS", "BRL", "COP"]

    init(apiManager: APIManagingProtocol = APIManager()) {
        self.apiManager = apiManager
    }

    func fetchCurrencies() async throws -> [String] {
        do {
            let response = try await apiManager.fetchCurrencies()
            try Task.checkCancellation()
            var seen = Set<String>()
            let currencies = response.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != "usdc" && seen.insert($0).inserted }
            return currencies.isEmpty ? fallbackCurrencies : currencies
        } catch {
            // An unavailable currencies endpoint is expected; cancellation is not a failure.
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw error
            }
            return fallbackCurrencies
        }
    }

    func fetchRate(for currency: String) async throws -> ExchangeRate {
        let tickers = try await apiManager.fetchTickers(currencies: [currency])
        try Task.checkCancellation()
        guard let ticker = tickers.first(where: { $0.book.lowercased() == "usdc_\(currency.lowercased())" }) else {
            throw ExchangeRepositoryError.tickerNotFound
        }

        let locale = Locale(identifier: "en_US_POSIX")
        guard ticker.ask.wholeMatch(of: /[0-9]+(\.[0-9]+)?/) != nil,
              ticker.bid.wholeMatch(of: /[0-9]+(\.[0-9]+)?/) != nil,
              let ask = Decimal(string: ticker.ask, locale: locale),
              let bid = Decimal(string: ticker.bid, locale: locale),
              !ask.isNaN, !bid.isNaN, bid > 0, ask >= bid else {
            throw ExchangeRepositoryError.invalidRate
        }

        guard let date = parseDate(ticker.date) else {
            throw ExchangeRepositoryError.invalidDate
        }
        return ExchangeRate(currency: currency, ask: ask, bid: bid, date: date)
    }

    private func parseDate(_ value: String) -> Date? {
        // The documented response omits a timezone; interpret it as UTC.
        let formatter = ISO8601DateFormatter()
        let formats: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ]
        for options in formats {
            formatter.formatOptions = options
            if let date = formatter.date(from: value) ?? formatter.date(from: value + "Z") {
                return date
            }
        }
        return nil
    }
}

enum ExchangeRepositoryError: LocalizedError {
    case tickerNotFound
    case invalidRate
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .tickerNotFound: return "Exchange rate is unavailable."
        case .invalidRate: return "Invalid exchange rate received from server."
        case .invalidDate: return "Invalid exchange rate date received from server."
        }
    }
}

struct ExchangeRate {
    let currency: String
    let ask: Decimal
    let bid: Decimal
    let date: Date
}
