import SwiftUI

struct CurrencyPickerView: View {
    let currencies: [String]
    let selectedCurrency: String
    let onSelect: (String) -> Void
    let onHeightChange: (CGFloat) -> Void

    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                
                ForEach(currencies, id: \.self) { currency in
                    currencyRow(currency)
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .background(Color(.systemBackground))
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            onHeightChange(proxy.size.height)
                        }
                        .onChange(of: proxy.size.height) { _, newHeight in
                            onHeightChange(newHeight)
                        }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Choose currency")
                .font(.system(size: 26, weight: .medium))
                .frame(height: Constants.headerHeight)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary)
                    .frame(width: Constants.xmarkSize, height: Constants.xmarkSize)
            }
            .accessibilityLabel("Close currency picker")
        }
        .padding(.vertical, Constants.headerVerticalPadding)
        .padding(.top, Constants.headerTopPadding)
    }

    private func currencyRow(_ currency: String) -> some View {
        Button {
            onSelect(currency)
        } label: {
            HStack(spacing: Constants.rowSpacing) {
                CurrencyFlagView(
                    imageName: CurrencyPresentation.flagImageName(for: currency),
                    size: Constants.flagSize,
                    showsBorder: true
                )

                Text(currency)
                    .foregroundStyle(.primary)

                Spacer()

                if currency == selectedCurrency {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Constants.selectionControlSize, weight: .light))
                        .foregroundStyle(Color.brandGreen)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: Constants.selectionBorderWidth)
                        .frame(width: Constants.selectionControlSize, height: Constants.selectionControlSize)
                }
            }
            .frame(height: Constants.rowHeight)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Constants

private extension CurrencyPickerView {
    enum Constants {
        static let selectionControlSize: CGFloat = 28
        static let flagSize: CGFloat = 32
        static let rowHeight: CGFloat = 64
        static let horizontalPadding: CGFloat = 16
        static let headerVerticalPadding: CGFloat = 18
        static let headerTopPadding: CGFloat = 15
        static let xmarkSize: CGFloat = 32
        static let headerHeight: CGFloat = 50
        static let rowSpacing: CGFloat = 12
        static let selectionBorderWidth: CGFloat = 1.5
    }
}
