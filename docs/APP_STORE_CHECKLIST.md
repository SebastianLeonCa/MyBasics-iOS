# Fase 5 · Checklist para el App Store

Leyenda: ✅ ya está en la app · ⬜ pendiente · 🧑 lo haces tú (cuenta, pago, web) · 🤖 lo puedo hacer yo en código.

Orden sugerido: **A → B → C → D → E → F**. Hasta el paso C todo es gratis; desde D necesitas el
Apple Developer Program (99 USD/año).

---

## A. Dejar el código listo en `main`

- ⬜ 🧑 Fusionar las ramas en `main`, en orden (cada una sale de la anterior):
  `feat/fase-0-base` → `feat/fase-1-ui-mock` → `feat/fase-1b-ajustes` → `feat/fase-2-supabase` →
  `feat/fase-3-pulido` → `feat/fase-4-auth` → `feat/fase-4b-diseno` → `feat/fase-4c-compartidos` →
  `fix/compartidos-edicion` → `feat/moneda-perfil` → `feat/moneda-fija-usd` → `feat/apple-opcional` →
  `fix/ocultar-google` → `feat/fase-5-app-store`.
  Como cada rama contiene a las anteriores, basta un PR de `feat/fase-5-app-store` a `main`.
- ✅ Tests unitarios pasando (⌘U) y SQL probado.
- ⬜ 🧑 Ejecutar la última versión de `supabase/schema.sql` en Supabase.
- ⬜ 🧑 **Rotar la secret key de Supabase** (estuvo en texto plano en un archivo del repo).

## B. Requisitos técnicos de Apple

| | Requisito | Estado |
| --- | --- | --- |
| ✅ | Ícono 1024×1024 (claro, oscuro y *tinted*) | `Assets.xcassets/AppIcon` |
| ✅ | Pantalla de inicio | `UILaunchScreen` en `Config/Info.plist` |
| ✅ | **Eliminar cuenta dentro de la app** (guía 5.1.1(v)) | Ajustes › Eliminar cuenta |
| ✅ | Sin credenciales en el código ni en Git | `Secrets.xcconfig` en `.gitignore` |
| ✅ | Solo HTTPS (Supabase) | — |
| ✅ | **Manifiesto de privacidad** `PrivacyInfo.xcprivacy` (obligatorio desde 2024). La app no rastrea, no usa APIs de "razón obligatoria" y declara los datos que recopila (ver C.2). | `Resources/PrivacyInfo.xcprivacy` |
| ✅ | **Cifrado:** agregar `ITSAppUsesNonExemptEncryption = NO` al Info.plist (solo usa el HTTPS del sistema). Evita la pregunta en cada subida. | `Config/Info.plist` |
| ✅ | **Solo iPhone y solo vertical** (`TARGETED_DEVICE_FAMILY = 1`, solo *Portrait*). Así no hacen falta capturas de iPad. | `project.pbxproj` |
| ⬜ 🧑 | **Bundle ID definitivo** (hoy `sleonca.MyBasics`). Se recomienda formato `com.tunombre.mybasics`; **no se puede cambiar** después de publicar. | por decidir |
| ⬜ 🧑 | Versión `1.0` (`MARKETING_VERSION`) y build `1` (`CURRENT_PROJECT_VERSION`). **Sube el build** en cada envío a TestFlight. | ✅ valores iniciales |
| ✅ | **Login de terceros (guía 4.8):** hoy el login es solo con email, así que no aplica. Si activas Google, Apple exige ofrecer también Sign in with Apple (o una opción equivalente en privacidad) → activa los dos juntos. | — |
| ⬜ 🤖 | Si activas Apple: **revocar el token de Apple** al eliminar la cuenta (Apple lo pide). Requiere una Supabase Edge Function con la llave `.p8`. | solo si activas Apple |

## C. Lo que se completa en App Store Connect

### C.1 Ficha de la app (en español e inglés)
- ⬜ 🧑 **Nombre** (30 caracteres): `MyBasics` (verifica que esté libre al crear la app).
- ⬜ 🧑 **Subtítulo** (30): p. ej. *"Tus gastos del día a día"* / *"Your everyday spending"*.
- ⬜ 🧑 **Descripción**, **palabras clave** (100 caracteres, separadas por coma) y **texto promocional**.
- ⬜ 🧑 **Categoría:** Finanzas. Secundaria opcional: Productividad.
- ⬜ 🧑 **Precio:** Gratis. **Disponibilidad:** países donde la publicas.
- ⬜ 🧑 **URL de soporte** (obligatoria) y **URL de política de privacidad** (obligatoria).
  Opción gratis: publicar `docs/PRIVACY_POLICY.md` con **GitHub Pages** o una página de Notion.
- ⬜ 🧑 **Clasificación por edad:** responder el cuestionario (todo "No" → 4+).
- ⬜ 🧑 **Copyright:** `2026 Tu Nombre`.

### C.2 Privacidad de la app ("etiquetas nutricionales")
Respuestas que corresponden a lo que hace la app hoy:

| Tipo de dato | ¿Se recopila? | Uso | ¿Vinculado al usuario? | ¿Rastreo? |
| --- | --- | --- | --- | --- |
| Información de contacto › **Email** | Sí | Funcionalidad de la app (cuenta) | Sí | No |
| Identificadores › **ID de usuario** | Sí | Funcionalidad de la app | Sí | No |
| Información financiera › **Otra información financiera** (gastos que escribe el usuario) | Sí | Funcionalidad de la app | Sí | No |
| Contenido del usuario › **Otro contenido** (nombres de personas en "Compartidos", descripciones) | Sí | Funcionalidad de la app | Sí | No |
| Ubicación, contactos, salud, navegación, diagnósticos, publicidad | **No** | — | — | — |

- La app **no rastrea** (no usa IDFA, analítica de terceros ni publicidad) → no necesita el aviso de *App Tracking Transparency*.
- Si en el futuro agregas Google/Apple: el email lo entrega el proveedor; las respuestas no cambian.

### C.3 Capturas de pantalla
- ⬜ 🧑 Mínimo **3**, máximo 10, para **iPhone 6.9"** (1320×2868 o 1290×2796 px). Con eso Apple
  reutiliza para tamaños menores. Si dejas iPad: también **iPad 13"**.
- ✅ Capturas en `screenshots/es` y `screenshots/en` (1320×2868, iPhone 18 Pro Max, datos de ejemplo sin marcas):
  Inicio, Nuevo gasto, Compartidos, Suscripciones y Login. Para regenerarlas: lanzar la app (Debug) con
  `-useMockData` y además `-screenshotTab shared|subscriptions`, `-screenshotAddExpense` o `-mockSignedOut`.

### C.4 Notas para el revisor de Apple
- ⬜ 🧑 **Cuenta de prueba obligatoria** (la app pide login): crea en Supabase un usuario
  `review@…` con *Auto Confirm User*, con algunos gastos cargados, y pon email y contraseña en
  *App Review Information*.
- ⬜ 🧑 Texto sugerido: *"MyBasics registra gastos personales. Inicie sesión con la cuenta de prueba.
  Para eliminar la cuenta: Ajustes › Eliminar cuenta."*

## D. Cuenta de desarrollador (99 USD/año)
- ⬜ 🧑 Inscribirte en <https://developer.apple.com/programs/enroll/> como **persona individual**
  (el nombre del vendedor será tu nombre legal). La aprobación puede tardar de horas a un par de días.
- ⬜ 🧑 Aceptar los acuerdos en **App Store Connect › Business** (para apps gratis basta el acuerdo
  gratuito; no necesitas cuenta bancaria ni datos fiscales).

## E. TestFlight
1. ⬜ 🧑 **App Store Connect › Apps › +** › *New App*: plataforma iOS, nombre, idioma principal Español,
   el **bundle ID** definitivo y un SKU (p. ej. `mybasics-001`).
2. ⬜ 🧑 En Xcode: *Team* = tu equipo pagado; destino **Any iOS Device (arm64)**.
3. ⬜ 🧑 **Product › Archive** → en el Organizer, **Distribute App › App Store Connect › Upload**.
4. ⬜ 🧑 En unos minutos aparece en **TestFlight**. Responde la pregunta de cifrado si no agregaste la clave del punto B.
5. ⬜ 🧑 **Testers internos** (hasta 100 personas de tu equipo en App Store Connect): instalan sin revisión
   con la app TestFlight. **Testers externos** (enlace público): la primera versión pasa por una revisión beta corta.
6. ⬜ 🧑 Prueba en el build de TestFlight: **Ajustes › Datos debe decir "Supabase"** (si dice "Ejemplo",
   el archivo `Secrets.xcconfig` no estaba completo al archivar). Registro, login, olvidé mi contraseña,
   crear/editar/eliminar gastos, compartidos, exportar CSV, cerrar sesión y eliminar cuenta.

## F. Antes de enviar a revisión
- ⬜ 🧑 **Supabase en producción:**
  - SMTP propio para los correos de confirmación y recuperación (el correo incluido solo envía a tu equipo).
  - Plantillas de correo en español (ver `docs/AUTH_SETUP.md`).
  - *Redirect URLs* `mybasics://auth-callback` y `mybasics://reset-password`.
  - El plan gratis **pausa el proyecto tras 7 días sin uso**: si eso pasa en plena revisión, Apple
    rechaza la app porque no carga. Considera el plan Pro o asegúrate de que tenga actividad.
- ⬜ 🧑 Revisar la ficha en ambos idiomas, capturas y URLs.
- ⬜ 🧑 **Enviar a revisión** (suele tardar 1–3 días). Elige publicación manual para decidir el día.

## Motivos de rechazo frecuentes (y cómo está MyBasics)
| Guía | Qué piden | MyBasics |
| --- | --- | --- |
| 2.1 Completitud | Que nada falle ni quede a medias | Probar el build de TestFlight completo (E.6) |
| 2.3 Metadatos | Capturas reales de la app, sin promesas falsas | Usar capturas del simulador |
| 4.8 Login | Si hay login de terceros, ofrecer Apple o equivalente | Hoy solo email ✅ |
| 5.1.1 Privacidad | Política de privacidad y borrar cuenta en la app | Borrar cuenta ✅ · política ⬜ |
| 5.1.1(v) | Eliminar cuenta sin tener que escribir a soporte | ✅ |
