# Intern PoC – Correspondence på Scaleway

**Statusdato: 30.10.2026**  
**Repository:** [Altinn/portability](https://github.com/Altinn/portability)  
**Ressursregion:** Warszawa (`pl-waw`, sone `pl-waw-1`)  
**Terraform state:** Object Storage i Paris (`fr-par`)

## Sammendrag

Den interne PoC-en har nå gått fra å verifisere grunnleggende infrastruktur og connectivity til å demonstrere at **Altinn Correspondence faktisk kan kjøre hos Scaleway**.

Correspondence er deployet som **Scaleway Serverless Container** med PostgreSQL, Redis, Object Storage, Secret Manager og Container Registry. En komplett funksjonell test med melding og vedlegg er gjennomført mot Altinn testmiljø, og data er verifisert både i PostgreSQL og Object Storage.

PoC-en er i tillegg utvidet med **Scaleway Kapsule / Kubernetes**. Det samme Correspondence-imaget kjører nå i Kubernetes på én worker-node og én pod. Kubernetes-runtime er eksponert gjennom en offentlig Scaleway Load Balancer, og `/health` er verifisert med HTTP 200.

**Status per 30.10.2026:**

- Serverless Container: **ende-til-ende funksjonelt verifisert**
- Kubernetes/Kapsule: **etablert og teknisk verifisert**
- Kubernetes full Correspondence-flyt: **gjenstår**
- Produksjonshardening, HA, DR og full operasjonell modell: **utenfor dagens PoC**

PoC-en viser dermed både **applikasjonsportabilitet** og at samme applikasjonsimage kan kjøres på mer enn én runtime hos Scaleway.

---

## 1. Formål og avgrensning

PoC-en skal undersøke:

- Om nødvendige infrastrukturtjenester for Correspondence kan etableres hos en europeisk skyleverandør med Terraform.
- Hvordan deployment og testing kan gjennomføres fra GitHub Actions.
- Hvilke Azure-avhengigheter som må tilpasses i applikasjon og driftsoppsett.
- Om Correspondence kan gjennomføre en funksjonell meldingsflyt på Scaleway.
- Om samme Correspondence-image kan kjøres på alternative runtime-plattformer, inkludert Kubernetes.
- Hvilke erfaringer som kan gjenbrukes ved testing av andre skyleverandører og Altinn-produkter.

PoC-en er fortsatt ikke en verifisering av produksjonskapasitet, høy tilgjengelighet, disaster recovery, full sikkerhetshardening eller komplett driftsmodell.

---

## 2. Hva PoC-en inneholder

| Komponent | Innhold | Status per 30.10.2026 |
| --- | --- | --- |
| Terraform | Gjenbrukbare Scaleway-moduler og miljøkonfigurasjon | Etablert og aktivt brukt |
| GitHub Actions | Validering, plan/apply/destroy, image-build, connectivity og PostgreSQL-bootstrap | Etablert |
| Remote state | `digdir-portability-tfstate` i Paris med S3-backend/locking | I bruk |
| VPC | Felles VPC med routing aktivert | Etablert i Warszawa |
| Private Network A | `10.20.0.0/24` for PostgreSQL, Redis og Serverless-baseline | I bruk |
| Private Network B | `10.21.0.0/22` for Kapsule | I bruk |
| PostgreSQL | Managed PostgreSQL 17, database `correspondence`, TLS og databaseprivilegier | I bruk av Correspondence |
| PostgreSQL connectivity | TLS, autentisering og `SELECT 1` | Verifisert |
| Redis | Managed Redis 8.6.6 med TLS og privat nettverk | I bruk og connectivity verifisert |
| Object Storage | Privat S3-kompatibel bucket for vedlegg | I bruk og funksjonelt verifisert |
| Secret Manager | Secrets opprettet gjennom Terraform | Etablert |
| Container Registry | Privat Registry i Warszawa | Correspondence- og støtte-images i bruk |
| Serverless Container | Correspondence API, public endpoint, port 2525 | **Ende-til-ende verifisert** |
| Kapsule | Managed Kubernetes cluster | **Etablert og Ready** |
| Kubernetes worker | `DEV1-M` | **1 node, Ready** |
| Correspondence pod | Samme image som Serverless Container | **1 pod, Running/Ready** |
| Kubernetes Service | `LoadBalancer`, port 80 → pod 2525 | **Verifisert** |
| Kubernetes public endpoint | Scaleway Load Balancer | `/health` returnerer HTTP 200 |
| Logging | Grafana/Cockpit viser applikasjonslogger fra Serverless | Verifisert på PoC-nivå |
| Kubernetes metrics | Begrenset detaljnivå i dagens Grafana-oppsett | Bør forbedres |
| Full Kubernetes-funksjonstest | Komplett melding/vedlegg via K8s-endepunkt | Gjenstår |

Vedleggsbucketen er:

```text
altinn-corr-internal-poc-attachments-8a731d6e
```

Regionalt S3-endepunkt:

```text
https://s3.pl-waw.scw.cloud
```

### Kodestruktur

```text
cloud-providers/scaleway/terraform/modules/
├── container-registry
├── kubernetes-application
├── kubernetes-cluster
├── object-storage
├── postgresql
├── private-network
├── redis
├── secret-manager
└── serverless-container

environments/internal-poc/correspondence/scaleway/terraform/

.github/workflows/

tools/ci/
tools/connectivity-probe/
tools/postgresql-bootstrap/
```

Credentials og passord leveres gjennom GitHub Secrets. Ikke-sensitive miljøinnstillinger leveres gjennom GitHub Variables og `SCW_TFVARS_JSON`.

---

## 3. Viktigste endringer siden status 19.10.2026

### 3.1 Correspondence-applikasjonen er deployet

Ved forrige status var infrastrukturen verifisert, men selve Correspondence-applikasjonen var ikke kjørt på Scaleway.

Dette er nå gjennomført.

Correspondence-imaget:

- bygges fra GitHub Actions
- lagres i Scaleway Container Registry i Warszawa
- kjører som Serverless Container
- bruker `ScalewayPoc`-konfigurasjon
- lytter på port `2525`
- kobler til PostgreSQL og Redis
- bruker Scaleway Object Storage for vedlegg

### 3.2 S3-støtte er implementert og testet

Correspondence er tilpasset slik at vedlegg kan lagres i Scaleway Object Storage i stedet for Azure Storage.

Den funksjonelle testen har dokumentert at:

- attachment-metadata lagres i PostgreSQL
- selve vedlegget lagres i Object Storage
- vedlegget kan vises/nedlastes gjennom Correspondence-flyten

Dette var en av de viktigste applikasjonstilpasningene i PoC-en.

### 3.3 Ende-til-ende-test er gjennomført

En testmelding med vedlegg er sendt til testbruker i Altinn testmiljø.

Følgende er verifisert:

```text
Testbruker / Altinn
        |
        v
Correspondence API på Scaleway
        |
        +--> PostgreSQL
        |
        +--> Redis
        |
        +--> Object Storage
```

Testen kan spores både i applikasjonslogger, PostgreSQL og Object Storage.

Dette betyr at PoC-en nå demonstrerer mer enn at infrastrukturen kan opprettes: **en faktisk Correspondence-brukerflyt er gjennomført med persistering hos Scaleway.**

### 3.4 Kubernetes er lagt til som PoC-utvidelse

PoC-en er utvidet med Scaleway Kapsule.

Serverless Container er beholdt som fungerende baseline. Kubernetes er lagt til parallelt slik at samme applikasjon kan testes på en alternativ runtime uten å rive ned den eksisterende løsningen.

Aktiv modell:

```text
Serverless Container
        +
Kubernetes/Kapsule
```

Kubernetes styres i Terraform med:

```text
enable_kubernetes = true
```

Den eldre variabelen:

```text
application_runtime
```

finnes fortsatt enkelte steder i repoet, men er ikke lenger den aktive runtime-bryteren.

### 3.5 Eget nettverk for Kubernetes

Første forsøk på å koble Kapsule til eksisterende `/24`-nett feilet fordi Private Network-subnettet var for lite.

Løsningen ble:

```text
VPC
├── Private Network A: 10.20.0.0/24
│   ├── PostgreSQL
│   ├── Redis
│   └── Serverless Container
│
└── Private Network B: 10.21.0.0/22
    └── Kapsule
        └── 1 x DEV1-M worker
            └── 1 x Correspondence pod
```

VPC-routing gjør at Kubernetes-poden kan nå PostgreSQL og Redis i det eksisterende nettverket.

### 3.6 Kubernetes er eksponert med Load Balancer

Correspondence i Kubernetes eksponeres gjennom:

```text
Internet
   |
   v
Scaleway Load Balancer
   |
   v
Kubernetes Service :80
   |
   v
Correspondence pod :2525
```

Verifisert Service:

```text
altinn-corr-internal-poc-api-public
```

Type:

```text
LoadBalancer
```

Portmapping:

```text
80/TCP -> 2525/TCP
```

Ved valideringen fikk Load Balancer adressen:

```text
151.115.42.149
```

### 3.7 Kubernetes health er verifisert

Test:

```text
http://151.115.42.149/health
```

returnerte:

```json
{
  "status": "Healthy",
  "message": "Environment properly configured and database is accessible"
}
```

med:

```text
HTTP 200 OK
```

Dette dokumenterer at trafikken når:

```text
Load Balancer
→ Kubernetes Service
→ Correspondence pod
```

Det er likevel ikke det samme som en komplett funksjonell Correspondence-test via Kubernetes.

### 3.8 Startup-probe måtte innføres

Den første Kubernetes-deploymenten fikk gjentatte container-restarter.

Årsaken var at liveness-proben startet før Correspondence hadde rukket å lytte på port `2525`.

Løsningen var å legge til:

```text
startup_probe
```

før readiness/liveness får effekt.

Etter denne endringen ble poden stabil og Ready.

### 3.9 Kapasitet på Kubernetes-node

Under første utrulling ble det observert:

```text
0/1 nodes are available: 1 Insufficient memory
```

PoC-en kjører fortsatt med:

```text
1 x DEV1-M worker
1 x Correspondence pod
```

Podens Correspondence-konfigurasjon bruker omtrent:

```text
CPU request:    500m
CPU limit:      1100m
Memory request: 1 GiB
Memory limit:   2 GiB
```

Dette er tilstrekkelig for dagens PoC, men gir liten margin dersom flere workloads eller replicas legges til.

---

## 4. Deployment-modell

GitHub Actions er fortsatt den primære deployment-mekanismen.

### Terraform-workflow

Tilgjengelige manuelle actions:

| Action | Formål |
| --- | --- |
| `plan` | Full Terraform-plan |
| `apply` | Lager ny plan og anvender den i samme workflow-kjøring |
| `apply-kubernetes-cluster` | Første etablering av Kubernetes-nett, Kapsule og node pool |
| `destroy` | Planlegger og river ned miljøet med bekreftelsesverdi |

Kubernetes krever et todelt førstegangsforløp:

```text
1. apply-kubernetes-cluster
2. normal plan
3. normal apply
```

`-target` brukes kun for å bootstrappe Kubernetes-clusteret. Normal drift skal benytte full Terraform plan/apply.

### Image-build

Build-workflow:

```text
Scaleway Build Correspondence
```

bygger og pusher Correspondence-imaget til Scaleway Registry.

En image-build oppdaterer ikke automatisk den kjørende workloaden. Ny image-referanse må settes i Terraform-konfigurasjonen og deployes med `apply`.

---

## 5. Dokumenterte testresultater

### 5.1 Infrastruktur-connectivity

Connectivity-proben i Warszawa har verifisert:

```json
{
  "postgresql": {
    "status": "ok"
  },
  "redis": {
    "status": "ok"
  },
  "object_storage": {
    "status": "ok"
  }
}
```

| Tjeneste | Verifisert operasjon |
| --- | --- |
| PostgreSQL | TLS, autentisering og `SELECT 1` |
| Redis | TLS, autentisering, ping, skriving, lesing og sletting |
| Object Storage | Autentisering, skriving, lesing og sletting av testobjekt |

### 5.2 Serverless Container

Verifisert:

- Correspondence-image starter og kjører.
- Public HTTPS-endepunkt fungerer.
- Private backend-tjenester nås.
- Applikasjonslogger vises i Grafana.
- En faktisk Correspondence-melding er prosessert.
- Vedlegg er lagret i Scaleway Object Storage.
- Metadata er lagret i PostgreSQL.
- Ende-til-ende-flyten mot Altinn testmiljø fungerer.

**Serverless Container er dermed funksjonelt verifisert på PoC-nivå.**

### 5.3 Kubernetes

Verifisert:

- Kapsule cluster er opprettet.
- Worker-node er Ready.
- Privat Registry-image kan hentes med `imagePullSecret`.
- Correspondence-pod er `Running` og `Ready 1/1`.
- LoadBalancer Service er etablert.
- Service har endpoint mot poden.
- Offentlig `/health` returnerer HTTP 200.
- Applikasjonen starter med samme image og konfigurasjonsmodell som Serverless Container.

Ikke fullstendig verifisert ennå:

- komplett Correspondence-melding gjennom Kubernetes-endepunktet
- vedleggsflyt via Kubernetes
- Redis-bruk i en full K8s-funksjonstest
- TT02-integrasjoner gjennom K8s-endepunktet
- bakgrunnsjobber ved parallell drift
- flere replicas/noder
- autoskalering

---

## 6. Observability

### Serverless Container

Grafana/Cockpit har vist applikasjonslogger fra Correspondence under den funksjonelle testen.

Logger har blant annet vist aktivitet relatert til:

```text
Enqueuing Correspondence
notification processing
delivery status
```

Dette dokumenterer faktisk runtime-aktivitet og ikke bare at containeren står som `Ready`.

### Kubernetes

Kubernetes-clusteret vises i Scaleway/Cockpit, men dagens Grafana-oppsett gir begrenset detaljert data for worker/pod.

Det er behov for bedre Kubernetes-observability dersom PoC-en skal utvides.

Aktuelle metrics:

```text
Node CPU
Node memory
Pod CPU
Pod memory
Pod restarts
Readiness
CPU throttling
Network traffic
```

En mulig videreføring er å sende Kubernetes-metrikker til Cockpit/Grafana med eksempelvis Grafana Alloy eller tilsvarende agent.

Dette er ikke nødvendig for å dokumentere dagens grunnleggende portabilitet, men vil være viktig for operasjonell sammenligning mellom runtime-alternativene.

---

## 7. Azure-avhengigheter og tilpasninger

Statusen har endret seg vesentlig siden 19. oktober.

| Azure-funksjon | Scaleway-retning | Status |
| --- | --- | --- |
| Azure Blob Storage | Scaleway Object Storage / S3 | **Implementert og funksjonelt testet for vedlegg** |
| Azure Files | Eventuelt separat objektlager eller annen løsning | Ikke avklart for eventuell migreringsfunksjon |
| Key Vault | Terraform-injiserte secrets / Secret Manager | PoC-løsning etablert |
| Managed Identity | Scaleway IAM/API keys og eksplisitte credentials | PoC-løsning etablert for nødvendige tjenester |
| Application Insights | Cockpit/Grafana/OpenTelemetry-retning | PoC-logging finnes; produksjonsmonitorering gjenstår |
| APIM / Event Grid | Direkte/testintegrasjoner mot eksisterende miljø | PoC-flyt fungerer, men full arkitekturerstatning er ikke et mål i denne fasen |
| Maskinporten JWK-rotasjon | Rotasjon deaktivert i PoC-profil | Produksjonsløsning gjenstår |
| Azure storage-provisionering | NoOp i ScalewayPoc | Tilpasset for PoC |

PoC-en viser at det er mulig å redusere de direkte Azure-avhengighetene nok til å kjøre Correspondence hos Scaleway, men det betyr ikke at alle produksjonsrelaterte Azure-integrasjoner er erstattet.

---

## 8. Viktige erfaringer

### Infrastruktur

- Tjenestetilgjengelighet og versjoner må sjekkes før regionvalg låses.
- Samme provider tilbyr ikke nødvendigvis alle tjenester i alle regioner.
- Managed Kubernetes kan ha strengere nettverkskrav enn andre workloads.
- Kapsule krevde større subnett enn det eksisterende `/24`-nettet.

### Terraform

- Parallelldrift av Serverless og Kubernetes er enklere og tryggere for PoC enn å gjøre runtime til en gjensidig eksklusiv bryter.
- Kubernetes-provider krever at Kapsule API eksisterer før Kubernetes-ressursene kan opprettes, derfor cluster-first deployment.
- `-target` bør kun brukes ved bootstrap/recovery.
- Controller-genererte Kubernetes Service-annotations må håndteres slik at Terraform ikke skaper unødvendig drift.
- `application_runtime` er nå teknisk gjeld og bør fjernes til fordel for den faktiske `enable_kubernetes`-modellen.

### Applikasjon

- Portering krevde både Terraform og kodeendringer.
- S3-laget var en sentral del av applikasjonsporteringen.
- Health-probes må ta høyde for faktisk oppstartstid.
- Samme container-image kan brukes i både Serverless Container og Kubernetes.

### Operasjon

- Én node og én pod er tilstrekkelig for funksjonell PoC, men ikke for produksjons-HA.
- Parallelldrift mot samme database/Redis må vurderes nøye dersom begge runtime-instansene kjører consumers eller bakgrunnsjobber.
- `/health` er nyttig for teknisk runtime-verifisering, men en komplett funksjonell test er sterkere bevis på portabilitet.

---

## 9. Kjente begrensninger

Dagens PoC har bevisste forenklinger:

- Én Kubernetes worker.
- Én Correspondence pod.
- Ingen Kubernetes runtime-HA.
- Ingen autoskalering i Kapsule.
- Kubernetes-endepunktet bruker HTTP direkte mot Load Balancer.
- Ingen DNS/TLS/Ingress foran Kubernetes-endepunktet.
- Worker-noden har offentlig IP.
- Object Storage benytter regionalt offentlig S3-endepunkt.
- Kubernetes-observability er begrenset.
- `wait_for_rollout = false` står fortsatt etter feilsøkingsfasen.
- Serverless og Kubernetes deler applikasjonskonfigurasjon/secrets.
- `GeneralSettings__CorrespondenceBaseUrl` er ikke runtime-spesifikk.
- Full ende-til-ende-test via Kubernetes er ikke gjennomført.
- Produksjons-HA, backup/restore, DR, lasttest og SLO-er er ikke del av dagens validering.

---

## 10. Gjenstående arbeid i anbefalt rekkefølge

### Høy prioritet

- [ ] Kjør komplett Correspondence-flyt via Kubernetes-endepunktet.
- [ ] Verifiser melding, vedlegg, PostgreSQL, Redis og TT02-integrasjoner gjennom Kubernetes-runtime.
- [ ] Avklar `GeneralSettings__CorrespondenceBaseUrl` for Kubernetes-testen.
- [ ] Kontrollere at parallelle Serverless/Kubernetes-instanser ikke gir uønsket dobbel prosessering av bakgrunnsjobber.
- [ ] Sett `wait_for_rollout = true` igjen når Kubernetes-oppstarten er stabil.

### Repo og deployment

- [ ] Fjern legacy `application_runtime` og oppdater README/tfvars/workflow-tekst til `enable_kubernetes`.
- [ ] Sikre at `.terraform.lock.hcl` inneholder både Scaleway- og Kubernetes-provider.
- [ ] Gjør `POC_REGISTRY_PULL_SECRET`-validering betinget av faktisk Kubernetes-behov.
- [ ] Rydd eller oppdater legacy connectivity-workflow som fortsatt har Paris-spesifikke antakelser.
- [ ] Oppdater deployment-dokumentasjonen slik at den gjenspeiler faktisk parallelldrift.

### Observability

- [ ] Forbedre Kubernetes metrics i Cockpit/Grafana.
- [ ] Dokumenter CPU/minne for worker og Correspondence-pod.
- [ ] Etabler tydelig logg-/metric-sammenligning mellom Serverless og Kubernetes dersom dette skal brukes i runtime-vurderingen.

### Videre portabilitetstesting

- [ ] Test kopiering av representativ PostgreSQL-data fra Azure til Scaleway.
- [ ] Test kopiering av representativ Blob-data fra Azure Storage til Scaleway Object Storage.
- [ ] Mål overføringstid, konsistens, egresskost og mulig cutover/nedetid.
- [ ] Test et nytt Altinn-produkt for å vurdere hvor gjenbrukbar Terraform-/portabilitetsmodellen er.

---

## 11. Status på PoC-målene

| Mål | Status |
| --- | --- |
| Etablere Scaleway med Terraform | ✅ Oppnådd |
| Deploy fra GitHub Actions | ✅ Oppnådd |
| Privat PostgreSQL | ✅ Oppnådd |
| Privat Redis | ✅ Oppnådd |
| S3-kompatibel vedleggslagring | ✅ Oppnådd |
| Kjørende Correspondence hos Scaleway | ✅ Oppnådd |
| Komplett melding med vedlegg | ✅ Oppnådd på Serverless |
| Persistering i PostgreSQL/Object Storage | ✅ Oppnådd |
| Runtime-logging | ✅ Oppnådd på PoC-nivå |
| Kjør Correspondence på Kubernetes | ✅ Oppnådd |
| Public Kubernetes Load Balancer | ✅ Oppnådd |
| Kubernetes health-test | ✅ Oppnådd |
| Full Kubernetes Correspondence-flyt | ⏳ Gjenstår |
| Kubernetes HA/autoskalering | ⏳ Ikke testet |
| Produksjonsmonitorering/SLO | ⏳ Ikke del av dagens PoC |
| Backup/restore/DR | ⏳ Ikke del av dagens PoC |
| Reell dataflytting fra Azure | ⏳ Neste utvidelse |
| Gjenbruk på annet Altinn-produkt | ⏳ Neste utvidelse |

---

## 12. Neste milepæl

**Gjennomføre den samme komplette Correspondence-funksjonstesten gjennom Kubernetes som allerede er verifisert gjennom Serverless Container.**

Det innebærer å dokumentere:

```text
Altinn test / testbruker
        |
        v
Scaleway Load Balancer
        |
        v
Kubernetes Service
        |
        v
Correspondence pod
        |
        +--> PostgreSQL
        +--> Redis
        +--> Object Storage
```

Når dette er gjennomført, har PoC-en dokumentert at **samme Correspondence-applikasjon og image kan kjøre funksjonelt på to forskjellige runtime-modeller hos Scaleway**, samtidig som de samme managed data-tjenestene gjenbrukes.

Et naturlig neste modenhetsnivå er deretter å teste **reell dataflytting fra Azure** og om portabilitetsmønsteret kan gjenbrukes for **flere Altinn-produkter**.
