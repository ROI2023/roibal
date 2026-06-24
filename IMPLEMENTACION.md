# Roibal App — Documento de Implementación

## Arquitectura

```
Flutter Web (roibal_app/)
    └── Build: Netlify (CI/CD desde GitHub)
    └── Auth: Supabase (Google OAuth via PKCE)
    └── Base de datos: Supabase (PostgreSQL + RLS)
    └── Repo: GitHub cuenta ROI2023
```

---

## 1. Repositorio GitHub

- **Cuenta:** ROI2023
- **Repo:** https://github.com/ROI2023/roibal.git
- **Remote configurado en** `.git/config` con token embebido en la URL HTTPS
- Push automático: `git push` sube a ROI2023/roibal sin pedir credenciales

---

## 2. Supabase

### Proyecto
| Campo | Valor |
|---|---|
| URL | `https://lzovmiybsqqiywdiaxnn.supabase.co` |
| Región | East US (North Virginia) |
| RLS | Habilitado |

### Variables
| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto |
| `SUPABASE_PUBLISHABLE_KEY` | Anon/public key (Settings → API) |

### Migraciones
Se corrieron 9 migraciones desde el panel SQL de Supabase. Si se necesita recrear el proyecto, correrlas en orden desde `roibal_app/` (scripts de migración en el repo).

### Configuración de Auth (Supabase Dashboard → Authentication → URL Configuration)
| Campo | Valor |
|---|---|
| Site URL | `https://roibal.netlify.app` |
| Redirect URLs | `https://roibal.netlify.app/**` |

### Google Provider (Authentication → Providers → Google)
- Habilitado: sí
- Client ID y Client Secret: provienen de Google Cloud Console (ver sección 3)

---

## 3. Google Cloud Console — OAuth

### Credenciales (APIs & Services → Credentials → OAuth 2.0 Client ID)
| Campo | Valor |
|---|---|
| Tipo | Web application |
| Authorized redirect URIs | `https://lzovmiybsqqiywdiaxnn.supabase.co/auth/v1/callback` |
| Authorized JavaScript origins | (vacío — no requerido para este flujo) |

> **Importante:** Google redirige a Supabase, no a la app. Supabase maneja el callback y luego redirige a Netlify.

### Flujo OAuth completo
```
App (Netlify) → Supabase inicia PKCE → Google autentica
→ Google redirige a supabase.co/auth/v1/callback
→ Supabase crea sesión → redirige a roibal.netlify.app
```

---

## 4. Netlify

### Sitio
- **URL:** https://roibal.netlify.app
- **Deploy:** automático al hacer push a `main` en GitHub

### Variables de entorno (Site configuration → Environment variables)
| Variable | Valor |
|---|---|
| `SUPABASE_URL` | `https://lzovmiybsqqiywdiaxnn.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `eyJhbGci...` (anon key completa) |

> Scope debe incluir **Builds** para que estén disponibles durante el build.

### netlify.toml
```toml
[build]
  base    = "roibal_app"
  publish = "build/web"
  command = """
    if [ ! -d $HOME/flutter ]; then
      git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
    fi
    export PATH="$PATH:$HOME/flutter/bin"
    flutter config --enable-web
    flutter pub get
    touch .env
    flutter build web --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
  """

[[redirects]]
  from   = "/*"
  to     = "/index.html"
  status = 200

[[headers]]
  for = "/*"
  [headers.values]
    Cross-Origin-Opener-Policy    = "same-origin"
    Cross-Origin-Embedder-Policy  = "require-corp"
    Cross-Origin-Resource-Policy  = "cross-origin"
```

> Los headers COOP/COEP son requeridos por el renderer Skwasm de Flutter web.

### Por qué `--dart-define` y no `.env`
Los env vars de Netlify no se exponen al shell de build via `printf`/`$VAR` en forma confiable. Con `--dart-define`, los valores quedan compilados directo en el JavaScript generado por Flutter. El `touch .env` solo existe para satisfacer el asset bundler (el archivo está declarado en `pubspec.yaml` como asset para desarrollo local).

---

## 5. Configuración Flutter (supabase_config.dart)

```dart
// Valores compilados en JS via --dart-define (Netlify)
static const _compiledUrl = String.fromEnvironment('SUPABASE_URL');
static const _compiledKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

static Future<void> initialize() async {
  String url = _compiledUrl;
  String key = _compiledKey;

  // Fallback a .env para desarrollo local
  if (url.isEmpty || key.isEmpty) {
    try {
      await dotenv.load(fileName: '.env');
      url = dotenv.env['SUPABASE_URL'] ?? '';
      key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    } catch (_) {}
  }
  await Supabase.initialize(url: url, publishableKey: key);
}
```

### Desarrollo local
El archivo `roibal_app/.env` (gitignored) contiene las variables para correr localmente:
```
SUPABASE_URL=https://lzovmiybsqqiywdiaxnn.supabase.co
SUPABASE_PUBLISHABLE_KEY=eyJhbGci...
```

---

## 6. Agregar dominio propio (NIC Argentina + Cloudflare)

### Paso 1 — Comprar dominio en NIC Argentina
1. Ir a https://nic.ar y registrar el dominio (ej. `roibal.com.ar`)
2. Una vez aprobado, ingresar al panel de NIC Argentina

### Paso 2 — Crear cuenta en Cloudflare y agregar el sitio
1. Ir a https://cloudflare.com → Add a Site → ingresar el dominio
2. Elegir plan **Free**
3. Cloudflare escanea los DNS existentes → Next
4. Cloudflare te da **dos nameservers** propios, ej:
   ```
   aaron.ns.cloudflare.com
   vera.ns.cloudflare.com
   ```

### Paso 3 — Delegar DNS a Cloudflare desde NIC Argentina
1. En el panel de NIC Argentina → tu dominio → **Modificar servidores de nombres**
2. Reemplazar los nameservers actuales por los dos que dio Cloudflare
3. Guardar — la propagación tarda entre 15 minutos y 48 horas

### Paso 4 — Configurar DNS en Cloudflare
En Cloudflare → tu dominio → **DNS → Records → Add record**:

| Type | Name | Target | Proxy |
|---|---|---|---|
| `CNAME` | `@` (o `www`) | `roibal.netlify.app` | Proxied (nube naranja) |

> Si querés `www.roibal.com.ar` que también funcione, agregá otro CNAME:
> `www` → `roibal.netlify.app`

### Paso 5 — Agregar dominio en Netlify
1. Netlify → tu sitio → **Domain management → Add a domain**
2. Ingresar `roibal.com.ar`
3. Netlify verifica el CNAME y emite el certificado SSL automáticamente (Let's Encrypt)
4. Esperar que aparezca el certificado como **Active**

### Paso 6 — Actualizar Supabase
En Authentication → URL Configuration:

| Campo | Valor anterior | Nuevo valor |
|---|---|---|
| Site URL | `https://roibal.netlify.app` | `https://roibal.com.ar` |
| Redirect URLs | `https://roibal.netlify.app/**` | `https://roibal.com.ar/**` |

> Podés dejar ambas URLs en Redirect URLs mientras transicionás.

### Paso 7 — Actualizar Google Cloud Console
En Credentials → OAuth 2.0 Client ID → **Authorized redirect URIs**:
- El URI de Supabase **no cambia** — Google siempre redirige a Supabase, no al dominio
- No hay nada que cambiar aquí

### Paso 8 — Actualizar Netlify (opcional)
Si querés que `roibal.netlify.app` redirija al dominio propio:
- Netlify → Domain management → `roibal.netlify.app` → **Set as primary domain** de `roibal.com.ar`
- Netlify maneja el redirect automáticamente

### Resumen de cambios al agregar dominio

| Servicio | Qué cambia |
|---|---|
| NIC Argentina | Nameservers → Cloudflare |
| Cloudflare | Agregar CNAME `@` → `roibal.netlify.app` |
| Netlify | Agregar custom domain, esperar SSL |
| Supabase | Site URL + Redirect URLs al nuevo dominio |
| Google Cloud Console | Nada (redirige a Supabase, no a la app) |
| Código Flutter | Nada |

---

## Checklist de deploy desde cero

- [ ] Crear proyecto Supabase (East US, RLS on)
- [ ] Copiar URL y anon key
- [ ] Correr las 9 migraciones SQL
- [ ] Habilitar Google Provider en Supabase con Client ID + Secret
- [ ] Configurar Site URL y Redirect URLs en Supabase Auth
- [ ] Crear OAuth Client ID en Google Cloud Console con redirect URI de Supabase
- [ ] Conectar repo GitHub a Netlify
- [ ] Setear `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` en Netlify env vars (scope: Builds)
- [ ] Verificar que `netlify.toml` esté en la raíz del repo
- [ ] Push → Netlify build automático
- [ ] Verificar en consola del browser que no aparezca `URL= key=(vacía)`
