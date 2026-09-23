# Personal Limits

App para iPhone, iPad y Apple Watch (SwiftUI) que muestra los límites de uso de
**Claude** (Pro/Max, el mismo dato que `/usage` en Claude Code) y de **Codex**
(ChatGPT Plus/Pro), con:

- **Widgets** de pantalla de inicio (pequeño, mediano, grande, extragrande en iPad) y de
  pantalla bloqueada (circular, rectangular, inline) con cuenta atrás hasta el reinicio.
- **Apple Watch**: app y complicaciones (circular, esquina, rectangular, inline)
  sincronizadas desde el iPhone por WatchConnectivity.
- **Actualización en segundo plano** (`BGAppRefreshTask`) y refresco propio del widget
  cada 15–30 min, con renovación de tokens serializada entre app y widget.
- **Envío a un ESP32** por Wi‑Fi para reflejar el uso con NeoPixels (firmware en `firmware/`)
  y sección para pedir el módulo ya montado en Etsy.
- **Monetización con anuncios** (Google AdMob, banner al pie del panel) con consentimiento
  UMP y App Tracking Transparency ya integrados.
- **Sitio web** para GitHub Pages en `docs/` (landing, privacidad, términos, soporte).

Usa endpoints no documentados de Claude Code y Codex CLI que pueden cambiar sin aviso.

## Estructura

```
project.yml                 Especificación XcodeGen (el .xcodeproj generado también está en el repo)
App/                        App iOS/iPadOS (vistas, OAuth en Safari, anuncios, puente con el Watch)
  Ads/                      AdsConfig (IDs), AdsManager (UMP + ATT + SDK), AdBannerView
  Store/StoreLinks.swift    URLs públicas: web, privacidad, soporte, Etsy, App Store
  Watch/WatchBridge.swift   Envía las lecturas al reloj y atiende sus peticiones
Widget/                     Extensión WidgetKit iOS (configurable: Todos / Claude / Codex)
Watch/                      App watchOS (SwiftUI) + WatchSessionManager
WatchWidget/                Complicaciones watchOS (WidgetKit)
Shared/                     Código común (proveedores, OAuth, llavero, caché, cliente ESP32)
firmware/esp32_limits/      Sketch Arduino para ESP32 + NeoPixels
docs/                       Sitio web estático para GitHub Pages
```

## Requisitos

- Xcode 26 (o 16+), iPhone con iOS 17+, Apple Watch con watchOS 10+ (opcional).
- Para probar: un Apple ID (cuenta gratuita). Para publicar: Apple Developer Program (99 $/año).
- Opcional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) si editas `project.yml`.
- La primera compilación descarga el SDK de Google Mobile Ads por Swift Package Manager.

## Instalar en el iPhone (cuenta gratuita)

1. Abre `PersonalLimits.xcodeproj` en Xcode.
2. En **Xcode → Settings → Accounts** añade tu Apple ID si no está.
3. En cada target (**PersonalLimits**, **PersonalLimitsWidget**, **PersonalLimitsWatch**,
   **PersonalLimitsWatchWidget**) → *Signing & Capabilities* → *Team*: tu equipo.
   - Si otro Apple ID ya usa el bundle ID, cambia `com.ericmargay.personallimits` (y los sufijos
     `.widget`, `.watchkitapp`, `.watchkitapp.widget`) en `project.yml`, el App Group
     `group.com.ericmargay.personallimits` en los cuatro `.entitlements` y en `Shared/AppConfig.swift`,
     y `WKCompanionAppBundleIdentifier` en `Watch/Info.plist`. Regenera con `xcodegen generate`.
4. Conecta el iPhone, elige el dispositivo y pulsa **Run** (⌘R).
5. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos → confía** en tu Apple ID.
6. Activa **Ajustes → General → Actualización en segundo plano** para Personal Limits.

Con cuenta gratuita la firma caduca a los **7 días** (vuelve a pulsar Run) y hay un máximo de
10 App IDs nuevos por semana (esta app usa 4: app, widget, watch app, watch widget).

## Conectar proveedores

En **Ajustes → Proveedores → Conectar**:

- **Claude**: se abre Safari con el inicio de sesión de Claude. La app pide únicamente el scope
  de lectura (`user:profile`): el token puede leer el uso pero **no** enviar prompts ni gastar cuota.
- **Codex**: inicio de sesión de OpenAI. El token se renueva solo cuando caduca.

Los tokens se guardan en el llavero (compartido con el widget mediante el App Group) y nunca
salen del dispositivo salvo hacia la API del proveedor.

**Alternativa**: *Pegar credenciales de otro equipo…* acepta el contenido de
`~/.claude/.credentials.json`, de `~/.codex/auth.json` o un token suelto. Estos tokens no se
renuevan desde el iPhone (para no invalidar los del Mac); el de Claude caduca en unas 8 h.

## Widget y Apple Watch

Mantén pulsada la pantalla de inicio → **+** → *Personal Limits*. Al editarlo puedes elegir
*Todos*, *Claude* o *Codex*. El widget pide a WidgetKit una recarga cada 15 min y en cada recarga
consulta los proveedores (renovando el token si hace falta); iOS concede unas 40–70 recargas al
día, así que en la práctica se actualiza cada 15–30 min sin abrir la app.

El **Apple Watch** no tiene los tokens (su llavero es independiente): recibe las lecturas del
iPhone por WatchConnectivity cada vez que la app o la actualización en segundo plano leen datos,
y puede pedir una lectura nueva con *Actualizar desde iPhone*. Las complicaciones se añaden desde
la esfera como cualquier otra.

## ESP32 / NeoPixels

1. Flashea el firmware siguiendo [`firmware/README.md`](firmware/README.md).
2. En la app: **Ajustes → ESP32 / NeoPixels**, activa *Enviar uso al ESP32* y elige el dispositivo
   en *Encontrados en la red* (Bonjour) o escribe `limits.local` / su IP.
3. *Probar conexión* muestra el estado del ESP32; *Enviar datos ahora* fuerza un envío.

La sección *Módulo listo para usar* enlaza a la tienda Etsy (`StoreLinks.etsyShop`): cambia la
URL por la de tu tienda cuando la crees.

## Publicar en la App Store (con anuncios)

Lo que ya está hecho en el proyecto:

- iPad (`TARGETED_DEVICE_FAMILY 1,2`) con todas las orientaciones y widgets grandes.
- Apple Watch (app + complicaciones) embebida en la app iOS.
- Google Mobile Ads 13 por SPM, `AdsManager` con consentimiento UMP (GDPR) y ATT, banner
  adaptativo al pie del panel principal. Solo el panel tiene anuncios; widgets y Watch no.
- `Info.plist`: `GADApplicationIdentifier`, `NSUserTrackingUsageDescription`, los 50
  `SKAdNetworkItems` de Google, orientaciones iPad.
- `PrivacyInfo.xcprivacy` en los cuatro targets (UserDefaults CA92.1/1C8F.1; la app declara
  seguimiento y datos de publicidad por AdMob).
- Icono 1024 sin canal alfa (requisito de App Store Connect).
- Sitio con política de privacidad, términos y soporte (`docs/`).

Lo que tienes que hacer tú:

1. **Apple Developer Program**: inscríbete y cambia el Team en los cuatro targets.
2. **AdMob**: crea la app y un bloque de banner. Pon el ID de app en `GADApplicationIdentifier`
   (`App/Info.plist`) y el del bloque en `AdsConfig.productionBannerUnitID`. Mientras el ID
   empiece por `REEMPLAZA`, la versión Release no pide anuncios. En *Privacidad y mensajes* de
   AdMob crea el mensaje GDPR y el de IDFA. **Nunca publiques con los IDs de prueba.**
3. **GitHub Pages**: en el repo, *Settings → Pages → Deploy from a branch → master, carpeta
   `/docs`*. La URL será `https://ericmargay.github.io/Personal_Limits/`. Cambia el correo
   `CAMBIA-ESTE-CORREO@ejemplo.com` en `docs/privacy.html`, `terms.html` y `support.html`.
   Si usas dominio propio, actualiza `StoreLinks` y añade `docs/CNAME`.
4. **Etsy**: crea la tienda y sustituye `StoreLinks.etsyShop` y el enlace de `docs/index.html`.
5. **App Store Connect**: URL de privacidad y de soporte (las de `docs/`), *App Privacy* coherente
   con `PrivacyInfo.xcprivacy` (Device ID, Advertising Data, Product Interaction, Crash Data,
   usados para publicidad de terceros), capturas de iPhone, iPad y Watch, categoría Utilidades.
6. **Idioma**: la app está solo en español. Para un lanzamiento global conviene añadir inglés con
   un String Catalog (`Localizable.xcstrings`); es el mayor pendiente para ampliar mercado.
7. **Riesgo legal**: la política de Anthropic para Claude Code (*Authentication and credential
   use*) dice que no permite a terceros ofrecer inicio de sesión con Claude.ai en sus apps ni
   almacenar tokens de sesión, aunque apps equivalentes sigan en la App Store con scope de solo
   lectura. Anthropic puede bloquear el endpoint sin aviso. Valóralo antes de publicar y no uses
   los nombres o logos de Anthropic/OpenAI en el nombre o el icono de la app.

## Limitaciones conocidas

- iOS decide cuándo ejecutar la actualización en segundo plano (típicamente cada 15–60 min si
  usas la app con regularidad).
- Los endpoints (`api.anthropic.com/api/oauth/usage`, `chatgpt.com/backend-api/wham/usage`) no
  son públicos; si cambian, el parseo está en `Shared/Providers/`.
- Claude limita las peticiones al endpoint de uso; la app no consulta más de una vez cada 3 min
  al abrirse.

## Regenerar el proyecto

```bash
brew install xcodegen
xcodegen generate
```

Al regenerar se pierde el Team elegido en Xcode; vuelve a seleccionarlo o escribe tu
`DEVELOPMENT_TEAM` en `project.yml`.

## Créditos

Flujo OAuth y endpoints contrastados con el proyecto de código abierto
[stavrop/ai-usage-limits](https://github.com/stavrop/ai-usage-limits) (Apache 2.0).
