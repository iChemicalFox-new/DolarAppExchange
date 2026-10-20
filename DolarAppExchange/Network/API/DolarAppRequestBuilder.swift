import Foundation

struct DolarAppRequestBuilder {
    private let baseURL: URL

    init(baseURL: URL = AppConfig.dolarAppBaseURL) {
        self.baseURL = baseURL
    }

    func makeRequest(endpoint: DolarAppEndpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)

        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return request
    }
}

enum DolarAppEndpoint {
    case tickers(currencies: [String])
    case currencies

    var path: String {
        switch self {
        case .tickers:
            return "v1/tickers"

        case .currencies:
            return "v1/tickers-currencies"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .tickers(let currencies):
            return [
                URLQueryItem(
                    name: "currencies",
                    value: currencies.joined(separator: ",")
                )
            ]

        case .currencies:
            return []
        }
    }
}


