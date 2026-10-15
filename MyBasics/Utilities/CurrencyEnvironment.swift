import SwiftUI

extension EnvironmentValues {
    /// Moneda con la que se muestran TODOS los montos (AppEnvironment.currency, fija en USD).
    /// La inyecta RootView para que haya un único lugar que la define.
    @Entry var currency: String = CurrencyFormatter.defaultCurrency
}
