# ORDA ZERO — Documento di design

> Documento di riferimento per tutte le fasi di sviluppo.
> Il testo dalla sezione "Concept" alla sezione "Fasi" è il design originale, riportato senza modifiche
> (sono state tolte solo le istruzioni rivolte alla singola sessione di lavoro).
> In fondo c'è l'elenco dei punti ambigui o in conflitto emersi durante la Fase 1, con la scelta provvisoria adottata (da confermare).

Sviluppiamo insieme "ORDA ZERO", un gioco Android in Godot 4 (GDScript), in questa repository. Lavoreremo a FASI.

## Concept
Shooter "crowd runner" a ondate infinite, schermo verticale, grafica 3D low-poly con soldati stilizzati, visuale dall'alto/dietro come i classici giochi mobile di questo genere. Personaggi e grafica tutti originali. Lingua del gioco: italiano. Nessuna monetizzazione. Il gioco deve essere DIFFICILE ma mai impossibile: si va avanti con skill e buone decisioni, non con la fortuna.

## Gameplay principale
- La folla del giocatore avanza da sola su una pista infinita; il giocatore la sposta a destra/sinistra trascinando il dito liberamente (non corsie fisse).
- Le unità SPARANO automaticamente in avanti. Se i nemici arrivano a contatto, attaccano e uccidono unità.
- Game over quando le unità arrivano a 0. Una sola vita, nessun checkpoint.
- CONTATORE UNITÀ: il numero reale di unità è tenuto da un contatore ben visibile. Oltre una soglia (VISUAL_UNIT_CAP, default 10) la folla visibile NON cresce più graficamente: il contatore sale, la grafica resta uguale. Anche la potenza di fuoco va calcolata sul numero REALE di unità, non su quelle visibili (usa proiettili aggregati se servono per le prestazioni).

## Nemici
- Arrivano frontalmente a ondate. Il numero cresce in modo LINEARE a ogni ondata (nemici = base + incremento × ondata, entrambi configurabili). Anche la velocità cresce leggermente, con un tetto massimo.
- Varianti che si sbloccano man mano con le ondate: base, veloci, corazzati (più colpi per ucciderli), a distanza (sparano alla folla). Ogni variante deve essere riconoscibile a colpo d'occhio.
- Per le prestazioni, anche i gruppi di nemici numerosi possono avere un limite visivo con contatore.

## Cancelli
- Arrivano a COPPIE: il giocatore sceglie da quale passare (+N, −N, ×N, ÷N).
- I cancelli malus diventano leggermente più frequenti con le ondate, ma fino a un LIMITE massimo configurabile, per non rendere il gioco impossibile. Alcuni sono ingannevoli (es. un +5 accanto a un ×2 quando hai 3 unità: bisogna ragionare).
- CANCELLI BONUS DA DISTRUGGERE: ostacoli fermi con dei punti vita (numero visibile) da abbattere sparando un certo numero di colpi. Se distrutti danno un bonus, ad esempio un'arma più potente (fucile → mitragliatrice → lanciarazzi) che dura per tutta la partita, o bonus temporanei. Il rischio è che mentre spari lì non spari ai nemici.

## Mini boss
- Compaiono dopo un numero di nemici uccisi pari a una base configurabile ± 20% casuale, così non sono prevedibili al millisecondo.
- Prima dell'arrivo compare un avviso "BOSS IN ARRIVO", così il giocatore può prepararsi.
- Devono essere superabili SOLO con una buona strategia: vita calibrata sulla potenza di fuoco che un giocatore bravo può aver accumulato, attacchi ad area segnalati prima (zona rossa a terra) da schivare trascinando la folla, eventuali scudi o fasi.
- Dopo ogni boss sconfitto: scelta di 1 potenziamento su 3 per il resto della partita, stile roguelite (es. +20% cadenza di fuoco, +10 unità, danni ad area, unità più resistenti).

## Punteggio
- Punteggio = ondata raggiunta. Salva solo il record personale in locale. Nessun potenziamento permanente tra le partite.
- Schermata game over con ondata raggiunta, record, unità massime avute e pulsante "Riprova".

## Requisiti tecnici
- Godot 4 (ultima versione stabile), renderer "Compatibility" per supportare più telefoni Android possibile.
- Prestazioni: MultiMeshInstance3D per folla, nemici e proiettili; object pooling; niente istanziazioni pesanti a runtime. Obiettivo 60 fps su un telefono di fascia media.
- TUTTI i parametri di bilanciamento (velocità, crescita nemici, frequenza malus e limite, vita boss, ±20%, VISUAL_UNIT_CAP, armi, potenziamenti) in UN unico file di configurazione ben commentato, così posso bilanciare io senza toccare il codice.
- Codice organizzato in scene e script chiari, con commenti in italiano.
- README con descrizione del gioco e istruzioni per scaricare e installare l'APK.

## Build automatica
Configura un workflow GitHub Actions che, a ogni push su main, esporti un APK di DEBUG di Godot 4 per Android (con export templates e una keystore di debug generata nel workflow stesso) e lo carichi come artifact scaricabile. NESSUNA chiave o segreto deve finire nella repository (la repo è pubblica). La firma di release la faremo più avanti con GitHub Secrets.

## Fasi
1. Setup progetto Godot + workflow APK + pista infinita + folla con trascinamento + sparo automatico + nemici base + contatore unità con limite visivo + game over.
2. Cancelli a coppie, malus con limite, cancelli bonus da distruggere e armi.
3. Varianti di nemici e crescita lineare delle ondate.
4. Mini boss con avviso, attacchi ad area e scelta potenziamenti 1 su 3.
5. Punteggio, record, menu, schermata game over.
6. Effetti, suoni, feedback visivi, bilanciamento finale.

---

## Punti ambigui o in conflitto (da confermare)

Per ogni punto: la domanda aperta e, tra parentesi quadre, la scelta **provvisoria** fatta in Fase 1 (tutto modificabile da `config/bilanciamento.cfg` quando possibile).

### Combattimento
1. **Contatto nemico–folla.** "Attaccano e uccidono unità": quante e per quanto tempo?
   [Ogni nemico che tocca la folla uccide `unita_uccise_al_contatto` unità (1) e muore nello scontro.]
2. **I nemici inseguono la folla?** "Arrivano frontalmente": se andassero solo dritti basterebbe spostarsi per evitarli tutti.
   [Avanzano dritti ma scivolano di lato verso la folla a velocità limitata (`velocita_laterale`): posizionarsi bene conta, ma non si può scappare all'infinito.]
3. **Direzione di tiro.** [I proiettili vanno sempre dritti in avanti: si mira spostando la folla. Vale anche per i futuri cancelli bonus da abbattere.]
4. **"Unità più resistenti"** (potenziamento): oggi un'unità muore al primo contatto. Serve introdurre una vita per unità, o è per esempio una probabilità di sopravvivere al contatto? (Fase 4)
5. **Nemici a distanza**: ogni loro colpo uccide 1 unità? I loro proiettili si possono schivare? (Fase 3)

### Ondate
6. **Formula "base + incremento × ondata".** Applicata alla lettera: l'ondata 1 ha già `base + incremento` nemici (8 + 4 = 12). Stessa forma per la velocità, con tetto.
7. **Fine di un'ondata e ritmo di comparsa** non sono specificati.
   [L'ondata finisce quando tutti i suoi nemici sono comparsi e non ne resta nessuno in campo; dopo `pausa_tra_ondate` parte la successiva. I nemici di un'ondata compaiono a squadre in `durata_comparsa` secondi, quindi diventano sempre più fitti.]
8. **Fase 1 vs Fase 3.** La crescita lineare è elencata in Fase 3, ma in Fase 1 servono comunque delle ondate.
   [La formula lineare è già attiva dalla Fase 1; in Fase 3 arrivano varianti e limite visivo dei gruppi.]
9. **Limite visivo dei gruppi di nemici con contatore**: un gruppo diventa un'unica "squadra" con un numero sopra? Come si comporta quando viene colpito? (Fase 3)

### Unità e cancelli
10. **Crescita moltiplicativa contro crescita lineare.** Con i cancelli ×N le unità (e la potenza di fuoco reale) possono crescere in modo esponenziale, mentre i nemici crescono in modo lineare. Nelle simulazioni della Fase 2, senza correttivi, anche un giocatore che non tocca lo schermo arrivava al tetto di unità e sopravviveva oltre 30 minuti.
    [Scelte provvisorie, tutte nel file di bilanciamento:
    - tetto di 250 unità (`unita_massime`);
    - cancelli ×N meno frequenti (solo ×2) e malus più frequenti (dal 40% al 70%);
    - **nuovo parametro, non previsto dal design:** la vita dei nemici cresce un po' a ogni ondata (`[nemici] vita_incremento_per_ondata`, oggi 0.8). Mettilo a 0 per tornare alla sola crescita del numero.

    Con questi valori, nelle simulazioni un giocatore "perfetto" arriva all'ondata 60–80 (15–20 minuti), uno che non si muove all'ondata 15–45.]
11. **Arrotondamenti di ÷N e −N**: per difetto? Possono portare a 0 unità?
    [÷N arrotonda per difetto. Un malus lascia sempre almeno 1 unità (`unita_minime_dopo_malus`, mettilo a 0 per renderli mortali). Le coppie con due malus ("il male minore") arrivano solo dall'ondata 5 e mai due di fila, perché due di fila a inizio partita facevano perdere anche giocando perfettamente.]
12. **Armi dai cancelli bonus**: "dura per tutta la partita" oppure "bonus temporanei"?
    [Ogni ostacolo "arma" fa salire l'arma di un livello (fucile → mitragliatrice → lanciarazzi), che resta per tutta la partita. Gli altri ostacoli danno un bonus temporaneo: FUOCO RAPIDO (cadenza ×2 per 8 s) o COLPI POTENZIATI (danno ×2 per 8 s). La ricompensa è scritta sopra l'ostacolo, così si sceglie se vale la pena sparargli. Con l'arma migliore già in mano, la ricompensa è sempre temporanea.]
13. **Unità iniziali** non specificate. [8 dalla Fase 2, quando sono arrivati i cancelli.]
13b. **Ostacoli bonus non distrutti**: se la folla li raggiunge, le passano attraverso senza danni. Il rischio è solo aver sprecato colpi. [Da confermare: in alternativa potrebbero uccidere delle unità.]

### Boss e punteggio
14. **Contatore per il mini boss**: si azzera dopo ogni boss? Contano anche i nemici morti per contatto? Le ondate si fermano mentre c'è il boss?
    [Per ora `uccisi_totali` conta solo i nemici abbattuti sparando.]
15. **"Ondata raggiunta"**: [è l'ondata in corso al momento del game over.]
16. **Schermata di game over**: il game over è in Fase 1, il record in Fase 5.
    [Fase 1: schermata base con ondata raggiunta, unità massime e "Riprova". Il record arriva in Fase 5.]
17. **Lingua**: la scritta "GAME OVER" è in inglese. Va bene o preferisci per esempio "SCONFITTA"?

### Build
18. **Quando parte il workflow**: il design dice "a ogni push su main".
    [Parte anche sulle pull request e a mano, così l'APK si può provare prima del merge.]
19. **Keystore di debug**: il design dice "generata nel workflow". Se fosse rigenerata a ogni build, ogni nuovo APK avrebbe una firma diversa e bisognerebbe disinstallare il gioco prima di aggiornarlo.
    [Viene generata nel workflow ma conservata nella cache di GitHub Actions. Se la cache scade (7 giorni senza build) ne viene creata una nuova e bisogna disinstallare una volta.]
20. **"Ultima versione stabile" di Godot**: [4.7.2, fissata nel workflow (`GODOT_VERSION`). Gli aggiornamenti si fanno a mano, per evitare che una nuova versione rompa la build all'improvviso.]
