# Apple Watch Body Battery

Private Apple-Watch-App, die aus Apple-Health-Daten einen Body-Battery-ähnlichen Energie-Score von 0–100 berechnet und ihn als Watch-Komplikation anzeigt.

## Enthalten

- native watchOS-App mit SwiftUI
- HealthKit: Schlaf, Schlafstadien, HRV (SDNN), Ruhepuls, aktive Energie und Trainingsminuten
- persönliche 28-Tage-Baseline für HRV und Ruhepuls
- Score 0–100 mit Erholung (`+`) und Belastung (`−`)
- WidgetKit-Komplikation für Circular, Rectangular, Inline und Corner
- lokaler Datenaustausch zwischen App und Komplikation über App Group
- Widget-Timeline wird nach einer neuen Berechnung aktualisiert
- keine Cloud und kein eigener Server

## Projekt erzeugen

Das Repository verwendet **XcodeGen**, damit die Xcode-Projektdatei reproduzierbar bleibt.

```bash
brew install xcodegen
git clone https://github.com/frechdax/applewatchbodybattery.git
cd applewatchbodybattery
xcodegen generate
open AppleWatchBodyBattery.xcodeproj
```

## Signing / Installation auf deiner eigenen Apple Watch

1. Öffne `AppleWatchBodyBattery.xcodeproj` in Xcode.
2. Wähle beim Target **BodyBatteryWatch** unter `Signing & Capabilities` dein Team aus.
3. Wähle beim Target **BodyBatteryComplication** dasselbe Team aus.
4. Prüfe, dass die App Group bei beiden Targets identisch ist: `group.com.frechdax.applewatchbodybattery`.
5. HealthKit muss beim Watch-App-Target aktiv sein.
6. Wähle deine gekoppelte Apple Watch als Run Destination.
7. Drücke **Run**.
8. Beim ersten Start Health-Zugriff erlauben.
9. Danach kannst du **Body Battery** in der Zifferblatt-Bearbeitung als Komplikation auswählen.

> App Groups können je nach Signing-/Developer-Konfiguration zusätzliche Apple-Developer-Capabilities erfordern. Der Identifier kann in `Shared/AppConstants.swift` und beiden Entitlements-Dateien geändert werden.

## Score

Die erste Version kombiniert Schlafdauer und Schlafstadien als Aufladung, HRV und Ruhepuls relativ zu deiner persönlichen 28-Tage-Baseline sowie aktive Energie und Trainingsminuten als Tagesbelastung.

Der Algorithmus befindet sich transparent in `WatchApp/BodyBatteryScoreEngine.swift`.

## Hinweis

Das ist ein persönlicher Wellness-/Fitnessindikator und kein medizinisches Messinstrument oder Diagnosewert. Der Score ist nicht Garmins proprietäre Body-Battery-Berechnung.

## Nächste Ausbaustufen

- HealthKit-Observer für automatische Aktualisierung
- stündlicher Tagesverlauf
- 7-/28-Tage-Trend
- stärkere individuelle Kalibrierung
- Stressindikator aus Herzfrequenz und HRV
- optionale iPhone-Begleitansicht
