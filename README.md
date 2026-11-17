# RefCard 05 – Frontend (React + Vite)

Frontend der BusinessTrips-Applikation: Trips, Wishlist und Mitarbeitende mit Foto-Upload. Der Vite-Build
wird als nginx-Container auf AWS ECS (Fargate) ausgeliefert.

> **RefCard 05 – Full-Stack auf AWS.** Dieser Fork ist die Abgabe von Erik Oros und Sven Toye.
> Vorgehen und Nachweise für dieses Repo stehen in [`docs/RefCard05.md`](docs/RefCard05.md), die
> Gesamtübersicht (Architektur, RDS, S3, IAM) im
> [Backend-Repo](https://github.com/thelittleerik/RefCard-03-be-SpringBootBusinessTrips/blob/main/docs/RefCard05.md).

## Tech-Stack

- React 19, Vite 8, Bootstrap 5
- Vitest + Testing Library, ESLint
- nginx 1.27 (Laufzeit-Image)

## Lokal entwickeln

```bash
npm ci
npm run dev        # http://localhost:5173
```

Die App ruft das Backend unter `VITE_API_BASE_URL` auf (Standard in [`.env`](.env): `http://localhost:8080/`).
Das Backend muss dafür laufen – am einfachsten zusammen mit Datenbank und Storage über
[refcard-05-compose](https://github.com/thelittleerik/refcard-05-compose).

```bash
npm test           # Tests
npm run lint       # ESLint
npm run build      # Produktions-Build nach dist/
```

## Konfiguration

| Variable | Bedeutung |
| --- | --- |
| `VITE_API_BASE_URL` | Basis-URL des Backends, **mit** abschliessendem `/`. Der Code hängt den Pfad direkt an (`${baseUrl}v1/trips`). |
| `VITE_IMGS` | Unterordner von `public/images` für die Trip-Bilder (Standard `items`). |

Vite kompiliert beide Werte beim Build fest ins JavaScript-Bundle. Sie sind deshalb Build-Argumente des
Images und keine Laufzeit-Variablen des Containers. In der Pipeline kommt `VITE_API_BASE_URL` aus der
gleichnamigen Repository-Variable; fehlt sie, bricht der Image-Build mit einer Fehlermeldung ab.

## Projektstruktur

```
src/                           React-Applikation (Komponenten und Tests)
Dockerfile, nginx.conf         Multi-Stage-Build: Node baut, nginx liefert aus (/healthz, /version.json)
.github/workflows/deploy.yml   Pipeline: Test → Build → Image nach ECR → Deploy auf ECS → Smoke-Test
task-definition.json           ECS-Task-Definition (Fargate)
infra/                         AWS-Infrastruktur des Frontends anlegen und wieder löschen
scripts/                       Smoke-Test und Erneuern der Learner-Lab-Secrets
docs/RefCard05.md              Dokumentation der RefCard-05-Lösung
docs/exercises/                CI/CD-Übungen der Vorlage (EX-01 bis EX-03)
```

## Ausgangspunkt der Vorlage

Der ursprüngliche Stand der Vorlage ist der Tag `v1-start` im Upstream-Repo:

```bash
git clone --branch v1-start https://github.com/bbwlc/refcard-03-fe-react-vite.git
```
