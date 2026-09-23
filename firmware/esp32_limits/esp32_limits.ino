// Personal Limits — firmware ESP32
//
// Recibe por HTTP el porcentaje de uso de Claude / Codex que le envía la app
// iOS (POST /usage) y lo pinta en una tira de NeoPixels.
//
// Librerías (Gestor de librerías de Arduino IDE):
//   - ArduinoJson (v7)
//   - Adafruit NeoPixel
// Placa: "ESP32 Dev Module" (o la que uses) con el core de Espressif.

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>
#include <Adafruit_NeoPixel.h>
#include "config.h"

struct Segment {
  const char* provider;
  uint8_t window;
  uint8_t start;
  uint8_t count;
};
static const Segment SEGMENTS[] = LED_SEGMENTS;
static const size_t SEGMENT_COUNT = sizeof(SEGMENTS) / sizeof(SEGMENTS[0]);

struct WindowState {
  bool valid = false;
  float percent = 0;
  long resetsAt = 0;
  char label[16] = "";
};

struct ProviderState {
  bool valid = false;
  char id[16] = "";
  char name[24] = "";
  WindowState windows[MAX_WINDOWS];
};

ProviderState providers[MAX_PROVIDERS];
bool haveData = false;
unsigned long lastUpdateMs = 0;
long lastUpdatedAt = 0;

Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
WebServer server(80);

// ---------- Color ----------

uint32_t colorForPercent(float pct) {
  if (pct < 50) return strip.Color(0, 200, 60);     // verde
  if (pct < 75) return strip.Color(220, 200, 0);    // amarillo
  if (pct < 90) return strip.Color(255, 110, 0);    // naranja
  return strip.Color(255, 20, 20);                  // rojo
}

uint32_t scaleColor(uint32_t c, float f) {
  if (f < 0) f = 0;
  if (f > 1) f = 1;
  uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * f);
  uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * f);
  uint8_t b = (uint8_t)((c & 0xFF) * f);
  return strip.Color(r, g, b);
}

// ---------- Estado ----------

ProviderState* findProvider(const char* id) {
  for (size_t i = 0; i < MAX_PROVIDERS; i++) {
    if (providers[i].valid && strcmp(providers[i].id, id) == 0) return &providers[i];
  }
  return nullptr;
}

bool isStale() {
  return !haveData || (millis() - lastUpdateMs) > (unsigned long)STALE_MINUTES * 60UL * 1000UL;
}

// ---------- Render ----------

void renderUsage(float dim) {
  strip.clear();
  for (size_t s = 0; s < SEGMENT_COUNT; s++) {
    const Segment& seg = SEGMENTS[s];
    ProviderState* p = findProvider(seg.provider);
    if (!p || seg.window >= MAX_WINDOWS || !p->windows[seg.window].valid) {
      // Sin datos para este segmento: un LED tenue azul como marcador.
      if (seg.count > 0) strip.setPixelColor(seg.start, scaleColor(strip.Color(0, 0, 120), dim));
      continue;
    }
    float pct = p->windows[seg.window].percent;
    uint32_t color = colorForPercent(pct);
    float shown = SHOW_REMAINING ? (100.0f - pct) : pct;
    float lit = (shown / 100.0f) * seg.count;
    for (uint8_t i = 0; i < seg.count; i++) {
      uint16_t idx = seg.start + i;
      if (idx >= LED_COUNT) break;
      float level;
      if (i + 1 <= lit) level = 1.0f;
      else if (i < lit) level = lit - i;         // LED parcial
      else level = 0.06f;                        // fondo muy tenue para ver el segmento
      strip.setPixelColor(idx, scaleColor(color, level * dim));
    }
  }
  strip.show();
}

void renderIdle(unsigned long now) {
  // Respiración lenta en azul mientras no hay datos.
  float phase = (now % 4000) / 4000.0f;
  float level = 0.15f + 0.35f * (0.5f + 0.5f * sinf(phase * 2.0f * PI));
  strip.clear();
  for (uint16_t i = 0; i < LED_COUNT; i++) {
    strip.setPixelColor(i, scaleColor(strip.Color(20, 60, 255), level));
  }
  strip.show();
}

void render(unsigned long now) {
  if (!haveData) {
    renderIdle(now);
    return;
  }
  float dim = 1.0f;
  if (isStale()) {
    // Datos viejos: se mantienen pero atenuados y con un pulso suave.
    float phase = (now % 3000) / 3000.0f;
    dim = 0.25f + 0.15f * (0.5f + 0.5f * sinf(phase * 2.0f * PI));
  }
  renderUsage(dim);
}

// ---------- HTTP ----------

void sendJSON(int code, const String& body) {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(code, "application/json", body);
}

void handleUsage() {
  if (!server.hasArg("plain")) {
    sendJSON(400, "{\"ok\":false,\"error\":\"cuerpo vacío\"}");
    return;
  }
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err) {
    sendJSON(400, String("{\"ok\":false,\"error\":\"") + err.c_str() + "\"}");
    return;
  }

  for (size_t i = 0; i < MAX_PROVIDERS; i++) providers[i].valid = false;

  size_t n = 0;
  for (JsonObject p : doc["providers"].as<JsonArray>()) {
    if (n >= MAX_PROVIDERS) break;
    ProviderState& st = providers[n];
    st.valid = true;
    strlcpy(st.id, p["id"] | "", sizeof(st.id));
    strlcpy(st.name, p["name"] | "", sizeof(st.name));
    for (size_t w = 0; w < MAX_WINDOWS; w++) st.windows[w].valid = false;
    size_t wi = 0;
    for (JsonObject w : p["windows"].as<JsonArray>()) {
      if (wi >= MAX_WINDOWS) break;
      WindowState& ws = st.windows[wi];
      ws.valid = true;
      ws.percent = w["percent"] | 0.0f;
      ws.resetsAt = w["resetsAt"] | 0L;
      strlcpy(ws.label, w["label"] | "", sizeof(ws.label));
      wi++;
    }
    n++;
  }

  lastUpdatedAt = doc["updatedAt"] | 0L;
  lastUpdateMs = millis();
  haveData = n > 0;

  Serial.printf("[usage] %u proveedores recibidos\n", (unsigned)n);
  for (size_t i = 0; i < n; i++) {
    Serial.printf("  %s:", providers[i].id);
    for (size_t w = 0; w < MAX_WINDOWS; w++) {
      if (providers[i].windows[w].valid)
        Serial.printf(" %s=%.0f%%", providers[i].windows[w].label, providers[i].windows[w].percent);
    }
    Serial.println();
  }

  render(millis());
  sendJSON(200, "{\"ok\":true}");
}

void handleStatus() {
  JsonDocument doc;
  doc["device"] = MDNS_HOSTNAME;
  doc["uptimeSeconds"] = millis() / 1000;
  doc["haveData"] = haveData;
  doc["stale"] = isStale();
  doc["secondsSinceUpdate"] = haveData ? (millis() - lastUpdateMs) / 1000 : -1;
  doc["updatedAt"] = lastUpdatedAt;
  JsonArray arr = doc["providers"].to<JsonArray>();
  for (size_t i = 0; i < MAX_PROVIDERS; i++) {
    if (!providers[i].valid) continue;
    JsonObject p = arr.add<JsonObject>();
    p["id"] = providers[i].id;
    JsonArray ws = p["windows"].to<JsonArray>();
    for (size_t w = 0; w < MAX_WINDOWS; w++) {
      if (!providers[i].windows[w].valid) continue;
      JsonObject o = ws.add<JsonObject>();
      o["label"] = providers[i].windows[w].label;
      o["percent"] = providers[i].windows[w].percent;
      o["resetsAt"] = providers[i].windows[w].resetsAt;
    }
  }
  String out;
  serializeJson(doc, out);
  sendJSON(200, out);
}

void handleNotFound() {
  sendJSON(404, "{\"ok\":false,\"error\":\"ruta no encontrada\"}");
}

// ---------- Arranque ----------

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(MDNS_HOSTNAME);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("Conectando a %s", WIFI_SSID);
  unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print('.');
    renderIdle(millis());
    if (millis() - started > 30000) {
      Serial.println("\nSin Wi-Fi, reiniciando…");
      ESP.restart();
    }
  }
  Serial.printf("\nConectado. IP: %s\n", WiFi.localIP().toString().c_str());
}

void setup() {
  Serial.begin(115200);
  strip.begin();
  strip.setBrightness(LED_BRIGHTNESS);
  strip.show();

  connectWiFi();

  if (MDNS.begin(MDNS_HOSTNAME)) {
    MDNS.addService("limits", "tcp", 80);   // _limits._tcp: lo busca la app
    MDNS.addService("http", "tcp", 80);
    Serial.printf("mDNS: http://%s.local\n", MDNS_HOSTNAME);
  } else {
    Serial.println("mDNS no disponible");
  }

  server.on("/", HTTP_GET, handleStatus);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/usage", HTTP_POST, handleUsage);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("Servidor HTTP listo (POST /usage, GET /)");
}

void loop() {
  server.handleClient();

  static unsigned long lastFrame = 0;
  unsigned long now = millis();
  if (now - lastFrame >= 40) {   // ~25 fps para las animaciones
    lastFrame = now;
    render(now);
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi perdido, reconectando…");
    connectWiFi();
  }
}
