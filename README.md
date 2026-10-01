# ORDA ZERO

Shooter per Android a ondate infinite, in 3D low-poly, fatto con Godot 4 e ispirato alle pubblicità di Top War. Tutta la grafica e tutti i suoni sono originali.

Comandi una squadra di soldati schierata in fondo a un ponte, di notte. Le orde nemiche ti vengono incontro. Trascini il dito a destra e a sinistra per spostare la squadra, e i soldati sparano da soli. Se i nemici ti toccano perdi soldati, e quando li perdi tutti la partita finisce. Il punteggio è l'ondata che hai raggiunto.

## Come si gioca
- **Cancelli** (+N, -N, ×N, ÷N): arrivano a coppie. Passi da quello del lato in cui ti trovi, e a volte bisogna fare il conto.
- **Barili gialli**: hanno i punti vita scritti sopra. Se li abbatti ottieni l'arma successiva (fucile → mitragliatrice → lanciarazzi) o un bonus temporaneo. Mentre spari a loro, però, non spari ai nemici.
- **Nemici**:
  - rossi (base);
  - arancioni (veloci);
  - grigi con scudo (corazzati);
  - viola (tiratori, che sparano da lontano: schiva i colpi spostandoti).

  Dall'ondata 3 arrivano anche le **orde**, con un contatore sopra.
- **Mini boss**: compare l'avviso "BOSS IN ARRIVO". Il boss lancia attacchi ad area segnalati da zone rosse a terra: trascina la squadra fuori. Sotto metà vita alza uno scudo. Quando lo sconfiggi scegli **1 potenziamento su 3**, che vale per il resto della partita.
- **Record**: viene salvata l'ondata più alta. Puoi mettere in pausa col pulsante in alto o col tasto indietro.

- Schermo verticale, lingua italiana, nessuna pubblicità né acquisto.
- Difficile ma mai impossibile: conta la bravura, non la fortuna.
- Il design completo e le scelte fatte sono in [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

> **Stato:** tutte e 6 le fasi completate (versione 1.0.0).

## Scaricare e installare l'APK sul telefono

L'APK di **debug** viene generato automaticamente da GitHub Actions a ogni push su `main`, a ogni pull request e quando lo avvii a mano.

1. Apri la scheda **Actions** della repository e scegli il workflow **"APK di debug Android"**.
   Serve essere loggati su GitHub per scaricare i file.
2. Apri l'esecuzione più recente con la spunta verde.
3. In fondo alla pagina, nella sezione **Artifacts**, scarica **`orda-zero-debug-apk`**.
   È un file `.zip`: estrailo e dentro trovi `orda-zero-debug.apk`.
4. Copia l'APK sul telefono (o scaricalo direttamente dal telefono) e aprilo.
5. Android ti chiederà di consentire l'installazione da "origini sconosciute" per l'app che stai usando (browser o file manager): accetta.
6. Play Protect potrebbe avvisarti che l'app non è verificata: scegli "Installa comunque". È normale per un APK di debug.

**Aggiornamenti:** di solito il nuovo APK si installa sopra il vecchio. Se Android dice che il pacchetto è in conflitto o "non è stato installato", disinstalla prima ORDA ZERO e poi installa il nuovo APK. Succede quando la chiave di debug è stata rigenerata, per esempio dopo 7 giorni senza build.

Per generare un APK a mano: **Actions → APK di debug Android → Run workflow**.

Requisiti: Android 7.0 o superiore, processore ARM a 32 o 64 bit (praticamente tutti i telefoni).

## Bilanciamento

Tutti i numeri che regolano la difficoltà stanno in **un unico file commentato**: [`config/bilanciamento.cfg`](config/bilanciamento.cfg).
Puoi modificarlo direttamente da GitHub (icona della matita). Al push successivo su `main` viene generato un nuovo APK con i nuovi valori.

## Sviluppo

- Motore: **Godot 4.7.2** (renderer *Compatibility*, per supportare più telefoni possibile).
- Apri la cartella del progetto con Godot e premi F5. Col mouse, trascina con il tasto sinistro premuto per spostare la folla.

Struttura:

| Percorso | Contenuto |
|---|---|
| `config/bilanciamento.cfg` | Tutti i parametri di bilanciamento |
| `scenes/main.tscn` | Scena della partita |
| `scenes/ui/` | HUD, menu, pausa, scelta dei potenziamenti, game over |
| `scripts/autoload/` | `Config` (file di bilanciamento), `Dati` (record e audio), `Suoni` (effetti sonori generati via codice) |
| `scripts/game/` | Ponte, folla, proiettili, nemici e orde, ondate, cancelli, armi, boss, potenziamenti, effetti e regia della partita |
| `scripts/ui/` | Script dell'interfaccia |
| `scripts/util/` | Modelli low-poly generati via codice (soldati, barili, ...) e aiuti per i MultiMesh |
| `shaders/pista.gdshader` | Strada del ponte e mare |
| `.github/workflows/android-debug-apk.yml` | Build automatica dell'APK |

Note tecniche:

- Folla, nemici, orde, proiettili, ringhiere, braci e particelle sono disegnati con **MultiMeshInstance3D**. Tutti i dati sono in pool di array e i nodi (cancelli, barili, etichette, zone del boss) vengono creati all'avvio e riusati: durante la partita non viene istanziato nessun nodo.
- La squadra resta ferma ed è tutto il resto a venirle incontro. Con `[pista] velocita_avanzamento` maggiore di 0 la strada scorre e la squadra "corre".
- Nel caso peggiore (120 gruppi e oltre 1500 nemici in campo) la logica di gioco costa in media circa 2 ms per fotogramma su un PC. Il costo su un telefono va verificato sul campo: se il gioco scatta, abbassa `max_nemici_attivi` e `membri_visibili_massimi`.
- I soldati disegnati sono al massimo `visual_unit_cap`. Il danno invece è calcolato sul numero **reale** di unità: ogni proiettile visibile porta un danno aggregato, e se avanza danno dopo aver ucciso un nemico continua sul successivo.

## Sicurezza

La repository è pubblica, quindi **nessuna chiave o password** va salvata qui dentro. La keystore di debug viene creata dal workflow. La firma di release si farà più avanti con i GitHub Secrets.
