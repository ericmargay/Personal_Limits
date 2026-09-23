// Copia este fichero como config.h y rellena tus datos (config.h está en .gitignore).
#pragma once

#define WIFI_SSID      "MiWiFi"
#define WIFI_PASSWORD  "secreto"

// Nombre mDNS: la app lo descubre por Bonjour y lo usa como http://limits.local
#define MDNS_HOSTNAME  "limits"

// NeoPixels
#define LED_PIN        5      // GPIO conectado a DIN de la tira
#define LED_COUNT      16
#define LED_BRIGHTNESS 48     // 0-255

// false: los LEDs muestran lo consumido (se llenan al gastar cuota)
// true:  los LEDs muestran lo que queda (se apagan al gastar cuota)
#define SHOW_REMAINING false

// Si no llegan datos en este tiempo, la tira se atenúa y respira
#define STALE_MINUTES  120

#define MAX_PROVIDERS  4
#define MAX_WINDOWS    3

// Segmentos de la tira: { id de proveedor, índice de ventana (0 = sesión, 1 = semana), primer LED, nº de LEDs }
#define LED_SEGMENTS { \
  {"claude", 0, 0, 4}, \
  {"claude", 1, 4, 4}, \
  {"codex",  0, 8, 4}, \
  {"codex",  1, 12, 4} \
}
