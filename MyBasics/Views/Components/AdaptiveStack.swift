import SwiftUI

/// HStack que pasa a VStack con tamaños de texto de accesibilidad (Dynamic Type XL+),
/// para que montos y nombres no se corten.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing / 2))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout(content)
    }
}
