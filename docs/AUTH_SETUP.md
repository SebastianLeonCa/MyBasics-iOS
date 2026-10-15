# Autenticación real (Fase 4): Apple, Google y email

Haz las partes en este orden. Cada una se puede probar por separado: la app muestra solo los
botones que estén configurados (Google aparece solo si `GOOGLE_IOS_CLIENT_ID` tiene valor).

> **Antes de empezar:** vuelve a ejecutar [`supabase/schema.sql`](../supabase/schema.sql) en el
> SQL Editor (agrega `delete_my_account()` para "Eliminar cuenta"). Es seguro: no borra datos.
>
> El usuario de prueba de la Fase 2 sigue sirviendo: entra con él desde el formulario de email.
> Las líneas `DEV_USER_*` de `Config/Secrets.xcconfig` ya no se usan; puedes borrarlas.

---

## 1. Email + contraseña (Supabase)

1. **Authentication › Sign In / Providers › Email**
   - *Enable Email provider*: activado.
   - *Confirm email*: activado (recomendado; quien se registra debe tocar un enlace).
   - *Minimum password length*: `8` (igual que la app).
2. **Authentication › URL Configuration**
   - *Site URL*: `mybasics://auth-callback`
   - *Redirect URLs* → **Add URL**, agrega estas dos:
     - `mybasics://auth-callback` (confirmación de registro)
     - `mybasics://reset-password` (olvidé mi contraseña)
3. **Authentication › Emails › Templates** (opcional, para que lleguen en español). Ejemplo para *Confirm signup*:
   - Subject: `Confirma tu cuenta de MyBasics`
   - Body:
     ```html
     <h2>¡Hola!</h2>
     <p>Toca el botón para activar tu cuenta de MyBasics:</p>
     <p><a href="{{ .ConfirmationURL }}">Confirmar mi correo</a></p>
     <p>Si no creaste esta cuenta, ignora este mensaje.</p>
     ```
   - Para *Reset password*: Subject `Crea una contraseña nueva`, mismo cuerpo con el texto
     "Toca el botón para crear una contraseña nueva" y **sin cambiar** `{{ .ConfirmationURL }}`.

> ⚠️ **Correo de prueba de Supabase:** el servidor de correo incluido solo envía a los emails de
> los miembros de tu equipo en Supabase y con un límite bajo por hora. Para probar con cualquier
> correo configura un SMTP propio (**Project Settings › Authentication › SMTP Settings**; Resend o
> Brevo tienen plan gratis), o desactiva *Confirm email* mientras pruebas.
>
> Los enlaces se abren en el **mismo iPhone** donde pediste el correo (la app guarda un código
> de seguridad PKCE). Desde el simulador: abre el correo en el Mac, copia el enlace y ejecuta
> `xcrun simctl openurl booted "<enlace>"`.

**Probar:** en la app, *Crear cuenta* → te llega el correo → tócalo → la app se abre con
"Correo confirmado". *¿Olvidaste tu contraseña?* → correo → la app pide la nueva contraseña.

---

## 2. Sign in with Apple

Requiere el **Apple Developer Program** (99 USD/año) en <https://developer.apple.com/programs/>.
Sin la membresía, Xcode no puede firmar la app con esta capacidad.

1. **Xcode** › proyecto › target **MyBasics** › **Signing & Capabilities**
   - *Team*: tu equipo pagado. *Automatically manage signing*: activado.
   - Debe aparecer la capacidad **Sign in with Apple** (ya viene en `Config/MyBasics.entitlements`).
     Si Xcode muestra un error, pulsa *Try Again* para que registre el App ID.
2. **developer.apple.com › Certificates, Identifiers & Profiles › Identifiers**
   - Abre el App ID `sleonca.MyBasics` y verifica que **Sign In with Apple** está marcado
     (*Enable as a primary App ID*). Si no existe, Xcode lo crea en el paso 1.
3. **Supabase › Authentication › Sign In / Providers › Apple**
   - *Enable Sign in with Apple*: activado.
   - *Client IDs*: `sleonca.MyBasics` (el bundle ID; es lo que valida el login nativo de iOS).
   - *Secret Key (for OAuth)*: déjalo vacío. Solo hace falta para el login **web**.
   - Guarda.
4. **Probar:** en un iPhone real (o simulador con sesión de Apple ID en Ajustes) toca
   *Continuar con Apple*. La primera vez Apple pregunta si compartir o esconder tu email.

<details>
<summary>Opcional: Services ID y llave (.p8) — solo para login web o revocar tokens</summary>

La app de iOS no los necesita. Sirven si más adelante agregas una web, o para revocar el token de
Apple al eliminar la cuenta desde un servidor (ver "Pendientes" abajo).

1. **Identifiers › +** › *Services IDs* › identificador `sleonca.MyBasics.web` › marca *Sign In with Apple*
   › *Configure*: Primary App ID `sleonca.MyBasics`; Domain `TU-PROYECTO.supabase.co`;
   Return URL `https://TU-PROYECTO.supabase.co/auth/v1/callback`.
2. **Keys › +** › nombre `MyBasics Sign in with Apple` › marca *Sign in with Apple* › *Configure* con el
   App ID › descarga el `.p8` (**solo se puede descargar una vez**; guárdalo en tu gestor de contraseñas,
   nunca en el repo). Anota el *Key ID* y tu *Team ID*.
3. En Supabase › Apple: agrega `sleonca.MyBasics.web` en *Client IDs* y genera el *Secret Key* con la
   herramienta que enlaza esa misma pantalla. Ese secreto vence cada 6 meses.
</details>

---

## 3. Continuar con Google

1. **Google Cloud Console** <https://console.cloud.google.com> › selector de proyectos › **New Project** › `MyBasics`.
2. **APIs & Services › OAuth consent screen** (o *Google Auth Platform*):
   - *App name*: `MyBasics`; *User support email* y *Developer contact*: tu correo.
   - *Audience*: **External**. Mientras esté en modo **Testing**, agrega como *Test users*
     las cuentas de Google con las que vas a probar.
   - *Scopes / Data access*: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile` (no sensibles).
3. **APIs & Services › Credentials › Create credentials › OAuth client ID** (hazlo dos veces):
   - **iOS** → *Bundle ID*: `sleonca.MyBasics` → *Create*. Copia el **Client ID**
     (`1234…-abc….apps.googleusercontent.com`).
   - **Web application** → nombre `Supabase` → *Authorized redirect URIs*:
     `https://TU-PROYECTO.supabase.co/auth/v1/callback` → *Create*. Copia el **Client ID** y el **Client secret**.
4. **Supabase › Authentication › Sign In / Providers › Google**
   - *Enable Sign in with Google*: activado.
   - *Client IDs*: los dos, separados por coma, **el web primero**: `WEB_CLIENT_ID,IOS_CLIENT_ID`.
   - *Client Secret (for OAuth)*: el secret del cliente **web**.
   - *Skip nonce checks*: **desactivado** (la app envía nonce).
   - Guarda.
5. **`Config/Secrets.xcconfig`**: `GOOGLE_IOS_CLIENT_ID = <Client ID de iOS>` (el Client ID no es secreto,
   pero vive con el resto de la configuración). Luego ⇧⌘K y ⌘R.
6. **Probar:** *Continuar con Google* abre una hoja de Google dentro de la app (iOS avisa
   "MyBasics quiere usar google.com para iniciar sesión": es normal) → elige la cuenta → vuelves a Inicio.

---

## 4. Criterio de aceptación: cada usuario ve solo sus datos

1. Entra con la **cuenta A** (p. ej. Apple) y registra 2 gastos.
2. **Ajustes › Cerrar sesión**. Entra con la **cuenta B** (Google o email): Inicio debe estar **vacío**
   y con sus propias 8 categorías.
3. Registra 1 gasto con B. En Supabase › **Table Editor › expenses** verás 3 filas con dos `user_id` distintos.
4. Vuelve a A: ves solo sus 2 gastos. ✅ (Esto lo garantiza RLS en el servidor, no la app.)
5. **Eliminar cuenta** (Ajustes) con B: vuelve al login; en Supabase desaparecen B de
   *Authentication › Users* y sus filas de las tablas. A no se toca.

## Problemas comunes

| Mensaje | Causa probable |
| --- | --- |
| *Este método de inicio de sesión no está habilitado en Supabase* | Falta activar el proveedor (Apple/Google/Email) en Supabase. |
| Apple: *Unacceptable audience in id_token* | *Client IDs* de Apple en Supabase no es exactamente `sleonca.MyBasics`. |
| Google: *Unacceptable audience* | Falta el Client ID de **iOS** en *Client IDs* de Google en Supabase. |
| Google: *Error 400: redirect_uri_mismatch* | El Client ID en `Secrets.xcconfig` no es el de tipo **iOS**. |
| Google: *Access blocked / app not verified* | Tu cuenta no está en *Test users* del consent screen. |
| *Confirma tu correo* al iniciar sesión | La cuenta no tocó el enlace de confirmación (o el correo no llegó: ver aviso de SMTP). |
| El enlace del correo abre Safari y no la app | Faltan `mybasics://auth-callback` / `mybasics://reset-password` en *Redirect URLs*. |
| *Eliminar cuenta* falla con *permission denied* | No se volvió a ejecutar `schema.sql` (falta `delete_my_account`). |

## Pendientes conocidos (para la Fase 5)

- **Revocar el token de Apple al eliminar la cuenta.** Apple pide usar su REST API para revocar el
  token cuando el usuario elimina la cuenta. Requiere la llave `.p8` en un servidor (p. ej. una Supabase
  Edge Function); hoy la app borra la cuenta y todos los datos, pero no revoca el token en Apple.
