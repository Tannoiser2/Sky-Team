# Sky Team - versione digitale

Sky Team di Luc Rémond (Le Scorpion Masqué) con l'espansione **Turbolenze**, in Godot 4.7, per la ludoteca digitale.

Pilota (blu) e Copilota (arancione) piazzano in silenzio i dadi sulla plancia di comando originale per far atterrare l'aereo.

## Cosa c'è

- **53 voli**: gioco base (21), espansione Turbolenze (20), scenari promozionali (12), con le piste di avvicinamento originali.
- **Tutti i moduli**: cherosene, perdita di cherosene, freni da ghiaccio, vento, tirocinante, tempo reale, allarmi, partenza a 5000 piedi, pinguini dell'Antartide (NZIR), atterraggio sulla pancia (WAW), motori spenti (TER).
- **Le sei abilità speciali**: Anticipazione, Adattamento, Padronanza, Controllo, Lavorare insieme, Sincronia.
- **Compagno IA** che gioca onestamente (vede solo i propri dadi) oppure il **Copilota Automa** del solitario ufficiale.
- **Online** con un amico (stanze su Firebase, radice `skyteam`), volo salvato a ogni mossa nel browser e su Firebase.
- **Vista 3D**: il modellino dell'aereo in alto, la rotta che scende fino alla pista, gli aerei del traffico (o i pinguini) sui traguardi delle caselle. Dove c'è una virata la rotta piega e un arco mostra le inclinazioni permesse (verdi) e vietate (rosse); l'aereo si inclina con l'asse, flap e carrello si muovono sul modello. Sotto l'aereo un plinto con carrello, flap, freni, caffè, rilanci e cherosene. La plancia originale resta di fianco per piazzare i dadi; un tasto passa alla vecchia vista 2D.
- **Comandi della vista 3D**: mouse (sinistro ruota, destro sposta, rotella zoom, doppio clic centra) e tocco (un dito sposta, due dita pizzicano per lo zoom e ruotano).
- **Scelta del volo per aeroporto**: schede Gioco base, Turbolenze, Promozionali; una riga per aeroporto con i suoi voli colorati per difficoltà.
- Tutto in italiano.

## Struttura

- `scripts/motore.gd` - le regole (stato JSON puro, riproducibile con un seme)
- `scripts/ia.gd` - il compagno guidato dal computer
- `scripts/automa.gd` - le 12 carte del Copilota Automa
- `scripts/tavolo.gd` - plancia, piste e moduli disegnati con la grafica originale
- `scripts/vista3d.gd` - la vista 3D (modelli del modulo TTS in `assets/modelli/`)
- `scripts/partita.gd`, `scripts/main.gd` - partita, menu, online
- `assets/dati/piste.json` - le 54 piste di avvicinamento trascritte (aerei, dadi traffico, virate, allarmi)
- `assets/dati/scenari.json` - i voli con moduli e testi in italiano

## Prove

- `godot --headless --path . -s tests/sim.gd -- 10` - partite automatiche su tutti i voli
- `xvfb-run -a godot --path . -s tests/foto.gd -- /tmp/foto 1920 1080 atl2` - fotografie dell'interfaccia
- `python3 tools/controlla_glifi.py` - controllo dei caratteri nei font

## Pubblicazione

Solo a richiesta: Actions, Pubblica, Run workflow, oppure un commit con `[pubblica]` nel messaggio.
