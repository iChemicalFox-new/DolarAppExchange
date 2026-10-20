import Foundation

protocol APIManagingProtocol {
    func fetchTickers(currencies: [String]) async throws -> [TickerDTO]
    func fetchCurrencies() async throws -> [String]
}

final class APIManager: APIManagingProtocol {
    private let networking: Networking
    private let requestBuilder: DolarAppRequestBuilder
    private let decoder: JSONDecoder

    init(
        networking: Networking = NetworkManager(),
        requestBuilder: DolarAppRequestBuilder = DolarAppRequestBuilder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.networking = networking
        self.requestBuilder = requestBuilder
        self.decoder = decoder
    }

    func fetchTickers(currencies: [String]) async throws -> [TickerDTO] {
        let request = try requestBuilder.makeRequest(
            endpoint: .tickers(currencies: currencies)
        )

        let data = try await networking.send(request)

        do {
            return try decoder.decode([TickerDTO].self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    func fetchCurrencies() async throws -> [String] {
        let request = try requestBuilder.makeRequest(
            endpoint: .currencies
        )

        let data = try await networking.send(request)

        do {
            return try decoder.decode([String].self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}
