# Datenschutzerklärung / Privacy Policy

**PeakMoto** — Kostenlose, quelloffene Motorrad-Navigation
Version: 1.0 · Stand: 2026-04-12

---

## 🇩🇪 Deutsch

### Grundsatz
PeakMoto ist eine **kostenlose und quelloffene Motorrad-Navigations-App**. Dein Datenschutz ist uns wichtig — wir sammeln **so wenig wie möglich**, und alles was wir sammeln ist **anonym**.

### Was wir NICHT tun
- ❌ **Kein Account**, keine Registrierung, keine E-Mail nötig
- ❌ **Kein Tracking** — keine Werbe-IDs, keine Cookies, keine Fingerprints
- ❌ **Kein Verkauf von Daten** — niemals, auch nicht anonymisiert
- ❌ **Keine Analytics** — kein Google Analytics, Firebase, Crashlytics etc.
- ❌ **Keine Drittanbieter-SDKs** die deine Daten lesen

### Was wir lokal verarbeiten (bleibt auf deinem Gerät)
- **Dein Standort (GPS)** — wird nur für Navigation verwendet, nicht gespeichert, nicht übertragen
- **Gespeicherte Routen** — liegen als JSON-Datei lokal im App-Speicher, nur du siehst sie
- **Karten-Cache** — heruntergeladene Kartenkacheln für Offline-Nutzung
- **Einstellungen** — Theme, Einheiten usw.

### Was an unseren Server geht
- **Routing** (`routing.peakmoto.app`): Start- und Zielkoordinaten werden gesendet, um die Route zu berechnen. **Nichts wird gespeichert**, keine Logs mit deinen Koordinaten.
- **Suche** (`photon.peakmoto.app`): Deine Suchanfrage (z.B. "Winterberg") wird gesendet, um Ergebnisse zu liefern. **Nichts wird gespeichert**.
- **Offline-Karten** (`tiles.peakmoto.app`): Kartenkacheln werden angefragt, Standard HTTP-Logs existieren (IP, User-Agent, ~7 Tage) für Abuse-Schutz.

### Was an Drittanbieter geht
- **CartoDB** (`a.basemaps.cartocdn.com`): Die Karten-Kacheln in der Standard-Ansicht kommen von CartoDB. CartoDB sieht deine IP-Adresse. [CartoDB Privacy](https://carto.com/privacy/)

### Feedback-Funktion (optional)
Wenn du am Ende einer Route auf **„Senden"** tippst, übertragen wir an `feedback.peakmoto.app`:
- Start- und Zielkoordinaten (Rundungsgrad: ~5 Nachkommastellen)
- Das verwendete Routing-Profil (z.B. `motorcycle_curvy`)
- Streckenlänge, Fahrzeit, Anzahl Abbiegungen
- Deine Sternebewertung (1-5)
- Dein optionaler Kommentar-Text
- App-Version

**Nicht übertragen werden:** Dein Name, deine Geräte-ID, deine IP-Adresse (der Server speichert nur HTTP-Logs mit IP für 7 Tage für Abuse-Schutz, diese werden NICHT mit den Feedback-Daten verknüpft).

Die Feedback-Daten landen **anonym** in einem Telegram-Chat des Entwicklers, der sie für die Verbesserung des Routings auswertet. Sie werden nicht weitergegeben und nicht verkauft.

Wenn du **„Überspringen"** tippst, wird **nichts** gesendet.

### Deine Rechte (DSGVO)
- **Löschung** — Da alle Daten anonym sind, können wir sie dir nicht zuordnen. Es gibt nichts, was wir löschen könnten.
- **Auskunft** — Was wir speichern, steht oben in dieser Erklärung.
- **Widerspruch** — Einfach keine Routen-Feedbacks absenden, dann landet nichts bei uns.

### Kontakt
Bei Fragen zum Datenschutz: Öffne ein Issue auf [github.com/phanes-io/peakmoto](https://github.com/phanes-io/peakmoto/issues) oder schreibe an die im Repository hinterlegte E-Mail.

### Änderungen
Diese Datenschutzerklärung kann sich ändern. Wesentliche Änderungen werden im Changelog der App-Updates dokumentiert.

---

## 🇬🇧 English

### Principle
PeakMoto is a **free and open-source motorcycle navigation app**. Your privacy matters — we collect **as little as possible**, and everything we collect is **anonymous**.

### What we DON'T do
- ❌ **No account**, no registration, no email required
- ❌ **No tracking** — no ad IDs, no cookies, no fingerprints
- ❌ **No selling of data** — never, not even anonymized
- ❌ **No analytics** — no Google Analytics, Firebase, Crashlytics etc.
- ❌ **No third-party SDKs** that read your data

### What stays on your device
- **Your GPS location** — used only for navigation, not stored, not transmitted
- **Saved routes** — stored as a local JSON file, only you see them
- **Map cache** — tiles for offline use
- **Preferences** — theme, units, etc.

### What goes to our server
- **Routing** (`routing.peakmoto.app`): Start and destination coordinates are sent to calculate the route. **Nothing is stored**, no logs with your coordinates.
- **Search** (`photon.peakmoto.app`): Your search query is sent to return results. **Nothing is stored**.
- **Offline maps** (`tiles.peakmoto.app`): Tile requests hit our server, standard HTTP logs exist (IP, User-Agent, ~7 days) for abuse protection.

### What goes to third parties
- **CartoDB** (`a.basemaps.cartocdn.com`): Default map tiles come from CartoDB. CartoDB sees your IP address. [CartoDB Privacy](https://carto.com/privacy/)

### Feedback feature (optional)
If you tap **"Send"** at the end of a route, we transmit to `feedback.peakmoto.app`:
- Start and destination coordinates
- The routing profile used (e.g. `motorcycle_curvy`)
- Distance, duration, turn count
- Your star rating (1-5)
- Your optional comment text
- App version

**Not transmitted:** Your name, device ID, or user identity. The server keeps HTTP access logs with IP for 7 days for abuse protection, not linked to feedback content.

The feedback data is sent **anonymously** to a developer Telegram chat and evaluated to improve routing. Not shared, not sold.

If you tap **"Skip"**, **nothing** is sent.

### Your rights (GDPR)
- **Deletion** — Since all data is anonymous, we cannot link it back to you. There is nothing for us to delete.
- **Access** — What we store is listed above.
- **Objection** — Simply don't submit feedback, then nothing reaches us.

### Contact
Privacy questions: Open an issue at [github.com/phanes-io/peakmoto](https://github.com/phanes-io/peakmoto/issues).

### Changes
This privacy policy may change. Significant changes will be documented in app update changelogs.
