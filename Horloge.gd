extends Node2D

@onready var Instruments = $Instruments						## Node Instruments qui joue les notes reçues
const MyData = preload("res://Note.gd")

@export_group("Fréquence d'échantillonnage")
@export var Fs : int = 48000								## Fréquence d'échantillonage (48000 Hz par défaut)


##### Valeurs à changer pour modifier le rythme #####
@export_group("Metrique et Tempo")
@export var bpm : int = 80  								## Tempo en battements par minute
@export var measure_length : int = 4						## Temps par mesure
@export var subs_div: int = 6								## Subdivisions par temps

var total_subs = measure_length * subs_div		## subdivisions totales par mesure

var spb = 60.0 / bpm							## secondes par temps
var s_per_sub = spb / subs_div					## secondes par subdivision

@export_group("Fréquence fondamentale")
@export var fondamental : float = 110.0			## Fréquence fondamentale (La2 = 110 Hz par défaut)

@export_group("Volumes des instruments")
@export var vol_drum_kick : float = 0.8			## Volume du kick (entre 0.0 et 1.0)
@export var vol_drum_snare : float = 0.4		## Volume de la snare (entre 0.0 et 1.0)
@export var vol_drum_hihat : float = 0.3		## Volume du hihat (entre 0.0 et 1.0)
@export var vol_lead : float = 0.3				## Volume du lead (entre 0.0 et 1.0)
@export var vol_bass : float = 0.3				## Volume de la basse (entre 0.0 et 1.0)

var semitone_ratio = pow(2.0, 1.0 / 12.0)		## ratio de fréquence entre deux demi-tons consécutifs

var gamme = [0, 2, 3, 5, 7, 8, 10]				## gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La)
var note = 0									## note choisie dans gamme au hasard

var markov_weighted = {							## Matrice de transition pondérée pour la génération de mélodies (voir chaine de markov)
	gamme[0]: {gamme[0]: 1.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré I
	gamme[1]: {gamme[0]: 2.0, gamme[1]: 1.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré II
	gamme[2]: {gamme[0]: 2.0, gamme[1]: 2.0, gamme[2]: 1.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré III
	gamme[3]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 1.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré IV
	gamme[4]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 1.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré V
	gamme[5]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 1.0, gamme[6]: 2.0},	# degré VI
	gamme[6]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 1.0},	# degré VII
}												



var message = [null, null, null, null, null]	## [Drum_Kick, Drum_Snare, Drum_HiHat, Bass_Note, Lead_Note] Array contenant le message envoyé aux instruments

func _ready():

	var Drum_Kick = Note.new("Drum", 0.4, "Kick", 440.0, vol_drum_kick)													## Note de kick
	var Drum_Snare = Note.new("Drum", 0.15, "Snare", 440.0, vol_drum_snare)												## Note de snare
	var Drum_HiHat = Note.new("Drum", 0.4, "HiHat", 440.0, vol_drum_hihat)												## Note de hihat

	var Lead_Note = Note.new("Synth", s_per_sub, "Square", fondamental * pow(2.0, note/12.0), randf()*vol_lead)			## Note de lead

	var Bass_Note = Note.new("Bass", s_per_sub*(subs_div-1), "Bass", fondamental * pow(2.0, note/12.0)/2, vol_bass)		## Note de basse
	var Bass_Groove = false																								## Booléen pour déterminer si la basse joue sur le temps ou pas

	# Normalize weights so each row sums to 1.0
	for key in markov_weighted:
		var total = 0.0
		for value in markov_weighted[key].values():
			total += value
		for note_proba in markov_weighted[key]:
			markov_weighted[key][note_proba] /= total

	for bidule in markov_weighted:
		print("From note ", bidule, " to:")

		for truc in markov_weighted[bidule]:
			print("   note ", truc, " with weight ", snapped(markov_weighted[bidule][truc], 0.01)*100, "%")




	await get_tree().create_timer(1.0).timeout

	while true:		
		print("###### Nouvelle mesure ",measure_length, " X ",subs_div ," ######")		
		for j in range(total_subs):	
			
			# note = gamme.pick_random() + 12 * int(randi_range(0, 1))
			
			message = [null, null, null, null, null]
			Drum_Kick.Volume = vol_drum_kick
			Drum_Snare.Volume = vol_drum_snare
			Drum_HiHat.Volume = vol_drum_hihat
			Bass_Note.Volume = vol_bass
			note = next_note_weighted(note)


			if j % subs_div == 0:
				print("- Temps ",(1+j / subs_div), " | Subdiv ", 1+j % subs_div)
			else:
				print("  Temps ",(1+j / subs_div), " | Subdiv ", 1+j % subs_div)
				
			if (j / subs_div) % 2 == 0 and j % subs_div == 0 :	
				message[0] = Drum_Kick

				Bass_Groove = randi_range(0, 1)
				if !Bass_Groove :
					Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
					message[3] = Bass_Note 

			elif (j / subs_div) % 2 == 1 and j % subs_div == 0 :
				message[1] = Drum_Snare

				if Bass_Groove :
					Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
					message[3] = Bass_Note

				Bass_Groove = round(randf_range(0, 3)/3)

			if j% 1 == 0:
				message[2] = Drum_HiHat
			

			Lead_Note.Frequency = fondamental * pow(2.0, note/12.0)
			Lead_Note.Volume = randf()*vol_lead
			message[4] = Lead_Note

			Instruments.receive_message(message)

			await get_tree().create_timer(s_per_sub).timeout
			
			

			
## Renvoie la note suivante (en demi-tons par rapport à la fonda) en fonction de la note précédente selon une matrice de transition pondérée
## [br]
## [br][param prev_note: int] Note précédente (en demi-tons par rapport à la fondamentale).
func next_note_weighted(prev_note: int) -> int:			
	if not markov_weighted.has(prev_note):
		return gamme.pick_random()
	
	var choices = markov_weighted[prev_note]
	var r = randf()
	var acc = 0.0
	for note in choices.keys():
		acc += choices[note]
		if r <= acc:
			return note
	return choices.keys().back()  # fallback

			

			
		
		
