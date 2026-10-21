import SwiftUI

struct ExchangeView: View {
    @State private var viewModel = ExchangeViewModel()
    @State private var isCurrencyPickerPresented = false
    @State private var currencyPickerHeight: CGFloat = 300
    @State private var requestedCurrency: String?
    @State private var reloadID = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topSection
                exchangeInfo
                bottomSection
                if let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(message)
                            .multilineTextAlignment(.center)
                        Button("Try again") { reloadID += 1 }
                    }
                    .padding()
                } else if !viewModel.isLoading && viewModel.exchangeRateText.isEmpty {
                    Button("Load exchange rates") { reloadID += 1 }
                        .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .task(id: reloadID) {
            if let requestedCurrency, requestedCurrency != viewModel.selectedCurrency {
                await viewModel.selectCurrency(requestedCurrency)
            } else {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $isCurrencyPickerPresented) {
            CurrencyPickerView(
                currencies: viewModel.currencies,
                selectedCurrency: viewModel.selectedCurrency
            ) { currency in
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
            HStack(spacing: 12) {
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
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Constants.swapButtonLeadingPadding)
        }
        .frame(height: Constants.exchangeInfoHeight)
    }
}

struct ExchangeCurrencyRow: View {
    let flagImageName: String
    let currency: String
    let subtitle: String
    let sign: String

    @Binding var amount: String
    @FocusState private var isAmountFocused: Bool

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
                CurrencyFlagView(
                    imageName: flagImageName,
                    size: Constants.flagSize,
                    showsBorder: false
                )

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
        HStack(spacing: Constants.amountSpacing) {
            Text("\(sign) $")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(amount.isEmpty ? .secondary : .primary)
                .fixedSize()

            // Measure the amount within the available width to keep the sign beside it.
            Text(amount.isEmpty ? "0" : amount)
                .font(.system(size: 32, weight: .medium))
                .lineLimit(1)
                .hidden()
                .overlay {
                    ScrollView(.horizontal, showsIndicators: false) {
                        // Full text sets the scrollable width; the outer text bounds the viewport.
                        Text(amount.isEmpty ? "0" : amount)
                            .font(.system(size: 32, weight: .medium))
                            .fixedSize(horizontal: true, vertical: false)
                            .hidden()
                            .overlay {
                                TextField("0", text: $amount)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 32, weight: .medium))
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .focused($isAmountFocused)
                                    .accessibilityLabel("\(currency) amount")
                                    .toolbar {
                                        if isAmountFocused {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Done") { isAmountFocused = false }
                                            }
                                        }
                                    }
                            }
                    }
                    .defaultScrollAnchor(.trailing)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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
    }
}
