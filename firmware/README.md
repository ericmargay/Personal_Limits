# Firmware ESP32 · NeoPixels

Muestra físicamente el uso de Claude y Codex con una tira de NeoPixels. El
ESP32 levanta un pequeño servidor HTTP en tu red Wi‑Fi y la app iOS (o el
widget) le envía los porcentajes cada vez que actualiza.

## Hardware

| Pieza | Nota |
|-------|------|
| ESP32 (cualquier DevKit) | Con Wi‑Fi, obviamente |
| Tira/anillo NeoPixel (WS2812B) | 16 LEDs por defecto; ajustable |
| Resistencia 330 Ω | En serie con DIN |
| Condensador 1000 µF | Entre 5 V y GND de la tira |

Conexión: `GPIO 5 → 330 Ω → DIN`, `5 V → 5 V`, `GND → GND` (GND común con el
ESP32). Con pocos LEDs el nivel lógico de 3,3 V suele bastar; si parpadea,
añade un conversor de nivel (74AHCT125) o alimenta la tira a ~4,3 V.

## Instalación

1. Arduino IDE → Gestor de placas: instala **esp32** (Espressif).
2. Gestor de librerías: instala **ArduinoJson** (7.x) y **Adafruit NeoPixel**.
3. Copia `esp32_limits/config.example.h` a `esp32_limits/config.h` y rellena
   Wi‑Fi, pin, número de LEDs y segmentos.
4. Abre `esp32_limits/esp32_limits.ino`, elige la placa y sube.
5. En el monitor serie (115200) verás la IP y `http://limits.local`.

## Segmentos

`LED_SEGMENTS` reparte la tira entre proveedores y ventanas:

```c
{"claude", 0, 0, 4}   // Claude, ventana 0 (sesión 5 h), LEDs 0-3
{"claude", 1, 4, 4}   // Claude, ventana 1 (semana),     LEDs 4-7
{"codex",  0, 8, 4}   // Codex,  sesión,                  LEDs 8-11
{"codex",  1, 12, 4}  // Codex,  semana,                  LEDs 12-15
```

Cada segmento se llena proporcionalmente al porcentaje (verde → amarillo →
naranja → rojo). Con `SHOW_REMAINING true` se invierte: los LEDs muestran lo
que te queda. Sin datos la tira respira en azul; si los datos tienen más de
`STALE_MINUTES`, se atenúan y pulsan.

## API

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/usage` | Recibe el JSON de la app y actualiza los LEDs |
| `GET` | `/` o `/status` | Estado en JSON (uptime, último dato, proveedores) |

Prueba sin la app:

```bash
curl -X POST http://limits.local/usage -H 'Content-Type: application/json' -d '{
  "updatedAt": 0,
  "providers": [
    {"id": "claude", "name": "Claude", "windows": [
      {"id": "five_hour", "label": "Sesión", "percent": 42},
      {"id": "seven_day", "label": "Semana", "percent": 12}]},
    {"id": "codex", "name": "Codex", "windows": [
      {"id": "primary", "label": "Sesión", "percent": 80},
      {"id": "secondary", "label": "Semana", "percent": 95}]}
  ]
}'
```

El ESP32 anuncia el servicio Bonjour `_limits._tcp`, así que en la app
(Ajustes → ESP32) aparece en "Encontrados en la red" y basta con tocarlo.
