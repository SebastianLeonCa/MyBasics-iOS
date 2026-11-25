# Instalar MyBasics en tu iPhone (gratis, con tu Apple ID)

No hace falta el Apple Developer Program para usar la app en **tu propio iPhone**.
Los datos se guardan en tu Supabase, así que no se pierden al reinstalar.

## Una sola vez

1. **Xcode › Settings › Accounts › +** › *Apple ID* e inicia sesión con tu Apple ID normal.
2. Abre `MyBasics.xcodeproj` › target **MyBasics** › **Signing & Capabilities**:
   - *Automatically manage signing*: activado.
   - *Team*: el que dice **(Personal Team)** con tu nombre.
   - Si aparece *"Failed to register bundle identifier"*, cambia el *Bundle Identifier* por algo único,
     p. ej. `com.tunombre.mybasics`. (Si luego activas Google, usa ese mismo bundle ID en Google Cloud.)
3. Verifica que en `Config/Secrets.xcconfig` esté `APPLE_SIGN_IN = NO`.
4. Conecta el iPhone al Mac con el cable y toca **Confiar** en el iPhone.
5. En el iPhone: **Ajustes › Privacidad y seguridad › Modo de desarrollador** › activar › reiniciar.
   (La opción aparece después de conectar el iPhone a Xcode.)

## Instalar

1. En Xcode, arriba, elige tu **iPhone** como destino (en vez del simulador) y pulsa **Run** (⌘R).
2. La primera vez, el iPhone dirá que el desarrollador no es de confianza:
   **Ajustes › General › VPN y gestión de dispositivos** › tu Apple ID › **Confiar**. Vuelve a pulsar ⌘R.
3. Listo: la app queda en tu pantalla de inicio y funciona sin el cable.

## Bueno saber

- **Caduca cada 7 días** con un Apple ID gratuito: la app deja de abrir. Conecta el iPhone y pulsa ⌘R
  otra vez; tus datos siguen ahí (están en Supabase) y normalmente sigues con la sesión iniciada.
- Máximo **3 apps** instaladas así a la vez por Apple ID.
- Para no usar el cable: con el iPhone conectado una vez, **Window › Devices and Simulators** ›
  tu iPhone › *Connect via network*. Luego basta con estar en la misma red Wi-Fi.
- Inicia sesión con **email y contraseña** (o Google, cuando lo configures).
