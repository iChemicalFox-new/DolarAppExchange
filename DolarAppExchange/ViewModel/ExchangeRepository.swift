import Foundation

protocol ExchangeRepositoryProtocol {
    func fetchCurrencies() async -> [String]
    func fetchRate(for currency: String) async throws -> ExchangeRate
}

final class ExchangeRepository: ExchangeRepositoryProtocol {
    private let apiManager: APIManagingProtocol

    private let fallbackCurrencies = ["MXN", "ARS", "BRL", "COP", "EURc"]

    init(apiManager: APIManagingProtocol = APIManager()) {
        self.apiManager = apiManager
    }

    func fetchCurrencies() async -> [String] {
        do {
            return try await apiManager.fetchCurrencies()
        } catch {
            return fallbackCurrencies
        }
    }

    func fetchRate(for currency: String) async throws -> ExchangeRate {
        let tickers = try await apiManager.fetchTickers(currencies: [currency])

        guard let ticker = tickers.first else {
            throw ExchangeRepositoryError.tickerNotFound
        }

        let locale = Locale(identifier: "en_US_POSIX")

        guard
            let ask = Decimal(string: ticker.ask, locale: locale),
            let bid = Decimal(string: ticker.bid, locale: locale)
        else {
            throw ExchangeRepositoryError.invalidRate
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS"

        guard let date = dateFormatter.date(from: ticker.date) else {
            throw ExchangeRepositoryError.invalidDate
        }

        return ExchangeRate(currency: currency, ask: ask, bid: bid, date: date)
    }
}

enum ExchangeRepositoryError: LocalizedError {
    case tickerNotFound
    case invalidRate
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .tickerNotFound:
            return "Exchange rate is unavailable."

        case .invalidRate:
            return "Invalid exchange rate received from server."
            
        case .invalidDate:
            return "Invalid exchange rate date received from server."
        }
    }
}

struct ExchangeRate {
    let currency: String
    let ask: Decimal
    let bid: Decimal
    let date: Date
}
