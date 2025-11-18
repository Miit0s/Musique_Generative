extends Node

# Le node horloge envoie un message aux Instruments toute les "subdivision" (sub_section)
# Une metrique est définie de base dans l'horloge (mesure, et facon de compter les subdivision, ex: 4*4 ou 3*7, etc...)
# Mais chaque instrument peut avoir sa propre façon de compter les mesures pour jouer avec le décalage

## Node Instruments qui joue les notes reçues
@onready var Instrument = $Instrument

@export_group("Fréquence d'échantillonnage")
## Fréquence d'échantillonage (48000 Hz par défaut)
@export var Fs : int = 48000

## La métrique est construite de la facon suivante : 1 mesure = measure_length x temps et 1 mesure = subs_div x subdivision
## Exemple, pour les valeurs de bases, une mesure contient 4 temps, et chaque temps contient 6 subdivisions, et les subdivisions sont jouée au rythme de 400/min
@export_group("Metrique et Tempo")

## Sub div par minute
@export var sub_div_pm : float = 400
## Temps par mesure
@export var measure_length : int = 4
## Subdivisions par temps
@export var subs_div: int = 6

@export_group("Fréquence fondamentale")
## Fréquence fondamentale (La2 = 110 Hz par défaut)
@export var fondamental : float = 110.0

## Subdivisions totales par mesure
@onready var total_subs = measure_length * subs_div
## Secondes par subdivision
@onready var s_per_sub : float = 60.0 / sub_div_pm

## Gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La)
var gamme: Array = [0, 2, 4, 5, 7, 9, 11]

## Matrice de transition pondérée pour la génération de mélodies (voir chaine de markov)
var markov_weighted: Dictionary = {
	gamme[0]: {gamme[0]: 1.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré I
	gamme[1]: {gamme[0]: 2.0, gamme[1]: 1.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré II
	gamme[2]: {gamme[0]: 2.0, gamme[1]: 2.0, gamme[2]: 1.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré III
	gamme[3]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 1.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré IV
	gamme[4]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 1.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré V
	gamme[5]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 1.0, gamme[6]: 2.0},	# degré VI
	gamme[6]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 1.0},	# degré VII
}

## Note en demi-ton par rapport à la fondamentale jouée sur se temp
var prev_note = 0
## Indice de la subdivision, par de 0 à l'infini si le projet ne s'arrete pas
var iteration : int = 0
## Variable qui va accumuler le delta pour s'assurer qu'il n'y est pas de décalage même avec un spike de lag
var time_acumulator: float = 0

func _ready():
	# Normalize weights so each row sums to 1.0
	for key in markov_weighted:
		var total = 0.0
		for value in markov_weighted[key].values():
			total += value
		for note_proba in markov_weighted[key]:
			markov_weighted[key][note_proba] /= total
	'''
	for bidule in markov_weighted:
		print("From note ", bidule, " to:")

		for truc in markov_weighted[bidule]:
			print("   note ", truc, " with weight ", snapped(markov_weighted[bidule][truc], 0.01)*100, "%")
	'''

# Tout les subdivision, Horloge envoie un message aux instruments contenant l'indice de la subdivision ainsi que la note jouée
func _process(delta: float) -> void:
	time_acumulator += delta
	
	var loops = 0
	var max_loops = 10 # Max de note à jouer en une frame si lag
	
	while time_acumulator >= s_per_sub:
		time_acumulator -= s_per_sub
		
		prev_note = next_note_weighted(prev_note)
		
		Instrument.receive_message([iteration, prev_note])
		iteration = iteration + 1
		
		loops += 1
		if loops >= max_loops:
			time_acumulator = fmod(time_acumulator, s_per_sub) #Flush le retard, mais garde l'alignement
			break

## Renvoie la note suivante (en demi-tons par rapport à la fonda) en fonction de la note précédente selon une matrice de transition pondérée
## [br]
## [br][param previous_note: int] Note précédente (en demi-tons par rapport à la fondamentale).
func next_note_weighted(previous_note: int) -> int:
	if not markov_weighted.has(previous_note):
		return gamme.pick_random()
	
	var choices: Dictionary = markov_weighted[previous_note]
	var r = randf()
	var acc = 0.0
	for note in choices.keys():
		acc += choices[note]
		if r <= acc:
			return note
	return choices.keys().back()  # fallback
