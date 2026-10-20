import Foundation
import OSLog

protocol NetworkLogger {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: URLResponse, data: Data)
    func logError(_ error: Error)
}

final class ConsoleNetworkLogger: NetworkLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DolarAppExchange",
        category: "Network"
    )

    func logRequest(_ request: URLRequest) {
        #if DEBUG
        logger.debug(
            "*** REQUEST: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")"
        )

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("*** Headers: \(String(describing: headers))")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("*** Body: \(bodyString)")
        }
        #endif
    }

    func logResponse(_ response: URLResponse, data: Data) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            logger.debug("*** RESPONSE: \(httpResponse.statusCode)")
        } else {
            logger.debug("*** RESPONSE: non-HTTP response")
        }

        if let bodyString = String(data: data, encoding: .utf8) {
            logger.debug("*** Body: \(bodyString)")
        }
        #endif
    }

    func logError(_ error: Error) {
        #if DEBUG
        logger.error("*** ERROR: \(error.localizedDescription)")
        #endif
    }
}
