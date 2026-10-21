import SwiftUI
import UIKit

struct ExchangeView: View {
    @State private var viewModel = ExchangeViewModel()
    @State private var isCurrencyPickerPresented = false
    @State private var currencyPickerHeight: CGFloat = 300
    @State private var requestedCurrency: String?
    @State private var reloadID = 0
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            topSection
            exchangeInfo
            bottomSection
            
            if let message = viewModel.errorMessage {
                networkError(message)
            } else if viewModel.isRateStale {
                rateWarning
            } else if !viewModel.isLoading && viewModel.exchangeRateText.isEmpty {
                Button("Load exchange rates") {
                    reloadID += 1
                }
                .font(.footnote)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground), ignoresSafeAreaEdges: .bottom)
        .background(Color(.systemGray6), ignoresSafeAreaEdges: .top)

        .task(id: reloadID) {
            if let requestedCurrency,
               requestedCurrency != viewModel.selectedCurrency {
                await viewModel.selectCurrency(requestedCurrency)
            } else if viewModel.rateExpiresAt != nil {
                await viewModel.refreshRate()
            } else {
                await viewModel.load()
            }
        }
        .task(id: viewModel.rateExpiresAt) {
            viewModel.updateRateFreshness()

            guard let expiresAt = viewModel.rateExpiresAt else { return }

            let remainingTime = expiresAt.timeIntervalSinceNow

            guard remainingTime > 0 else { return }

            do {
                try await Task.sleep(for: .seconds(remainingTime))
                try Task.checkCancellation()
            } catch {
                return
            }

            viewModel.updateRateFreshness()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.updateRateFreshness()
            }
        }
        .sheet(isPresented: $isCurrencyPickerPresented) {
            CurrencyPickerView(currencies: viewModel.currencies, selectedCurrency: viewModel.selectedCurrency) { currency in
                isCurrencyPickerPresented = false
                if currency != viewModel.selectedCurrency {
                    requestedCurrency = currency
                    reloadID += 1
                }
            } onHeightChange: { height in
                currencyPickerHeight = height
            }
            .presentationDetents([
                .height(min(currencyPickerHeight, 500)), .large
            ])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Constants.pickerCornerRadius)
            .presentationBackground(Color(.systemBackground))
        }
    }
    
    private var topSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Exchange calculator")
                .font(.system(size: 32, weight: .medium))
                .tracking(-1.28)

            Spacer()
                .frame(height: Constants.titleToRowSpacing)

            Group {
                if viewModel.isUSDCFirst {
                    usdcRow(sign: "-")
                } else {
                    currencyRow(sign: "-")
                }
            }
            .offset(y: Constants.currencyRowVerticalOffset)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.titleTopPadding)
        .padding(.bottom, Constants.sectionVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
    }
    
    private var bottomSection: some View {
        Group {
            if viewModel.isUSDCFirst {
                currencyRow(sign: "+")
            } else {
                usdcRow(sign: "+")
            }
        }
        .offset(y: -Constants.currencyRowVerticalOffset)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.sectionVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func usdcRow(sign: String) -> some View {
        let currency = "USDc"
        
        return ExchangeCurrencyRow(
            flagImageName: "flag_us",
            currency: currency,
            subtitle: "Digital dollars",
            sign: sign,
            amount: Binding(
                get: {
                    viewModel.usdcAmount
                },
                set: {
                    viewModel.updateUSDCAmount($0)
                }
            )
        )
    }

    private func currencyRow(sign: String) -> some View {
        ExchangeCurrencyRow(
            flagImageName: CurrencyPresentation.flagImageName(for: viewModel.selectedCurrency),
            currency: viewModel.selectedCurrency,
            subtitle: CurrencyPresentation.subtitle(for: viewModel.selectedCurrency),
            sign: sign,
            amount: Binding(
                get: {
                    viewModel.currencyAmount
                },
                set: {
                    viewModel.updateCurrencyAmount($0)
                }
            ),
            showsCurrencySelector: true
        ) {
            guard !viewModel.currencies.isEmpty else { return }
            isCurrencyPickerPresented = true
        }
    }

    private var exchangeInfo: some View {
        ZStack {
            VStack(spacing: 0) {
                Color(.systemGray6)
                Color(.systemBackground)
            }

            Divider()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading rates")
                } else {
                    Text(viewModel.exchangeRateText.isEmpty ? "Rate unavailable" : viewModel.exchangeRateText)
                }
            }
            .font(.system(size: 16))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(Color.brandGreen)
            .padding(.horizontal, Constants.rateHorizontalPadding)
            .padding(.vertical, Constants.rateVerticalPadding)
            .background(Capsule().fill(Color(.systemBackground)))
            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))

            HStack {
                Button {
                    viewModel.swap()
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: Constants.swapButtonSize, height: Constants.swapButtonSize)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap currencies")

                Spacer()
            }
            .padding(.horizontal, Constants.swapButtonLeadingPadding)
        }
        .frame(height: Constants.exchangeInfoHeight)
    }
    
    private var rateWarning: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Rate may be outdated")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Refresh") {
                reloadID += 1
            }
            .disabled(viewModel.isLoading)
        }
        .font(.footnote)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, 4)
    }
    
    private func networkError(_ message: String) -> some View {
        VStack(spacing: 6) {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Try again") {
                reloadID += 1
            }
            .disabled(viewModel.isLoading)
        }
        .font(.footnote)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, 4)
    }
}

struct ExchangeCurrencyRow: View {
    let flagImageName: String
    let currency: String
    let subtitle: String
    let sign: String

    @Binding var amount: String
    @State private var isAmountFocused = false

    var showsCurrencySelector = false
    var onCurrencyTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Constants.spacing) {
            currencyInfo
                .layoutPriority(1)

            Spacer(minLength: 8)

            amountField
        }
        .frame(minHeight: Constants.rowHeight)
    }
    
    private var currencyInfo: some View {
        VStack(alignment: .leading, spacing: Constants.currencyInfoSpacing) {
            currencyTitle

            HStack(spacing: 4) {
                CurrencyFlagView(imageName: flagImageName, size: Constants.flagSize, showsBorder: false)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Constants.subtitleTopPadding)
        }
    }

    @ViewBuilder
    private var currencyTitle: some View {
        if showsCurrencySelector {
            Button {
                onCurrencyTap?()
            } label: {
                currencyTitleContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose currency")
        } else {
            currencyTitleContent
        }
    }

    private var currencyTitleContent: some View {
        HStack(spacing: 4) {
            Text(currency)
                .font(.system(size: 32, weight: .medium))
                .tracking(-1.28)

            if showsCurrencySelector {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(.primary)
    }
    
    private var amountField: some View {
        GeometryReader { geometry in
            let prefix = "\(sign) $"
            let prefixWidth = textWidth(prefix, fontSize: Constants.amountMaximumFontSize)
            let availableWidth = max(1, geometry.size.width - prefixWidth - Constants.amountSpacing)
            let presentation = amountPresentation(availableWidth: availableWidth)

            HStack(alignment: .firstTextBaseline, spacing: Constants.amountSpacing) {
                Text(prefix)
                    .font(.system(size: presentation.fontSize, weight: .medium))
                    .foregroundStyle(amount.isEmpty ? Color.secondary : Color.primary)
                    .fixedSize()

                AmountTextField(
                    text: $amount,
                    isFocused: $isAmountFocused,
                    fontSize: presentation.fontSize,
                    currency: currency
                )
                .frame(width: presentation.width, height: Constants.amountFieldHeight)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    let font = UIFont.systemFont(ofSize: presentation.fontSize, weight: .medium)

                    return (dimensions.height - font.lineHeight) / 2 + font.ascender
                }
                .overlay(alignment: .trailing) {
                    if !isAmountFocused {
                        Text(presentation.text)
                            .font(.system(size: presentation.fontSize, weight: .medium))
                            .foregroundStyle(amount.isEmpty ? Color.secondary : Color.primary)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topTrailing)
            .contentShape(Rectangle())
            .onTapGesture {
                isAmountFocused = true
            }
        }
        .frame(height: Constants.amountFieldHeight)
        .frame(maxWidth: .infinity)
    }

    private func amountPresentation(availableWidth: CGFloat) -> (text: String, fontSize: CGFloat, width: CGFloat) {
        let fullText = amount.isEmpty ? "0" : amount
        let textPadding: CGFloat = 2
        let usableWidth = max(1, availableWidth - textPadding)

        let maximumTextWidth = textWidth(fullText, fontSize: Constants.amountMaximumFontSize)

        let fittedFontSize = min(
            Constants.amountMaximumFontSize,
            max(Constants.amountMinimumFontSize, Constants.amountMaximumFontSize * usableWidth / max(maximumTextWidth, 1))
        )

        let needsScientificNotation =
            !isAmountFocused
            && textWidth(fullText, fontSize: Constants.amountMinimumFontSize) > usableWidth

        let displayedText = needsScientificNotation ? scientificAmount(fullText) : fullText
        let fontSize = needsScientificNotation ? Constants.amountMinimumFontSize : fittedFontSize
        let width = min(availableWidth, textWidth(displayedText, fontSize: fontSize) + textPadding)

        return (text: displayedText, fontSize: fontSize, width: width)
    }

    private func textWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)

        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func scientificAmount(_ text: String) -> String {
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            return text
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .scientific
        formatter.exponentSymbol = "e"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? text
    }
}

private struct AmountTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let fontSize: CGFloat
    let currency: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad

        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )

        context.coordinator.textField = textField

        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.done))
        ]
        toolbar.sizeToFit()
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        let textChanged = uiView.text != text

        if textChanged {
            uiView.text = text
        }

        // Font of active field updating here
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let color: UIColor = isFocused ? .label : .clear

        if uiView.font != font {
            uiView.font = font
        }
        uiView.textColor = color

        if uiView.isEditing {
            var attributes = uiView.typingAttributes ?? [:]
            attributes[.font] = font
            attributes[.foregroundColor] = color
            uiView.typingAttributes = attributes
        }

        uiView.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .font: font,
                .foregroundColor: isFocused ? UIColor.secondaryLabel : UIColor.clear
            ]
        )

        uiView.accessibilityLabel = "\(currency) amount"

        if isFocused != uiView.isFirstResponder {
            let coordinator = context.coordinator

            DispatchQueue.main.async { [weak uiView] in
                guard let uiView else { return }

                if coordinator.parent.isFocused {
                    uiView.becomeFirstResponder()
                } else {
                    uiView.resignFirstResponder()
                }
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountTextField
        weak var textField: UITextField?

        init(parent: AmountTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""

            // We apply normalization, or else we discard the model immediately
            if textField.text != parent.text {
                textField.text = parent.text
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        @objc func done() {
            textField?.resignFirstResponder()
        }
    }
}

// MARK: - Constants

private extension ExchangeView {
    enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let titleTopPadding: CGFloat = 64
        static let titleToRowSpacing: CGFloat = 28
        static let sectionVerticalPadding: CGFloat = 60
        static let currencyRowVerticalOffset: CGFloat = 30
        
        static let pickerCornerRadius: CGFloat = 28

        static let exchangeInfoHeight: CGFloat = 44
        static let swapButtonSize: CGFloat = 40
        static let swapButtonLeadingPadding: CGFloat = 8

        static let rateHorizontalPadding: CGFloat = 16
        static let rateVerticalPadding: CGFloat = 8
    }
}

private extension ExchangeCurrencyRow {
    enum Constants {
        static let rowHeight: CGFloat = 74
        static let spacing: CGFloat = 12
        static let currencyInfoSpacing: CGFloat = 5
        static let subtitleTopPadding: CGFloat = 10
        static let flagSize: CGFloat = 14
        static let amountSpacing: CGFloat = 2
        
        static let amountMaximumFontSize: CGFloat = 32
        static let amountMinimumFontSize: CGFloat = 16
        static let amountFieldHeight: CGFloat = 44
    }
}
