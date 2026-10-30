# StockPyme — reglas para la compilación final (R8).
# Evitan que Android borre código de los complementos que se usa desde Flutter.

# Complementos de Flutter (shared_preferences, in_app_purchase, etc.)
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Puente JNI que usa shared_preferences
-keep class com.github.dart_lang.jni.** { *; }

# Corrutinas de Kotlin (aparecen en las firmas de los métodos)
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }

# Escáner de códigos de barras
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Google Play Billing (suscripción)
-keep class com.android.billingclient.** { *; }

# Firebase (cuentas y nube)
-keep class com.google.firebase.** { *; }
-keep class io.grpc.** { *; }

-dontwarn com.google.android.play.core.**
