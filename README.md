# Kleinanzeigen Analyzer

Kleine Flutter-Desktop-App zum Identifizieren, Recherchieren, Bewerten und Formulieren von Kleinanzeigen-Angeboten.

## Aktueller Stand

- mehrere Produktfotos per Drag & Drop oder Dateiauswahl laden
- bekannte Fakten ergänzen: Hersteller, Modell, Kategorie, Zustand, Maße/Lieferumfang
- OpenAI API-Key direkt in der App hinterlegen
- API-Key lokal über `flutter_secure_storage` speichern
- Verbindungstest direkt im API-Dialog
- Zeilenumbrüche und Leerzeichen beim Einfügen des Keys automatisch entfernen
- echte Bildanalyse über die OpenAI Responses API
- Websuche während derselben Analyse für Vergleichsangebote
- Preisansicht mit `Schnell`, `Realistisch` und `Inserat`
- Confidence-Wert für Identifikation + Preisbasis
- editierbarer Titel und Beschreibung mit Kopierfunktion
- Recherche-Zusammenfassung und verwendete Quellen direkt in der UI

Die Analyse darf Unsicherheiten nicht als Fakten ausgeben. Aktive Angebotspreise werden ausdrücklich nicht automatisch als echte Verkaufspreise behandelt.

## Windows lokal starten

```powershell
git clone https://github.com/SinaSalvatrice/kleinanzeigen_analyzer.git
cd kleinanzeigen_analyzer
flutter create . --platforms=windows
flutter pub get
flutter run -d windows
```

`flutter create . --platforms=windows` ergänzt die generierten Windows-Runner-Dateien des Flutter-Projekts.

### API-Key

Nach dem Start oben rechts auf `API-Key` klicken.

Dort kann der OpenAI API-Key:

- eingefügt
- automatisch bereinigt
- gespeichert
- getestet
- wieder entfernt oder ersetzt werden

Der Key wird nicht im Repository gespeichert. Eine bestehende Windows-Umgebungsvariable `OPENAI_API_KEY` wird weiterhin als Fallback unterstützt.

## Analyse-Pipeline

1. Bis zu acht Fotos werden als Vision-Input analysiert.
2. Eigene Angaben wie Hersteller, Modell, Zustand und Lieferumfang werden als bekannte Fakten mitgegeben.
3. Das Modell recherchiert im Web nach möglichst passenden Vergleichsangeboten.
4. Quellen werden nach Vergleichbarkeit eingeordnet; bloße Angebotspreise werden vorsichtig behandelt.
5. Es werden drei Preisziele in EUR erzeugt: schneller Verkauf, realistischer Marktwert und sinnvoller Inserat-/VB-Preis.
6. Identifikation, Recherche-Zusammenfassung, Quellen und Confidence werden strukturiert zurückgegeben.
7. Daraus entstehen ein sachlicher Kleinanzeigen-Titel und eine Beschreibung ohne erfundene Eigenschaften.

## Noch offen

- Analysefortschritt feiner aufschlüsseln
- gespeicherte Artikel / Verlauf
- Korrektur einer Identifikation mit anschließender Neurecherche
- Hinweise auf fehlende Fotos, Typenschilder oder wichtige Produktdetails
- optional zusätzliche Preisquellen oder spezialisierte APIs

## Grundsatz

Recherche-Ergebnisse und Vermutungen dürfen nicht stillschweigend als sichere Tatsachen in das veröffentlichbare Listing übernommen werden.
