class_name Testi
extends RefCounted
## Testi in italiano: abilità speciali e regole in breve.

const ABILITA := {
	"anticipazione": ["Anticipazione", "Prima di piazzare il primo dado del round, chi gioca per primo può rilanciare uno dei suoi dadi."],
	"adattamento": ["Adattamento", "Una volta per partita, ognuno di voi può girare un proprio dado sulla faccia opposta (1-6, 2-5, 3-4)."],
	"padronanza": ["Padronanza", "Se i due dadi dei Motori hanno lo stesso valore, prendete un gettone Rilancio."],
	"controllo": ["Controllo", "Se i due dadi dell'Asse hanno lo stesso valore, prendete un caffè."],
	"insieme": ["Lavorare insieme", "Una volta per round: uno di voi mette un dado su questo spazio, l'altro ne mette uno a sua volta e i due dadi tornano in mano scambiati."],
	"sincronia": ["Sincronia", "La prima volta nel round in cui ci sono dadi sia sul Carrello sia sui Flap, chi ha appena giocato tira il dado Traffico e lo piazza subito, in uno spazio di qualsiasi colore."],
}

static func regole(s: Dictionary) -> Array:
	var r := [
		["Lo scopo", "Siete Pilota (blu) e Copilota (arancione) di un aereo di linea. In 7 round dovete far scendere l'aereo dai 6000 piedi fino all'atterraggio e arrivare all'aeroporto in fondo alla pista di avvicinamento."],
		["Il round", "Ognuno tira i suoi 4 dadi di nascosto. A turno, cominciando da chi indica la pista della quota (freccia blu: Pilota, freccia arancione: Copilota), piazzate un dado alla volta sulla plancia. Mentre piazzate i dadi non potete parlare. Alla fine del round l'aereo scende di 1000 piedi."],
		["Azioni obbligatorie", "In ogni round ci devono essere un dado blu e uno arancione sull'Asse e un dado blu e uno arancione sui Motori, altrimenti l'aereo precipita."],
		["Asse", "Quando ci sono entrambi i dadi, l'aereo si inclina verso chi ha messo il dado più alto, di tanti scatti quanta è la differenza. Se l'inclinazione arriva alla X l'aereo va in vite."],
		["Motori", "La somma dei due dadi è la velocità. Fino al segnalino blu l'aereo non avanza, tra blu e arancione avanza di 1 casella, oltre l'arancione avanza di 2. Non potete entrare in una casella con aerei del traffico, né superare l'aeroporto. Le virate tra due caselle vanno affrontate con l'asse nella posizione permessa (verde)."],
		["Radio", "Il dado indica quale casella liberare: 1 la casella attuale, 2 la successiva e così via. Toglie un aereo del traffico."],
		["Carrello, Flap e Freni", "Il carrello (solo Pilota) e i flap (solo Copilota, dall'alto in basso) spostano i segnalini blu e arancione della velocità. I freni (solo Pilota: 2, poi 4, poi 6) servono solo all'atterraggio: la velocità finale deve essere minore della posizione del segnalino rosso."],
		["Concentrazione", "Un dado qualsiasi dà un caffè (massimo 3). Ogni caffè cambia di 1 il valore di un dado prima di piazzarlo (un 6 non diventa 1)."],
		["Gettoni Rilancio", "Si prendono sulle quote indicate. In qualsiasi momento del round uno di voi può usarlo: entrambi potete rilanciare i dadi che volete."],
		["Atterraggio", "All'ultimo round dovete essere sull'aeroporto, con l'aereo orizzontale, carrello tutto estratto, flap tutti estesi, nessun aereo del traffico rimasto e velocità più bassa dei freni."],
	]
	var m: Array = s.get("moduli", [])
	if m.has("cherosene"):
		r.append(["Cherosene", "Un dado qualsiasi sul cherosene consuma tanto carburante quanto il suo valore. Se a fine round non ci avete messo un dado, ne perdete 6. A -3 il carburante è finito."])
	if m.has("perdita"):
		r.append(["Perdita di cherosene", "Non potete usare lo spazio del cherosene: a ogni round perdete tanto carburante quanta è la differenza tra i dadi dei Motori, più 1."])
	if m.has("ghiaccio"):
		r.append(["Freni da ghiaccio", "Al posto dei freni normali: per attivare un freno servono due dadi dello stesso valore (uno blu sopra, uno di qualsiasi colore sotto) nello stesso round, in ordine da 2 a 5. All'atterraggio devono essere tutti attivati."])
	if m.has("vento"):
		r.append(["Vento", "Ogni volta che l'asse si inclina, anche l'aereo ruota sull'anello del vento. Il valore del vento si aggiunge alla velocità dei Motori."])
	if m.has("stagista"):
		r.append(["Tirocinante", "Un dado sul Tirocinante (con valore diverso dal gettone più vicino) vi fa prendere quel gettone, da piazzare subito come se fosse un dado (non sulla Concentrazione). Prima di atterrare deve aver finito l'addestramento: tutti i gettoni usati."])
	if m.has("tempo"):
		r.append(["Tempo reale", "Avete 60 secondi per piazzare i dadi di ogni round. Allo scadere i dadi non piazzati si perdono."])
	if m.has("allarmi"):
		r.append(["Allarmi", "Sulle caselle con la campanella si scopre un allarme: blocca un sistema dell'aereo finché non lo ripristinate con il dado del colore e del valore indicati."])
	if m.has("quota5000"):
		r.append(["Partenza a 5000 piedi", "La partita comincia già a 5000 piedi, senza il gettone Rilancio dei 6000."])
	match s.get("speciale", ""):
		"waw":
			r.append(["Atterraggio sulla pancia", "Il carrello è bloccato: non serve estrarlo. Gli allarmi sono solo Concentrazione, Flap e Radio del Copilota."])
		"ter":
			r.append(["Motori spenti", "Si plana: non ci sono dadi sui Motori, l'aereo avanza da solo di 1 casella a ogni round e ciascuno usa solo 3 dadi su 4. I freni da ghiaccio sono l'unico modo di fermarsi."])
		"nzir":
			r.append(["Pinguini", "Sulla pista di ghiaccio ci sono pinguini al posto degli aerei: si tolgono con la Radio come il traffico. Il vento qui soffia al contrario."])
	if not s.get("abilita", []).is_empty():
		for a in s["abilita"]:
			r.append(["Abilità: " + ABILITA[a][0], ABILITA[a][1]])
	return r
