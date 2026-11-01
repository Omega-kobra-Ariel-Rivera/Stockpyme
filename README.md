# StockPyme

**Inventario y punto de venta para almacenes, minimarkets y pymes.**
App Flutter para Android y Windows, desarrollada por **Rivera Systems** (San Felipe, Chile).

Precios Premium (StockPyme Pro), con **14 días de prueba gratis**:

| Plan | Precio | Equivale a |
|---|---|---|
| Mensual | **$4.990** al mes | — |
| Anual | **$49.900** al año | $4.158 al mes (2 meses gratis) |

Los montos están en `lib/utils/constants.dart` (`PremiumPlan`) y deben ser iguales a los del servidor de pagos (`Stockpyme-pagos`), que es el que cobra.

## Funciones

| Función | Detalle |
|---|---|
| Productos | Nombre, código de barras, categoría, unidad (unidad, kg, litro…), costo, precio, stock y stock mínimo |
| Escáner | Lee códigos de barras con la cámara para buscar, crear o vender |
| Punto de venta | Carrito con cantidades a granel, medios de pago y cálculo de vuelto |
| Stock | Descuento automático al vender, entradas de mercadería, mermas e historial por producto |
| Alertas | Productos bajo el mínimo destacados en Inicio |
| Reportes | Ventas, ganancia, ticket promedio, gráfico diario y más vendidos (hoy, 7 y 30 días) |
| Exportar | Inventario y ventas en CSV para Excel o Google Sheets |
| Suscripción | Prueba de 14 días y planes mensual, semestral y anual con **Mercado Pago** |
| Idiomas | Español, inglés y portugués (se elige en Ajustes o en la pantalla de inicio de sesión) |
| Monedas | Peso chileno, argentino, colombiano y mexicano, sol peruano, dólar, euro y real (con centavos donde corresponde) |
| Demo | Carga productos de ejemplo para mostrar la app |
| Cuentas | Inicio de sesión con correo y contraseña o con Google; recuperar contraseña |
| Nube | Respaldo automático de productos y ventas; se recuperan al cambiar de teléfono |
| Administrador | Panel con todas las cuentas, negocios, planes, inventarios con precios y ventas; activar Pro a mano |

Funciona **sin internet**: los datos quedan guardados en el teléfono.

## Novedades v1.5.0

- **Idiomas**: español, inglés y portugués. La app parte en el idioma del teléfono; se cambia en
  *Ajustes → Idioma* o con el botón **ES / EN / PT** del inicio de sesión.
- **Monedas**: cada negocio elige su moneda en *Ajustes → Moneda* (CLP, ARS, COP, MXN, PEN, USD, EUR, BRL).
  Las monedas con centavos aceptan precios como `12,50`. Al cambiar de moneda los números se mantienen
  (no se convierten con el tipo de cambio).
- **Dos niveles de plan** (hay que actualizar también el servidor de pagos `Stockpyme-pagos`):
  - **Básico** (solo celular): $4.990 mes · $26.990 semestre · $49.900 año.
  - **Negocio** (celular + PC, equipos ilimitados): $7.990 mes · $43.990 semestre · $79.900 año.
  - La prueba gratis de 14 días es solo en el celular; en el PC se necesita el Plan Negocio.
  - Quien tiene Básico puede pasar a Negocio desde la app (después cancela el Básico en Mercado Pago).
  - El Pro pagado en un equipo se reconoce en los demás con la misma cuenta.
- **Reglas de Firestore actualizadas** (campo `manualProTier`): vuelve a publicar `firestore.rules`.
- El administrador ve cada negocio en su propia moneda y puede dar Básico o Negocio por 30 días, 6 meses o 1 año.
- Para agregar un texto nuevo: escríbelo con `tr('Texto en español')` y agrega su traducción en
  `lib/l10n/translations_en.dart` y `lib/l10n/translations_pt.dart`.

## Novedades v1.4.0

- **Programa para Windows** con instalador `.exe` y versión portátil `.zip`, generados solos en GitHub.
- **Lector USB de códigos de barras** en el PC.
- **Menú lateral** en pantallas anchas (PC y tablet).
- **Plan anual** de $49.900 (2 meses gratis) además del mensual de $4.990.

## Novedades v1.3.0

- **Inicio de sesión** con correo y contraseña o con **Google**, con registro (nombre y negocio) y recuperación de contraseña.
- **Cada cuenta tiene su propio negocio** en el teléfono. Los datos de la versión anterior pasan automáticamente a la primera cuenta que inicie sesión.
- **Respaldo en la nube** (Firestore): productos y ventas se suben solos unos segundos después de cada cambio. La app sigue funcionando sin internet.
- **Panel de administración** (solo para correos administradores): cuentas, negocios, plan de cada uno, inventario con precios, costo, margen y stock, y últimas ventas. Permite **activar Pro 30 días o 1 año** cuando alguien paga por fuera de la app.
- La **prueba gratis queda ligada a la cuenta**: reinstalar la app no regala días.
- **Plan anual** de $49.900 (2 meses gratis) además del mensual de $4.990, elegible en la pantalla Premium.
- **Firma fija del APK**: el inicio con Google funciona y las actualizaciones se instalan encima, sin desinstalar.

## Programa para Windows (PC)

StockPyme también funciona como **programa de escritorio para Windows 10 y 11**, con las mismas cuentas y datos que el teléfono.

- **Descargar:** en GitHub → **Releases** → *StockPyme Windows prueba (build N)*:
  - `StockPyme-Instalador-vX.exe`: instalador con acceso directo en el escritorio (recomendado).
  - `StockPyme-Windows-vX.zip`: versión portátil, se descomprime y se abre `stock_pyme.exe`.
- **Lector de códigos de barras USB:** al tocar el botón del escáner se abre un cuadro; pasa el producto por el lector (o escribe el código) y se agrega solo.
- **Cuentas:** en el PC se entra con **correo y contraseña**. Firebase no ofrece el inicio con Google en Windows; quien creó la cuenta con Google puede crear una contraseña con *¿Olvidaste tu contraseña?* usando el mismo correo.
- **Pantalla ancha:** el menú pasa a la izquierda.
- Windows puede mostrar *"Windows protegió su PC"* porque el programa no está firmado con un certificado pagado: toca **Más información → Ejecutar de todas formas**.

Lo compila solo el workflow `build-windows.yml` en cada `git push` (tarda unos 15 minutos). Para probarlo en tu PC necesitas Visual Studio 2022 con *Desarrollo para el escritorio con C++*:

```powershell
flutter create --org cl.riverasystems --project-name stock_pyme --platforms windows .
flutter run -d windows
```

## Configurar Firebase (una sola vez)

Las cuentas y la nube usan **Firebase** (gratis para empezar). Sin este paso la app abre con el aviso *"Falta configurar Firebase"*.

### 1. Crear el proyecto

1. Entra a [console.firebase.google.com](https://console.firebase.google.com) → **Agregar proyecto** → nombre `stockpyme`.
2. **Authentication → Comenzar → Método de acceso**:
   - Activa **Correo electrónico/contraseña**.
   - Activa **Google** (elige tu correo como correo de asistencia).
3. **Firestore Database → Crear base de datos** → modo **producción** → ubicación `southamerica-east1 (São Paulo)`.
4. **Firestore → Reglas**: borra lo que hay, pega el contenido de [`firestore.rules`](firestore.rules) y toca **Publicar**.

### 2. Hacerte administrador

En **Firestore → Datos → Iniciar colección**:

- ID de la colección: `admins`
- ID del documento: **tu correo en minúsculas** (el mismo con que entrarás a la app, por ejemplo con Google)
- Campo: `rol` · tipo string · valor `admin` → **Guardar**

Para que el panel aparezca, entra a la app **con Google** con ese correo (las reglas exigen un correo verificado, y los de Google ya lo están).

### 3. Conectar la app (en tu PC, en la carpeta del proyecto)

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=ID-DE-TU-PROYECTO --platforms=android,web,windows --android-package-name=cl.riverasystems.stock_pyme
```

Esto reemplaza `lib/firebase_options.dart` (y puede agregar `android/app/google-services.json`). Si Windows no reconoce `flutterfire`, cierra y abre VS Code.

### 4. Huellas de la llave de firma

En **Firebase → Configuración del proyecto → Tus apps → Android → Agregar huella digital**, agrega el **SHA-1** y el **SHA-256** que vienen en `LEEME_llave_StockPyme.txt`. Sin esto, *Continuar con Google* da error en el teléfono.

### 5. Secretos de GitHub (firma fija)

En el repositorio: **Settings → Secrets and variables → Actions → New repository secret**. Crea `KEY_ALIAS`, `KEYSTORE_PASSWORD` y `KEYSTORE_BASE64` con los valores de `LEEME_llave_StockPyme.txt`.

> La llave (`.jks`) y su contraseña **nunca** se suben al repositorio. Guárdalas en un lugar seguro: sin ellas no podrás actualizar la app en Google Play.

### 6. Subir y compilar

```powershell
git add .
git commit -m "StockPyme v1.3: cuentas, nube y panel de administración"
git push
```

Como cambia la firma, **desinstala una última vez** la versión anterior del teléfono. Desde aquí, las actualizaciones se instalan encima.

## Novedades v1.2.0

- **Pago con Mercado Pago:** el botón "Pagar con Mercado Pago" abre Mercado Pago directamente (la app de Mercado Pago o el navegador). El cobro se repite automáticamente cada mes.
- La app revisa sola si el pago se aprobó al volver de Mercado Pago y una vez al día.
- El Access Token **no va en la app**: vive en el servidor de pagos (`stockpyme-pagos`, funciones de Netlify).
- Para cambiar la dirección del servidor, edita `paymentsApiUrl` en `lib/utils/constants.dart`.

## Novedades v1.1.0

- Diseño más profesional: tema unificado, tarjetas con borde, barra de navegación y tipografía más marcada.
- Inicio con un resumen destacado de las ventas del día (total, número de ventas y ganancia).
- Pantalla de suscripción renovada, con la etiqueta "14 días gratis".
- Firma de Rivera Systems con el logo en la pantalla de carga, en Inicio, en la suscripción y en Ajustes.
- La app aparece como **StockPyme** en el teléfono.

## Estructura

```
lib/
├── main.dart            Arranque: Firebase, sesión y datos de cada cuenta
├── firebase_options.dart  Configuración de Firebase (la crea flutterfire)
├── models/              Producto, venta, movimiento, reportes, cuenta (admin)
├── services/            Almacenamiento, inventario, carrito, suscripción,
│                        cuentas (auth), nube (sync) y administración
├── screens/             Inicio, productos, vender, reportes, ajustes, suscripción
│   ├── auth/            Inicio de sesión y registro
│   └── admin/           Panel de administración
├── widgets/             Componentes reutilizables
└── utils/               Tema, constantes, formatos, permisos de acceso
assets/branding/         Ícono, pantalla de inicio y logo de Rivera Systems
.github/workflows/       Compilación automática del APK (con firma fija)
firestore.rules          Reglas de seguridad de la base de datos
```

## Compilar el APK

Cada `git push` a `main` compila el APK en GitHub Actions y lo publica en **Releases** como versión de prueba.

Para publicar una versión oficial:

```bash
git tag v1.1.0
git push origin v1.1.0
```

## Probar en el computador

```bash
flutter pub get
flutter run
```

## Publicar en Google Play

1. Crea tu clave de firma (keystore) y configúrala en `android/app/build.gradle.kts`.
2. Compila con `flutter build appbundle --release`.
3. En Google Play, las suscripciones dentro de la app deben cobrarse con Google Play Billing.
   La versión con Google Play Billing está en el historial de Git (v1.1.0).

---

© Rivera Systems
