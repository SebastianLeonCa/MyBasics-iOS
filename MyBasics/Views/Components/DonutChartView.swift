import Accessibility
import Charts
import SwiftUI

/// Gráfico donut por categoría. Tocar un sector lo resalta; tocar el centro (o el mismo sector) lo quita.
struct DonutChartView: View {
    let totals: [CategoryTotal]
    let totalCents: Int
    @Environment(\.currency) private var currency
    let selectedCategoryId: UUID?
    let onSelect: (UUID?) -> Void

    private let innerRatio: CGFloat = 0.6

    private var selected: CategoryTotal? {
        totals.first { $0.categoryId == selectedCategoryId }
    }

    var body: some View {
        Chart(totals) { item in
            SectorMark(
                angle: .value("Monto", item.amountCents),
                innerRadius: .ratio(innerRatio),
                outerRadius: .ratio(item.categoryId == selectedCategoryId ? 1 : 0.94),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(Color(hex: item.colorHex) ?? .gray)
            .opacity(selectedCategoryId == nil || item.categoryId == selectedCategoryId ? 1 : 0.35)
            .accessibilityLabel(item.name)
            .accessibilityValue(
                "\(CurrencyFormatter.string(fromCents: item.amountCents, currency: currency)), \(percent(item.share))")
        }
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let frame = geo[plotFrame]
                    centerLabel
                        .frame(width: frame.width * innerRatio * 0.72)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        onSelect(categoryId(at: location, in: geo[plotFrame]))
                    }
            }
        }
        .frame(height: 240)
        .accessibilityChartDescriptor(self)
        .accessibilityLabel("Gráfico de gastos por categoría")
    }

    @ViewBuilder
    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(selected?.name ?? String(localized: "Total"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            // El primer tamaño que quepa en el hueco del donut.
            ViewThatFits(in: .horizontal) {
                ForEach([Font.title2, .headline, .subheadline, .footnote], id: \.self) { font in
                    Text(CurrencyFormatter.string(fromCents: selected?.amountCents ?? totalCents, currency: currency))
                        .font(font.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .fixedSize()
                }
            }
            if let selected {
                Text(percent(selected.share))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: selected.colorHex) ?? .secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .multilineTextAlignment(.center)
        // El hueco del donut tiene un tamaño fijo: el texto crece hasta un tope (VoiceOver lee el valor completo).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }

    /// Convierte el punto tocado en la categoría del sector (los sectores parten a las 12 y van en sentido horario).
    private func categoryId(at location: CGPoint, in frame: CGRect) -> UUID? {
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let radius = min(frame.width, frame.height) / 2
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= radius * innerRatio, distance <= radius else { return nil }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let target = Double(angle / (2 * .pi)) * Double(totalCents)

        var cumulative = 0
        for item in totals {
            cumulative += item.amountCents
            if target <= Double(cumulative) { return item.categoryId }
        }
        return totals.last?.categoryId
    }

    private func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// Descripción del gráfico para VoiceOver (incluye "Gráficos de audio").
/// Se describe con porcentajes, no con montos: el dinero nunca pasa a Double.
extension DonutChartView: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let categories = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Categoría"),
            categoryOrder: totals.map(\.name))
        let percentages = AXNumericDataAxisDescriptor(
            title: String(localized: "Porcentaje del total"),
            range: 0...100,
            gridlinePositions: []) { value in "\(Int(value.rounded())) %" }
        let series = AXDataSeriesDescriptor(
            name: String(localized: "Gastos"),
            isContinuous: false,
            dataPoints: totals.map { item in
                AXDataPoint(
                    x: item.name,
                    y: item.share * 100,
                    label: CurrencyFormatter.string(fromCents: item.amountCents, currency: currency))
            })
        return AXChartDescriptor(
            title: String(localized: "Gastos por categoría"),
            summary: String(localized: "Total \(CurrencyFormatter.string(fromCents: totalCents, currency: currency))"),
            xAxis: categories,
            yAxis: percentages,
            additionalAxes: [],
            series: [series])
    }
}
