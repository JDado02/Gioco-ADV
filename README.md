# ORDA ZERO

Shooter "crowd runner" per Android a ondate infinite, in 3D low-poly, fatto con Godot 4.

Guidi una folla di soldati che avanza da sola su una pista infinita. Trascini il dito a destra e a sinistra per spostarla, e i soldati sparano da soli. Le ondate di nemici sono sempre più numerose. Se ti toccano, perdi soldati. Quando i soldati finiscono, la partita è finita. Il punteggio è l'ondata che hai raggiunto.

- Schermo verticale, lingua italiana, nessuna pubblicità né acquisto.
- Difficile ma mai impossibile: conta la bravura, non la fortuna.
- Il design completo è in [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

> **Stato:** Fase 1 di 6 (pista infinita, folla, sparo automatico, nemici base, ondate, game over).
> Cancelli, armi, varianti di nemici, boss e record arriveranno nelle fasi successive.

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
| `scenes/ui/` | HUD e schermata di game over |
| `scripts/autoload/config.gd` | Lettura del file di bilanciamento (`Config`) |
| `scripts/game/` | Pista, folla, proiettili, nemici, ondate e regia della partita |
| `scripts/ui/` | Script dell'interfaccia |
| `scripts/util/` | Mesh low-poly generate via codice e aiuti per i MultiMesh |
| `shaders/pista.gdshader` | Terreno della pista infinita |
| `.github/workflows/android-debug-apk.yml` | Build automatica dell'APK |

Note tecniche:

- Folla, nemici, proiettili e alberi sono disegnati con **MultiMeshInstance3D**, e i dati sono tenuti in pool di array: durante la partita non viene istanziato nessun nodo.
- La folla resta ferma attorno all'origine ed è il mondo a scorrere verso la telecamera, così le coordinate restano sempre piccole.
- I soldati disegnati sono al massimo `visual_unit_cap`. Il danno invece è calcolato sul numero **reale** di unità: ogni proiettile visibile porta un danno aggregato, e se avanza danno dopo aver ucciso un nemico continua sul successivo.

## Sicurezza

La repository è pubblica, quindi **nessuna chiave o password** va salvata qui dentro. La keystore di debug viene creata dal workflow. La firma di release si farà più avanti con i GitHub Secrets.
