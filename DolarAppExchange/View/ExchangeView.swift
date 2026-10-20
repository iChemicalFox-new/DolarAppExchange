import SwiftUI

struct ExchangeView: View {
    @State private var viewModel = ExchangeViewModel()
    @State private var isCurrencyPickerPresented = false
    @State private var currencyPickerHeight: CGFloat = 300
    
    var body: some View {
        VStack(spacing: 0) {
            topSection
            exchangeInfo
            bottomSection
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isCurrencyPickerPresented) {
            CurrencyPickerView(
                currencies: viewModel.currencies,
                selectedCurrency: viewModel.selectedCurrency
            ) { currency in
                Task {
                    await viewModel.selectCurrency(currency)
                    isCurrencyPickerPresented = false
                }
            } onHeightChange: { height in
                currencyPickerHeight = height
            }
            .presentationDetents([
                .height(currencyPickerHeight)
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
        .background(Color.white)
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
            isCurrencyPickerPresented = true
        }
    }

    private var exchangeInfo: some View {
        ZStack {
            VStack(spacing: 0) {
                Color(.systemGray6)
                Color.white
            }

            Divider()

            Text(viewModel.exchangeRateText)
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brandGreen)
                .padding(.horizontal, Constants.rateHorizontalPadding)
                .padding(.vertical, Constants.rateVerticalPadding)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            HStack {
                Button {
                    viewModel.swap()
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: Constants.swapButtonSize, height: Constants.swapButtonSize)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.leading, Constants.swapButtonLeadingPadding)
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

    var showsCurrencySelector = false
    var onCurrencyTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Constants.spacing) {
            currencyInfo

            Spacer()

            amountField
        }
        .frame(height: Constants.rowHeight)
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

            TextField("0", text: $amount)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 32, weight: .medium))
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Constrants

private extension ExchangeView {
    enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let titleTopPadding: CGFloat = 117
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
