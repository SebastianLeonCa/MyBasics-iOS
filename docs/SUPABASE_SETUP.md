# Configurar Supabase para MyBasics (Fase 2)

Tiempo estimado: 10 minutos. Todo en el plan gratuito.

> Mientras no completes `Config/Secrets.xcconfig`, la app sigue funcionando con los
> datos de ejemplo. En **Ajustes › Datos** ves cuál está usando: *Ejemplo* o *Supabase*.

## 1. Crear la cuenta y el proyecto

1. Entra a <https://supabase.com> y pulsa **Start your project**. Regístrate con GitHub o con tu email.
2. Si te pide crear una **organización**, ponle cualquier nombre (p. ej. tu nombre) y elige el plan **Free**.
3. Pulsa **New project** y completa:
   - **Name:** `MyBasics`
   - **Database password:** pulsa *Generate a password* y **guárdala** en tu gestor de contraseñas
     (la app no la usa, pero la necesitarás si algún día te conectas directo a Postgres).
   - **Region:** la más cercana a ti (p. ej. *East US* o *South America (São Paulo)*).
4. Pulsa **Create new project** y espera 1–2 minutos a que termine de prepararse.

## 2. Crear las tablas (ejecutar el SQL)

1. En el menú izquierdo abre **SQL Editor** y pulsa **New query** (o el botón **+**).
2. Abre el archivo [`supabase/schema.sql`](../supabase/schema.sql) de este repo, copia **todo** su contenido y pégalo.
3. Pulsa **Run** (o ⌘↵).
   - Si aparece un aviso de *“destructive operations”*, es por los `drop policy if exists` que
     permiten re-ejecutar el script sin errores. Confirma con **Run this query**.
   - Debe terminar en **Success**. Puedes volver a ejecutarlo cuando quieras: no borra datos.
4. Comprueba en **Table Editor** que existen `categories`, `expenses` y `debts`, y que las tres muestran
   el candado de **RLS enabled**.

## 3. Crear el usuario de prueba

1. Ve a **Authentication › Users** y pulsa **Add user › Create new user**.
2. Escribe un email (puede ser inventado, p. ej. `dev@mybasics.test`) y una contraseña.
3. Marca **Auto Confirm User** (así no hace falta confirmar el correo) y pulsa **Create user**.
4. Comprueba en **Table Editor › categories** que se crearon **8 categorías** para ese usuario
   (Comida, Supermercado, …, Suscripciones, Otros). Las crea el trigger del SQL.
   - ¿No aparecen? Vuelve a ejecutar `schema.sql`: la última línea siembra las categorías de los usuarios existentes.

> En **Authentication › Sign In / Providers**, el proveedor **Email** debe estar habilitado (lo está por defecto).

## 4. Copiar la URL y la llave al proyecto

1. En Supabase pulsa el botón **Connect** (arriba) o ve a **Project Settings**:
   - **Project URL:** *Project Settings › Data API* (se ve como `https://abcdefghijkl.supabase.co`).
   - **Llave pública:** *Project Settings › API Keys*. Copia la **Publishable key** (`sb_publishable_…`).
     Si tu proyecto solo muestra la pestaña **Legacy API keys**, copia la **anon / public**.
   - ⚠️ **Nunca** uses la *secret key* ni la *service_role*: esas saltan RLS y no deben ir en una app.
2. En tu Mac, dentro del repo:
   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # solo si aún no existe
   open -e Config/Secrets.xcconfig
   ```
3. Completa los cuatro valores. **Ojo con la URL:** en `.xcconfig` el `//` es un comentario, por eso va `https:/$()/`:
   ```
   SUPABASE_URL = https:/$()/abcdefghijkl.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_xxxxxxxxxxxxxxxx
   DEV_USER_EMAIL = dev@mybasics.test
   DEV_USER_PASSWORD = la-contraseña-del-paso-3
   ```
   Este archivo está en `.gitignore`: no se sube a GitHub (`git status` no debe mostrarlo).

## 5. Probar

1. En Xcode: **Product › Clean Build Folder** (⇧⌘K) y luego **Run** (⌘R).
2. La app muestra *Conectando…* un instante y luego Inicio vacío (tu base de datos está vacía).
   En **Ajustes › Datos** debe decir **Supabase**.
3. Toca **+**, registra un gasto y guárdalo.
4. En Supabase › **Table Editor › expenses** pulsa *Refresh*: ahí está la fila.
   Si lo marcaste como compartido, también aparece en **debts**.
5. Cierra la app por completo (desliza desde el selector de apps) y vuelve a abrirla: el gasto sigue ahí. ✅

## Problemas comunes

| Mensaje en la app | Causa probable |
| --- | --- |
| *No se pudo conectar con el servidor. Revisa SUPABASE_URL.* | URL mal escrita, o falta el `$()` en `https:/$()/`. |
| *No se pudo iniciar sesión con el usuario de prueba…* | Email/contraseña distintos a los del paso 3, o el usuario no está confirmado. |
| *La base de datos no está configurada…* | No se ejecutó `schema.sql` (o se ejecutó en otro proyecto). |
| *Ajustes › Datos* dice *Ejemplo* | `Secrets.xcconfig` aún tiene placeholders (`TU_…`). Corrige y haz Clean Build. |
| Todo funcionaba y de pronto no conecta | Los proyectos gratis se **pausan tras 7 días sin uso**. Reactívalo desde el dashboard. |

## Qué hay en `schema.sql`

- **Tablas** `categories`, `expenses`, `debts` (los “Compartidos” de la app). Dinero en `integer` de centavos.
- **Índices** por `user_id` y `(user_id, spent_at)`.
- **RLS “own rows”**: cada usuario solo lee/escribe filas con su `auth.uid()`. Además, un gasto solo puede usar
  categorías propias y un compartido solo puede colgar de gastos propios.
- **`save_expense(p_expense, p_debts)`**: guarda el gasto y sus compartidos en una sola transacción
  (si algo falla, no queda nada a medias). Corre con los permisos del usuario, así que RLS aplica.
- **Trigger `on_auth_user_created`**: siembra las 8 categorías por defecto al crear un usuario.
