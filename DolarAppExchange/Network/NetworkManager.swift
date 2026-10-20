import Foundation

protocol Networking {
    func send(_ request: URLRequest) async throws -> Data
}

final class NetworkManager: Networking {
    private let session: URLSession
    private let logger: NetworkLogger

    init(
        session: URLSession = .shared,
        logger: NetworkLogger = ConsoleNetworkLogger()
    ) {
        self.session = session
        self.logger = logger
    }

    func send(_ request: URLRequest) async throws -> Data {
        logger.logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            logger.logResponse(response, data: data)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                throw NetworkError.httpStatus(httpResponse.statusCode, data)
            }

            return data
        } catch {
            logger.logError(error)
            throw error
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, Data)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to build a valid URL."

        case .invalidResponse:
            return "Invalid response from server."

        case .httpStatus(let code, let data):
            let body = String(data: data, encoding: .utf8) ?? "No body"
            return "HTTP error \(code). Body: \(body)"
            
        case .decoding(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
