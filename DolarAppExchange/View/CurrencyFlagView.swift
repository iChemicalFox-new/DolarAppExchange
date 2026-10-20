import SwiftUI

struct CurrencyFlagView: View {
    let imageName: String
    let size: CGFloat
    let showsBorder: Bool

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color(.systemGray6), lineWidth: showsBorder ? 6 : 0)
            }
    }
}
