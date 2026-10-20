import Foundation

enum CurrencyPresentation {
    static func flagImageName(for currency: String) -> String {
        switch currency {
        case "USDc":
            return "flag_us"

        case "MXN":
            return "flag_mx"

        case "ARS":
            return "flag_ar"

        case "COP":
            return "flag_co"

        case "BRL":
            return "flag_br"

        case "EUR", "EURc":
            return "flag_eu"

        default:
            return "flag_default"
        }
    }

    static func subtitle(for currency: String) -> String {
        switch currency {
        case "MXN":
            return "Mexican pesos"
        case "ARS":
            return "Argentine pesos"
        case "COP":
            return "Colombian pesos"
        case "BRL":
            return "Brazilian reais"
        case "EUR", "EURc":
            return "Euros"
        case "USDc":
            return "Digital dollars"
        default:
            return currency
        }
    }
}
