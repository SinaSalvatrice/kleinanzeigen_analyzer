# Kleinanzeigen Analyzer

Kleine Flutter-Desktop-App zum Identifizieren, Recherchieren, Bewerten und Formulieren von Kleinanzeigen-Angeboten.

## Aktueller Stand

- mehrere Produktfotos per Drag & Drop oder Dateiauswahl laden
- bekannte Fakten ergänzen: Hersteller, Modell, Kategorie, Zustand, Maße/Lieferumfang
- echte Bildanalyse über die OpenAI Responses API
- Websuche während derselben Analyse für Vergleichsangebote
- Preisansicht mit `Schnell`, `Realistisch` und `Inserat`
- Confidence-Wert für Identifikation + Preisbasis
- editierbarer Titel und Beschreibung
- Rechercheergebnis und verwendete Quellen im Datenmodell getrennt vom Listing

Die Analyse darf Unsicherheiten nicht als Fakten ausgeben. Aktive Angebotspreise werden ausdrücklich nicht automatisch als echte Verkaufspreise behandelt.

## Windows lokal starten

```powershell
git clone https://github.com/SinaSalvatrice/kleinanzeigen_analyzer.git
cd kleinanzeigen_analyzer
flutter create . --platforms=windows
flutter pub get
```

Vor dem Start muss ein OpenAI API-Key als Umgebungsvariable vorhanden sein.

Nur für das aktuelle PowerShell-Fenster:

```powershell
$env:OPENAI_API_KEY="DEIN_KEY"
flutter run -d windows
```

Oder dauerhaft für den Benutzer:

```powershell
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "DEIN_KEY", "User")
```

Danach ein neues Terminal öffnen und starten:

```powershell
flutter run -d windows
```

`flutter create . --platforms=windows` ergänzt nur die generierten Windows-Runner-Dateien des Flutter-Projekts.

## Analyse-Pipeline

1. Bis zu acht Fotos werden als Vision-Input analysiert.
2. Eigene Angaben wie Hersteller, Modell, Zustand und Lieferumfang werden als bekannte Fakten mitgegeben.
3. Das Modell recherchiert im Web nach möglichst passenden Vergleichsangeboten.
4. Quellen werden nach Vergleichbarkeit eingeordnet; bloße Angebotspreise werden vorsichtig behandelt.
5. Es werden drei Preisziele in EUR erzeugt: schneller Verkauf, realistischer Marktwert und sinnvoller Inserat-/VB-Preis.
6. Identifikation, Recherche-Zusammenfassung, Quellen und Confidence werden strukturiert zurückgegeben.
7. Daraus entstehen ein sachlicher Kleinanzeigen-Titel und eine Beschreibung ohne erfundene Eigenschaften.

## Noch offen

- Recherche-Zusammenfassung und Quellen vollständig in der UI anzeigen
- Fehlerdialoge statt ungefangener API-Fehler
- gespeicherte Artikel / Verlauf
- optional zusätzliche Preisquellen oder spezialisierte APIs

## Grundsatz

Recherche-Ergebnisse und Vermutungen dürfen nicht stillschweigend als sichere Tatsachen in das veröffentlichbare Listing übernommen werden.
