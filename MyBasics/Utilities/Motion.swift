import SwiftUI

/// Animaciones que respetan "Reducir movimiento" (Ajustes de iOS › Accesibilidad › Movimiento).
/// RootView mantiene `isReduced` sincronizado con el entorno.
enum Motion {
    static var isReduced = false

    static func animate<Result>(_ animation: Animation = .smooth, _ body: () throws -> Result) rethrows -> Result {
        if isReduced {
            return try withAnimation(.easeInOut(duration: 0.15), body)   // sin rebotes ni desplazamientos
        }
        return try withAnimation(animation, body)
    }
}
