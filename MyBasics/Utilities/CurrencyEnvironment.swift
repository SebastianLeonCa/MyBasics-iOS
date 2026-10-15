import SwiftUI

extension EnvironmentValues {
    /// Moneda con la que se muestran TODOS los montos. Viene del perfil (AppEnvironment.currency)
    /// y la inyecta RootView: al cambiarla, toda la interfaz se vuelve a dibujar al instante.
    @Entry var currency: String = CurrencyFormatter.defaultCurrency
}
