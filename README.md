# Kleinanzeigen Analyzer

Kleine Flutter-Desktop-App zum Identifizieren, Recherchieren, Bewerten und Formulieren von Kleinanzeigen-Angeboten.

## MVP

- mehrere Produktfotos per Drag & Drop oder Dateiauswahl laden
- bekannte Fakten ergänzen: Hersteller, Modell, Kategorie, Zustand, Maße/Lieferumfang
- Analyse-Workflow als eigener Service vorbereitet
- Preisansicht mit `Schnell`, `Realistisch` und `Inserat`
- editierbarer Titel und Beschreibung
- Recherchebereich strikt vom fertigen Listing getrennt

> Der aktuelle `AnalyzerService` ist bewusst ein Stub. Er erzeugt noch keine echte Webrecherche und verwendet Platzhalterpreise. Die UI und Datenstruktur sind so angelegt, dass Bildanalyse und Vergleichspreis-Recherche als nächster Schritt angeschlossen werden können.

## Windows lokal starten

```powershell
git clone https://github.com/SinaSalvatrice/kleinanzeigen_analyzer.git
cd kleinanzeigen_analyzer
flutter create . --platforms=windows
flutter pub get
flutter run -d windows
```

`flutter create . --platforms=windows` ergänzt nur die noch fehlenden generierten Windows-Runner-Dateien des Flutter-Projekts.

## Geplante Analyse-Pipeline

1. Fotos analysieren und sichtbare Hersteller-/Modellhinweise erkennen.
2. Unsichere Identifikation als Hypothese kennzeichnen, nicht als Listing-Fakt übernehmen.
3. Webrecherche nach möglichst identischen oder vergleichbaren Angeboten.
4. Vergleichsdaten nach Quelle, Zustand, Vollständigkeit und Aktualität gewichten.
5. Drei Preisziele berechnen: schneller Verkauf, realistischer Marktwert, Inserat/VB.
6. Quellen und Confidence separat anzeigen.
7. Erst aus bestätigten Fakten Titel und Beschreibung erzeugen.

## Grundsatz

Recherche-Ergebnisse und Vermutungen dürfen nicht stillschweigend als sichere Tatsachen in das veröffentlichbare Listing übernommen werden.
