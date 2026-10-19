# Intern PoC – Correspondence på Scaleway

**Statusdato: 19.10.2026**  
**Repository:** [Altinn/portability](https://github.com/Altinn/portability)  
**Ressursregion:** Warszawa (`pl-waw`, sone `pl-waw-1`)  
**Terraform state:** Object Storage i Paris (`fr-par`)

## Sammendrag

Den interne PoC-en har etablert en Terraform-basert grunnplattform for Correspondence hos Scaleway. Infrastrukturen deployes fra GitHub Actions, og en egen testcontainer har bekreftet tilgang til PostgreSQL, Redis og Object Storage.

**Grunnplattform og kommunikasjon mellom tjenestene er verifisert. Selve Correspondence-applikasjonen er ennå ikke verifisert på Scaleway.** Applikasjonstilpasning, databasemigreringer, eksterne integrasjoner og en komplett meldingsflyt gjenstår.

Miljøet ble først etablert i Paris. Fordi Redis var deaktivert/ikke tilgjengelig for kontoen der, ble PoC-ressursene revet ned og opprettet på nytt i Warszawa. Terraform-state ble beholdt i Paris.

## 1. Formål og avgrensning

PoC-en skal undersøke:

- Om nødvendige infrastrukturtjenester for Correspondence kan etableres hos en europeisk skyleverandør med Terraform.
- Hvordan deployment og testing kan gjennomføres fra GitHub Actions.
- Hvilke Azure-avhengigheter som må tilpasses i applikasjon og driftsoppsett.
- Om Correspondence kan gjennomføre en funksjonell meldingsflyt på Scaleway.

Arbeidet så langt omfatter hovedsakelig infrastruktur, tilgang, deployment og grunnleggende kommunikasjon. Resultatene er ikke en verifisering av produksjonskapasitet, høy tilgjengelighet, gjenoppretting eller full funksjonell portabilitet.

## 2. Hva PoC-en inneholder

| Komponent | Innhold | Status per 19.10.2026 |
| --- | --- | --- |
| Terraform | Gjenbrukbare Scaleway-moduler og egen miljøkonfigurasjon | Etablert og benyttet til utrulling |
| GitHub Actions | Validering, tester, plan/apply/destroy, bygging av images og separate test-/bootstrap-workflows | Etablert |
| Remote state | Bucketen `digdir-portability-tfstate` i Paris, med state-låsing | I bruk |
| Nettverk | VPC og privat nettverk | Opprettet i Warszawa |
| PostgreSQL | Administrert PostgreSQL, databasen `correspondence`, TLS og databaseprivilegier | Tilkobling og `SELECT 1` verifisert |
| PostgreSQL-extensions | Bootstrap-container for `uuid-ossp`, `hstore`, `pg_stat_statements`, `pgaudit` og `pg_cron` | Vellykket resultat dokumentert i Paris; sluttresultat i Warszawa må bekreftes |
| Redis | Administrert Redis med TLS og privat nettverk | Skriving, lesing og sletting verifisert |
| Object Storage | Privat S3-kompatibel bucket for vedlegg | Skriving, lesing og sletting verifisert |
| Secret Manager | Modul for blant annet database- og Redis-tilkoblingsstrenger | Etablert; øvrige applikasjonssecrets gjenstår |
| Container Registry | Images for connectivity-probe og PostgreSQL-bootstrap | I bruk i Warszawa |
| Serverless Containers | Containerplattform med privat nettverk, secrets og skalering | Connectivity-probe deployet og testet |
| Logging og overvåking | Grunnlag gjennom containerplattformens Cockpit-integrasjon | Fullt applikasjonsoppsett, retention og alarmer gjenstår |
| Correspondence-applikasjonen | Tilpasset image og full applikasjonskonfigurasjon | Ikke verifisert på Scaleway |

Vedleggsbucketen heter `altinn-corr-internal-poc-attachments-8a731d6e`. S3-endepunktet for ressursregionen er `https://s3.pl-waw.scw.cloud`.

### Kodestruktur

```text
cloud-providers/scaleway/terraform/modules/
environments/internal-poc/correspondence/scaleway/terraform/
.github/workflows/
tools/ci/
tools/connectivity-probe/
tools/postgresql-bootstrap/
```

Terraform-konfigurasjon og workflows ligger i repoet. Credentials og passord leveres gjennom GitHub Secrets. Miljøinnstillinger leveres blant annet gjennom GitHub Variables og `SCW_TFVARS_JSON`.

## 3. Prosessen med å etablere miljøet

### 3.1 Tilgang og første kontakt

Scaleway-prosjekt, API-nøkler og GitHub-miljøet `scaleway-internal-poc` ble konfigurert. Et API-kall fra GitHub Actions bekreftet kontakt med Scaleway før infrastruktur var opprettet.

### 3.2 Terraform og remote state

Terraform-moduler og miljøkonfigurasjon ble etablert. State-bucketen ble gjort tilgjengelig før miljøet tok i bruk S3-backend. Terraform-state lagres separat fra applikasjonsressursene og ble beholdt ved regionflyttingen.

### 3.3 Trinnvis deployment

Ressursene ble aktivert og deployet gradvis: nettverk, registry, objektlagring, PostgreSQL, secrets og containere. Redis ble midlertidig utelatt i Paris.

Moduler ble i perioder kommentert ut. Dette krevde tilsvarende justeringer i `locals.tf`, `outputs.tf` og avhengigheter i `main.tf`.

### 3.4 Connectivity-probe

En egen Python-container ble bygget i GitHub Actions og lastet opp til Scaleway Registry. Terraform ble deretter kjørt for å deploye imaget med nødvendige miljøvariabler og secrets.

En separat workflow kaller containerens `/checks`-endepunkt. Database- og S3-operasjonene kjøres fra containeren hos Scaleway, slik at GitHub-runneren ikke trenger direkte nettverkstilgang til de private databasene.

### 3.5 PostgreSQL-extensions

En separat bootstrap-container ble etablert for å installere og kontrollere extensions gjennom SQL. GitHub Actions kaller bootstrap-containeren over HTTPS; containeren kobler til databasen over privat nettverk.

`pgaudit` krever også en innstilling på Scaleway-databaseinstansen. `pg_cron` ble konfigurert i Scaleways `rdb`-database. Bootstrap er separat fra applikasjonens databasemigreringer.

### 3.6 Flytting til Warszawa

Paris-miljøet var ikke i bruk og ble revet ned. Ressursene ble opprettet i `pl-waw`, mens state-bucketen ble beholdt i `fr-par`.

Region, sone, registry-adresser, image-referanser og container-endepunkt måtte oppdateres. Images ble bygget i registryet i Warszawa, og Redis ble inkludert i connectivity-testen.

### Deployment-modell

| Hendelse | Handling |
| --- | --- |
| Pull request / relevant push til `main` | Validering og tester |
| Manuell Terraform-workflow med `plan` | Oppretter plan |
| Manuell Terraform-workflow med `apply` | Oppretter og anvender planen i samme kjøring |
| Manuell Terraform-workflow med `destroy` | Planlegger og river ned miljøet, med kontroll av bekreftelsesverdi |
| Build-workflow | Bygger og laster opp image; oppdaterer ikke den kjørende containeren |
| Connectivity-workflow | Kaller proben og kontrollerer testresultatet |
| PostgreSQL-bootstrap-workflow | Kaller bootstrap-containeren for å konfigurere extensions |

**Commit starter ikke automatisk deployment til Scaleway. Bygging av image og deployment er separate handlinger.**

## 4. Utfordringer og håndtering

| Utfordring | Årsak / konsekvens | Håndtering |
| --- | --- | --- |
| Referanser til moduler som var kommentert ut | Terraform validerer også referanser i locals og outputs | Tilhørende referanser og avhengigheter ble justert |
| Gjentatte formateringsfeil | `terraform fmt -check` stoppet workflowen på whitespace | Formateringssjekken ble fjernet; øvrig validering og testing ble beholdt |
| Redis utilgjengelig i Paris | Tjenesten var deaktivert/ikke tilgjengelig for kontoen | Miljøet ble flyttet til Warszawa |
| Redis-versjon ikke funnet | Konfigurert serverversjon samsvarte ikke med tilbudet fra API-et | Versjonen ble tilpasset tilgjengelig tjeneste |
| Feil Redis-versjon i Python-avhengigheter | Serverversjon ble brukt som versjon for Python-klienten | Redis-server og `redis`-pakken i `requirements.txt` ble skilt |
| PostgreSQL-bruker manglet databasetilgang | Innlogging fungerte, men `CONNECT` til `correspondence` var ikke tillatt | Databaseprivilegier ble lagt til eksplisitt i Terraform |
| Feil i extension-bootstrap | Rettigheter og Scaleway-spesifikk plassering/aktivering måtte avklares | Privilegier og instansinnstillinger ble tilpasset |
| Kontroll av `shared_preload_libraries` feilet | Brukeren manglet tilgang til å lese den beskyttede innstillingen | Den unødvendige kontrollen ble fjernet |
| Eksisterende PostgreSQL-innstillinger ble planlagt fjernet | Nytt settings-kart inneholdt bare pgaudit-innstillingen | Eksisterende verdier ble bevart med `merge` |
| Bootstrap-containerens navn var for langt | Navnet oversteg Scaleways lengdegrense | Suffikset ble forkortet til `-pg-init` |
| Manglende bootstrap-output | Containeren var ikke aktivert/deployet med gyldig image | Image ble bygget og konfigurert før ny apply |
| Ugyldige eller gamle image-referanser | Blant annet `.` som image og referanser til tidligere registry i Paris | Gyldige images ble bygget og valgt i Warszawa |
| Ugyldig `SCW_TFVARS_JSON` | Manglende avsluttende klammeparentes stoppet konfigurasjonsskriptet | JSON-konfigurasjonen ble rettet |
| DNS-feil ved connectivity-test | GitHub-variabelen pekte fortsatt til det gamle Paris-endepunktet | Endepunktet ble oppdatert til Warszawa |
| `/checks` returnerte nginx 404 | Containeren kjørte fortsatt smoke-imaget | Connectivity-imaget ble valgt og deployet med Terraform |
| Minneverdien ga endring etter apply | API-et returnerte en litt annen verdi enn konfigurert | Ressursverdien ble tilpasset; etterfølgende plan viste ingen endringer |

### Erfaringer

- Trinnvis deployment bør etter hvert styres med tydelige konfigurasjonsvalg fremfor manuell utkommentering.
- Tilkobling til PostgreSQL og rettigheter inne i databasen er forskjellige forhold og må testes separat.
- Kontroll av tilgjengelige tjenester og versjoner bør gjøres før region og konfigurasjon låses.
- Ved regionflytting må også eksterne GitHub-variabler og image-referanser oppdateres.
- En vellykket image-build betyr ikke at den kjørende containeren er oppdatert.
- Portering fra Azure krever både infrastrukturoppsett og endringer i applikasjonens tjenesteintegrasjoner.

## 5. Dokumenterte testresultater

Siste samlede connectivity-test i Warszawa returnerte:

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
| PostgreSQL | TLS-tilkobling, autentisering og `SELECT 1` |
| Redis | TLS-tilkobling, autentisering, ping, skriving, lesing og sletting av testnøkkel |
| Object Storage | Autentisering, skriving, lesing og sletting av testobjekt |

Extension-bootstrap returnerte tidligere følgende installasjoner i Paris:

```json
{
  "status": "ok",
  "application_extensions": {
    "uuid-ossp": "1.1",
    "hstore": "1.8",
    "pg_stat_statements": "1.11",
    "pgaudit": "17.1"
  },
  "rdb_extensions": {
    "pg_cron": "1.6"
  }
}
```

Dette resultatet må ikke tolkes som en dokumentert kontroll av den nye databasen i Warszawa. Connectivity-testens `SELECT 1` kontrollerer heller ikke extensions eller applikasjonens databaseskjema.

## 6. Azure-funksjoner som fortsatt må tilpasses

| Azure-funksjon | Retning for Scaleway-PoC | Gjenstående arbeid |
| --- | --- | --- |
| Azure Blob Storage | S3-kompatibel Object Storage | Implementere og teste S3-støtte i Correspondence, inkludert eventuelle nedlastingslenker |
| Azure Files for migreringsfiler | Separat S3-bucket dersom verktøyet kan bruke objektlagring | Kartlegge behovet for filsystem og Azure Files SDK |
| Key Vault-referanser | Secrets injisert som miljøvariabler ved deployment | Komplettere konfigurasjonen og gjennomgå eventuell direkte Key Vault-bruk |
| Managed Identity / Azure Resource Manager | Tilpasset autentisering for tjenestene som fortsatt brukes | Kartlegge Azure-kall og nødvendige identiteter |
| Application Insights | OpenTelemetry og Cockpit | Instrumentering, eksport, dashboards og alarmer |
| Driftslogger / auditlogger | Separate loggstrømmer og datakilder ved behov | Ruting og ønsket retention, blant annet 30/90 dager fra Azure-oppsettet |
| APIM / Event Grid | Avklart innkommende tilgang og autentisering | Teste leveranse fra eventuelle gjenværende Azure-tjenester |
| Maskinporten JWK-rotasjon | Foreløpig deaktivert i PoC-konfigurasjonen | Tilpasse rotasjon som i dag oppdaterer Azure-ressurser |
| Azure RBAC og tag-policyer | Scaleway IAM, bucket-policyer, Terraform-tags og eventuelle CI-kontroller | Avgrense rettigheter og etablere ønsket håndheving |

I dagens Terraform-oppsett får Secret Manager og containerens secret-miljøvariabler verdiene fra Terraform-konfigurasjonen. Containeren henter dem ikke automatisk fra Secret Manager.

## 7. Gjenstående arbeid i anbefalt rekkefølge

- [ ] Bekrefte extension-bootstrap mot PostgreSQL i Warszawa og dokumentere resultatet.
- [ ] Kartlegge gjenværende Azure-avhengigheter i Correspondence og deployment-pipelines.
- [ ] Implementere S3-støtte og bygge et tilpasset Correspondence-image i registryet i Warszawa.
- [ ] Legge inn nødvendige applikasjonssecrets, tjenesteadresser og miljøkonfigurasjon.
- [ ] Avklare og etablere lagring for migreringsfiler dersom den brukes av migreringsprosessen.
- [ ] Kjøre applikasjonens databasemigreringer og kontrollere skjema og rettigheter.
- [ ] Deploye Correspondence med `container_mode = "correspondence"`, `min_scale = 1`, port `2525` og riktig helseendepunkt for imaget.
- [ ] Teste nødvendige eksterne integrasjoner og innkommende autentisering.
- [ ] Verifisere en komplett meldingsflyt med vedlegg, PostgreSQL og Redis.
- [ ] Teste bakgrunnsjobber, omstart, skalering og utvalgte feilscenarier.
- [ ] Ferdigstille logging, auditlogging, retention og alarmer.
- [ ] Gjennomgå IAM-tilganger, secret-håndtering og rutiner for deployment og nedrigging.
- [ ] Dokumentere applikasjonsendringer, tidsbruk, begrensninger og driftskostnader som grunnlag for videre vurdering.

## 8. Neste milepæl

**Deploye et tilpasset Correspondence-image og dokumentere én komplett funksjonell meldingsflyt på Scaleway.**

Når dette er gjennomført, kan PoC-en brukes til å vurdere applikasjonsportabilitet i tillegg til den allerede verifiserte infrastrukturen og datatilgangen.
