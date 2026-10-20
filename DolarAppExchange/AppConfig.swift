import Foundation

enum AppConfig {
    static var dolarAppBaseURL: URL {
        guard let url = URL(string: "https://api.dolarapp.dev") else {
            preconditionFailure("Invalid DolarApp base URL")
        }

        return url
    }
}
