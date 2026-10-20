# Start her – intern Correspondence-PoC hos Scaleway

Pakken inneholder åtte gjenbrukbare moduler, miljøkode i de avtalte katalogene,
GitHub Actions og en valgfri testcontainer for databasetilkobling, Redis og S3.
Den første kjøringen bruker nginx. Selve Correspondence-applikasjonen må fortsatt
få tilpasninger for Azure-avhengighetene før den kan fungere på Scaleway.

## 1. Legg filene i GitHub-repoet

Pakk ut ZIP-en og kopier **innholdet** i toppmappen til roten av portability-repoet.
Ta med skjulte filer: `.github`, `.gitignore`, `.terraform-version` og
`.terraform.lock.hcl` i de to Terraform-røttene. Bevar eksisterende repo-filer og
slå sammen `.gitignore`/workflows ved behov.

- Moduler: `cloud-providers/scaleway/terraform/modules`
- Miljø: `environments/internal-poc/correspondence/scaleway/terraform`
- State-bootstrap: `cloud-providers/scaleway/terraform/bootstrap/state`

Opprett en branch/PR. CI kan sjekke koden før dere har Scaleway-konto eller nøkler.
Hvis hovedbranchen har et annet navn enn `main`, endre `push.branches` i workflowen.

## 2. Når Digdir-kontoen er klar

1. Velg et Digdir-eid Scaleway-prosjekt og en IAM-applikasjon for automasjon.
2. Opprett state-bucket én gang via bootstrap-koden; se README i bootstrap-mappen.
   Bevar dens lokale state sikkert utenfor Git.
3. Opprett GitHub environment `scaleway-internal-poc`.
4. Registrer obligatoriske secrets og variables fra tabellen i hoved-README:
   `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_ORGANIZATION_ID`, `SCW_PROJECT_ID`,
   `SCW_STATE_BUCKET`, `POC_DATABASE_PASSWORD` og `POC_REDIS_PASSWORD`.
   Passordene skal ha 16–128 tegn: store og små bokstaver, tall og minst én `_` eller `-`; øvrige tegn tillates ikke i denne første kodeversjonen. Velg også en tilgjengelig, oppdatert Redis-versjon i `SCW_TFVARS_JSON` (se hoved-README).
5. Kjør Actions → **Scaleway Terraform** → **plan** fra hovedbranchen.
6. Se gjennom planen. Kjør deretter **apply** for å opprette ressursene.

Standardmiljøet bruker Paris, PostgreSQL 17, én liten Redis-node, private
endepunkter, daglig databasebackup og maks én container. Kontroller tilgjengelige
størrelser, versjoner, kvoter og kostnader i det faktiske prosjektet.

## 3. Test i to trinn

**Første trinn: HTTP.** Åpne containerens URL med `X-Auth-Token`-header, som
beskrevet i hoved-README. Nginx viser at containeren er oppe.

**Andre trinn: datatjenester.** Sett registry-endepunktet som GitHub-variable,
bygg probe-imaget med **Scaleway Build Connectivity Probe**, legg inn egne S3-nøkler
og sett `container_mode` til `connectivity`. Etter plan/apply testes `/checks`.
Den sjekker PostgreSQL, Redis og lagring med små, midlertidige testverdier.

Deretter kan dere arbeide med den tilpassede Correspondence-containeren på port
2525 og integrasjoner mot Altinn testmiljø. Se `docs/APPLICATION_PORTING.md`.

## Avklaring om migrering

Serverless Jobs kan foreløpig ikke nå Private Network. Jobbmodulen kobles ikke
til den private databasen. Correspondence med `ScalewayPoc` kjører EF-migrering
ved oppstart i selve API-containeren. Databasen åpnes ikke offentlig.

## Kontroller og avgrensning

Les `docs/VALIDATION.md` før første apply. Koden er formatkontrollert,
provider-avhengighetene er initialisert, og Python-testene er kjørt.
Full `terraform validate` og mock-planer må kjøres i GitHub Actions: dette
arbeidsmiljøet blokkerer Unix-socketen som Terraform-providerprosessen trenger.
Det er ikke kjørt noen utrulling mot Scaleway.

Database-/Redis-passord og secret-verdier lagres i Terraform state.
State og lagrede planer skal derfor behandles som hemmeligheter. Planer lastes
ikke opp som GitHub-artifacts. Fjern PoC-ressursene med destroy når testperioden
er ferdig; state-bootstrap inngår ikke i den oppryddingen.
