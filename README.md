# Licentra

## Inhaltsverzeichnis

1. [Projektübersicht](#projektübersicht)
2. [Systemvoraussetzungen & Abhängigkeiten](#systemvoraussetzungen--abhängigkeiten)
3. [Projektstruktur](#projektstruktur)
4. [Installation & Setup](#installation--setup)
    - [Entwicklungsumgebung](#entwicklungsumgebung)
    - [Testumgebung](#testumgebung)
    - [Produktivumgebung](#produktivumgebung)
5. [Docker & Microservice-Architektur](#docker--microservice-architektur)
6. [Konfiguration & Anpassung](#konfiguration--anpassung)
7. [Typische Entwicklungsaufgaben](#typische-entwicklungsaufgaben)
8. [Weitere Ressourcen](#weitere-ressourcen)
9. [Vorteile dieser Dokumentation](#vorteile-dieser-dokumentation)

---

## Projektübersicht

Licentra ist ein modulares System zur Verwaltung von Lizenzen und Zugriffsrechten. Es bietet eine zentrale Plattform für das Management, die Überwachung und die Automatisierung von Lizenzprozessen.  
**Hauptfunktionen:**
- Verwaltung und Zuweisung von Lizenzen
- Benutzer- und Rollenmanagement
- Automatisierte Prüfungen und Benachrichtigungen
- REST-API für Integration mit Drittsystemen
- Web-Frontend zur Administration

---

## Systemvoraussetzungen & Abhängigkeiten

- **Betriebssystem:** Linux, macOS, Windows (mit Docker)
- **Docker** (mind. v20.10)
- **Docker Compose** (mind. v2.0)
- **Git** (für Quellcodeverwaltung)
- **Optional:** Ruby (für lokale Entwicklung ohne Docker)

**Abhängigkeiten (Auszug):**
- Backend: Ruby, Sinatra, Sequel, Rake
- Frontend: HTML/ERB, Bootstrap
- Datenbank: PostgreSQL
- Test: RSpec

---

## Projektstruktur

```
Licentra-main/
│
├── backend/                # Ruby-Backend (API, Business Logic)
│   ├── config/             # Umgebungs- und DB-Konfiguration
│   ├── db/                 # Migrationen, Seeds
│   ├── spec/               # Tests
│   └── ...                 
├── frontend/               # Web-Frontend (Views, Assets)
│   ├── views/              # HTML/ERB-Templates
│   └── ...
├── docker-compose.yml      # Basis-Docker-Konfiguration
├── docker-compose.prod.yml # Produktionserweiterungen
├── .env.example           # Beispiel-Umgebungsvariablen
├── .github/
│   └── workflows/          # CI/CD Workflows (z.B. deploy.yml)
└── README.md
```

---

## Installation & Setup

### Entwicklungsumgebung

1. **Repository klonen**
   ```sh
   git clone https://github.com/DeinRepo/licentra.git
   cd licentra
   ```

2. **Umgebungsvariablen anpassen**
   - `.env.example` kopieren und als `.env` anpassen.

3. **Docker-Container starten**
   ```sh
   docker compose up --build
   ```

4. **Backend-Tests ausführen**
   ```sh
   docker compose run --rm backend bundle exec rake spec
   ```

### Testumgebung

- Analog zur Entwicklungsumgebung, aber mit `RACK_ENV=test` in der `.env` und ggf. eigenen Testdaten.
- Tests laufen automatisiert via GitHub Actions (`.github/workflows/deploy.yml`).

### Produktivumgebung

- Deployment via GitHub Actions und SSH (siehe [deploy.yml](.github/workflows/deploy.yml)).
- Produktionsspezifische Einstellungen in `docker-compose.prod.yml` und `.env`.
- Beispiel-Deploy-Befehl (wird im Workflow ausgeführt):
   ```sh
   docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile proxy up -d --build --force-recreate
   ```

---

## Docker & Microservice-Architektur

- **Backend** und **Frontend** laufen in separaten Docker-Containern.
- **PostgreSQL** als persistente Datenbank (eigener Container).
- **Docker Compose** orchestriert alle Services.
- **Profile** in Compose ermöglichen flexible Umgebungen (z.B. mit/ohne Proxy).
- **Vorteile:** Isolierte Services, einfache Skalierung, reproduzierbare Setups.

**Beispiel:**
```yaml
services:
  backend:
    build: ./backend
    env_file: .env
    depends_on: [db]
  frontend:
    build: ./frontend
    depends_on: [backend]
  db:
    image: postgres:15
    volumes:
      - db_data:/var/lib/postgresql/data
volumes:
  db_data:
```

---

## Konfiguration & Anpassung

- **Umgebungsvariablen:**  
  Alle zentralen Einstellungen werden über die `.env`-Datei gesteuert (z.B. Datenbankzugang, Ports, Secrets).  
  Beispiel:
  ```
  DB_USER=licentra
  DB_PASSWORD=geheim
  ```

- **Docker Compose Profile:**  
  Über Profile wie `proxy` können optionale Services aktiviert werden.  
  Beispiel:
  ```
  docker compose --profile proxy up
  ```

- **Produktionsspezifische Anpassungen:**  
  In `docker-compose.prod.yml` können Ressourcen, Netzwerke und Umgebungsvariablen für den Produktivbetrieb überschrieben werden.

---

## Typische Entwicklungsaufgaben

- **Neues Feature entwickeln**
  1. Branch erstellen:  
     `git checkout -b feature/neues-feature`
  2. Code im passenden Service (z.B. `backend/`) anpassen.
  3. Tests ergänzen:  
     `docker compose run --rm backend bundle exec rake spec`
  4. Pull Request erstellen.

- **Fehlerbehebung**
  1. Fehler lokalisieren (Logs: `docker compose logs backend`).
  2. Fix implementieren und testen.
  3. Dokumentation ggf. aktualisieren.

- **Migrationen ausführen**
  ```sh
  docker compose run --rm backend bundle exec sequel -m db/migrations postgres://user:pass@db/licentra
  ```

- **Datenbankzugriff**
  ```sh
  docker compose exec db psql -U <user> <datenbank>
  ```

---

## Weitere Ressourcen

- [Deployment-Workflow](.github/workflows/deploy.yml)
- [Backend-Konfiguration](backend/config/environment.rb)
- [Frontend-Views](frontend/views/)
- [Datenbank-Migrationen](backend/db/migrations/)

---

## Vorteile dieser Dokumentation

- **Beschleunigte Einarbeitung:** Neue Entwickler werden in wenigen Stunden produktiv.
- **Reduzierter Schulungsaufwand:** Weniger persönliche Einweisungen nötig.
- **Selbstständigere Problemlösung:** Entwickler finden Antworten in der Doku.
- **Zuverlässigere Konfiguration:** Klare Anleitungen verhindern Fehler.
- **Verbesserte Systemwartung:** Alle Infos zentral und aktuell.

---

Für Fragen und Verbesserungen: Bitte Issues oder Pull Requests im Repository anlegen.
