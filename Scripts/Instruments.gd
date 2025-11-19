extends Node
class_name Instruments

@export_group("Node Link")
## (Node) Clock Node that send the message every sub_times, and give value like Fs, tempo, etc...
@export var clock: Clock
## (Node AudioStreamPlayer) Node qui joue le son généré
@export var audio_player: AudioStreamPlayer

@export_group("Buffer")
## Durée du buffer (secondes)
@export var buffer_duration: float = 1.0

@export_group("Metrique (-1 is Clock value)")
## Temps par mesure (-1 is Clock value)
@export var measure_length : int = -1
## Subdivisions par temps (-1 is Clock value)
@export var subs_div : int = -1

@export_group("Tuning (-1 is Clock value)")
## Fréquence fondamentale (-1 is Clock value)
@export var fondamental : float = -1.0

@export_group("Instruments Volumes")
## Volume du lead (entre 0.0 et 1.0)
@export_range(0, 1) var vol_lead : float = 0.3
## Volume de la basse (entre 0.0 et 1.0)
@export_range(0, 1) var vol_bass : float = 0.3

@export_group("Visualisation and Debug")
## If true, this will plot every subdiv and note
@export var metric_plot: bool = false

## Fréquence d'échantillonage du parent (48000 Hz par défaut)
@onready var fs : float = clock.fs
## Taille du buffer (1 seconde d'audio)
@onready var buffer_size : int = round(fs * buffer_duration)
## Sub div par minute du parent
@onready var sub_div_pm: float = clock.sub_div_pm
## Secondes par subdivision
@onready var s_per_sub : float = 60.0 / sub_div_pm
## Gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La) du parent
@onready var gamme : Array = clock.gamme

## Ratio de fréquence entre deux demi-tons consécutifs
var semitone_ratio : float = pow(2.0, 1.0 / 12.0)
## Note choisie dans gamme au hasard
var note: float = 0

## Buffer circulaire contenant les échantillons audio générés
var buffer: PackedFloat32Array = PackedFloat32Array()
## Handle de playback pour envoyer les échantillons audio
var playback: AudioStreamPlayback

## Subdivisions totales par mesure
var total_subs : int
## Secondes par temps
var spb : float

## [Drum_Kick, Drum_Snare, Drum_HiHat, Bass_Note, Lead_Note] Array contenant le message envoyé aux instruments
var sound_to_render: Array[Note] = [null, null, null, null, null]

## Booléen pour déterminer si la basse joue sur le temps ou pas
var bass_groove: bool = false

## Note de kick
@export var drum_kick: Note
## Note de snare
@export var drum_snare: Note
## Note de hihat
@export var drum_hihat: Note
## Note de lead
var lead_note: Note
## Note de basse
var bass_note: Note

## Indice de la subdivision actuelle normalisé sur la metrique de l'instrument
var j: int = 0

## Stoque d'un kick précalculer à ré-utiliser
var baked_kick: PackedFloat32Array
## Stoque d'un Snare précalculer à ré-utiliser
var baked_snare: PackedFloat32Array
## Stoque d'un Hithat précalculer à ré-utiliser
var baked_hihat: PackedFloat32Array

enum WaveTypeEnum {
	SINE,
	SQUARE,
	SAWTOOTH
}

func _ready():
	# Stop si l'audio player n'a pas été définie
	assert(!audio_player == null, "No AudioPlayer defined for this Instrument")
	
	# Applique la valeur de la clock si param = -1
	if measure_length == -1:
		measure_length = clock.measure_length
	if subs_div == -1:
		subs_div = clock.subs_div
	if fondamental == -1:
		fondamental = clock.fondamental
	
	# Update total_subs value
	total_subs = measure_length * subs_div
	
	lead_note = Note.new(Note.InstrumentEnum.SYNTH, s_per_sub, Note.SoundTypeEnum.SQUARE, fondamental * pow(2.0, note/12.0), randf()*vol_lead)         ## Note de lead
	bass_note = Note.new(Note.InstrumentEnum.BASS, s_per_sub*(subs_div-1), Note.SoundTypeEnum.BASS, fondamental * pow(2.0, note/12.0)/2, vol_bass)     ## Note de basse
	
	baked_kick = _create_kick(drum_kick.duration, drum_kick.volume)
	baked_snare = _create_snare(drum_snare.duration, drum_snare.volume)
	baked_hihat = _create_hithat(drum_hihat.duration, drum_hihat.volume)
	
	# Start playing the AudioPlayer, and prepare the Buffer Array
	audio_player.play()
	playback = audio_player.get_stream_playback()
	buffer.resize(buffer_size)
	buffer.fill(0.0)

#TODO: Need doc
func _create_kick(duration: float, volume: float) -> PackedFloat32Array:
	var out = lowpass_iir(add_arrays(chirp(duration, 40.0, 10.0, WaveTypeEnum.SAWTOOTH, 1.0), white_noise(duration)), 200.0)
	var out_bis = lowpass_iir(add_arrays(white_noise(duration), white_noise(duration)), 1000.0)
	var decay_result = decay(duration, 4.5)
	
	for i in range(out.size()):
		out[i] *= decay_result[i] * volume * out_bis[i]
	
	return out

#TODO: Need doc
func _create_snare(duration: float, volume: float) -> PackedFloat32Array:
	var out = white_noise(duration)
	var decay_result = decay(duration, 1.5)
	
	for i in range(out.size()):
		out[i] *= decay_result[i] * volume
	
	return out

#TODO: Need doc
func _create_hithat(duration: float, volume: float) -> PackedFloat32Array:
	var out = lowpass_iir(white_noise(duration), 10000.0)
	var decay_result = decay(duration, 16.0)
	
	for i in range(out.size()):
		out[i] *= decay_result[i] * volume
	
	return out

## Quand le node reçoit un message (array de Notes), il génère le son correspondant dans le buffer et envoie certain echantillons du buffer au player.
func receive_message(message):
	sound_to_render = [null, null, null, null, null]
	bass_note.volume = vol_bass
	
	note = message[1]
	j = message[0] % total_subs
	
	if metric_plot :
		if j == 0 :
			print("      New ",measure_length, "X", subs_div, " Measure")
		if j % subs_div == 0 :
			print("--- ", j+1,"/",total_subs, " | ", note, " semi-tone")
		else : 
			print("    ", j+1,"/",total_subs, " | ", note, " semi-tone")
	
	if int(float(j) / subs_div) % 2 == 0 and j % subs_div == 0 :
		sound_to_render[0] = drum_kick
		bass_groove = randi_range(0, 1)
		
		if !bass_groove :
			bass_note.frequency = fondamental * pow(2.0, note/12.0)/2
			sound_to_render[3] = bass_note 
	
	elif int(float(j) / subs_div) % 2 == 1 and j % subs_div == 0 :
		sound_to_render[1] = drum_snare

		if bass_groove :
			bass_note.frequency = fondamental * pow(2.0, note/12.0)/2
			sound_to_render[3] = bass_note
			
		bass_groove = randi_range(0, 1)
	
	elif j% 1 == 0:
		sound_to_render[2] = drum_hihat
	
	lead_note.frequency = fondamental * pow(2.0, note/12.0)
	lead_note.volume = randf() * vol_lead
	sound_to_render[4] = lead_note
	
	for m: Note in sound_to_render:
		if m == null: continue
		
		match m.sound_type:
			Note.SoundTypeEnum.HITHAT:
				play_baked_sound(baked_hihat, m.volume)
			Note.SoundTypeEnum.KICK:
				play_baked_sound(baked_kick, m.volume)
			Note.SoundTypeEnum.SNARE:
				play_baked_sound(baked_snare, m.volume)
			Note.SoundTypeEnum.SQUARE:
				play_squarewave(m.duration, m.frequency, m.volume)
			Note.SoundTypeEnum.BASS:
				play_bass(m.duration, m.frequency, m.volume)
	
	var frames_to_push = int(fs * s_per_sub)
	
	var stereo_data = PackedVector2Array()
	stereo_data.resize(frames_to_push)
	
	for i in range(frames_to_push):
		var sample = buffer[i]
		
		stereo_data[i] = Vector2(sample, sample)
	
	playback.push_buffer(stereo_data)
	
	buffer = rotate_array(buffer, int(fs * s_per_sub))

## Rotate (shift) to the left an array by a given integer offset, filling out-of-bounds indices with 0.0.
## [br]
## [br][param arr: Array] Input array to be rotated.
## [br][param offset: int] Number of positions to rotate the array to the left
func rotate_array(arr: PackedFloat32Array, offset: int) -> PackedFloat32Array:
	var size = arr.size()
	if offset >= size:
		arr.fill(0.0)
		return arr
	
	var result = arr.slice(offset)
	
	var padding = PackedFloat32Array()
	padding.resize(offset)
	padding.fill(0.0)
	
	result.append_array(padding)
	
	return result

## Generates a WhiteNoise array of given duration (s).
## [br]
## [br][param duration: float] Duration of the sound (seconds).
func white_noise(duration: float) -> PackedFloat32Array:
	var n = int(duration * fs)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = randf()
	return out

## Generates a sine wave of given duration (s) and frequency (Hz).
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float = 440.0] Frequency of the sine wave (Hz).
func sine_wave(duration: float, frequency: float = 440.0) -> PackedFloat32Array:
	var n = int(duration * fs)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = sin(i * 2.0 * PI * frequency / fs)       
	return out

## Generates a linear chirp from start_frequency to end_frequency over the given duration.
## [br]
## possible wavetype: "sine", "square", "sawtooth".
## [br][param duration: float] Duration of the sound (seconds).
## [br][param start_frequency: float = 50.0] Starting frequency (Hz).
## [br][param end_frequency: float = 10.0] Ending frequency (Hz).
## [br][param wave: String="sawtooth"] Waveform type between ("sine", "square", "sawtooth").
## [br][param volume: float=1.0] Amplitude multiplier (between 0.0 and 1.0).
func chirp(duration: float, start_frequency : float = 50.0, end_frequency: float = 10.0, wave: WaveTypeEnum = WaveTypeEnum.SAWTOOTH, volume: float=1.0) -> PackedFloat32Array:
	var n = int(duration * fs)
	var out = PackedFloat32Array()
	out.resize(n)
	
	match wave:
		WaveTypeEnum.SINE:
			for i in range(n):
				var t = float(i) / fs
				var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
				out[i] = sin(2.0 * PI * instantaneous_frequency * t) * volume
		WaveTypeEnum.SQUARE:
			for i in range(n):
				var t = float(i) / fs
				var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
				out[i] = sign(sin(2.0 * PI * instantaneous_frequency * t)) * volume
		WaveTypeEnum.SAWTOOTH:
			for i in range(n):
				var t = float(i) / fs
				var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
				out[i] = 2.0 * (t * instantaneous_frequency - floor(0.5 + t * instantaneous_frequency)) * volume
	return out

## Generates an exponential decay envelope going from 1 to 0 of given duration (s) and time constant tau .
## [br]
## Higher tau values produce a faster decay (tau > 0).
## [br]
## [br][param duration: float] Duration of the envelope (seconds).
## [br][param tau: float = 1.0] Time constant controlling the decay rate [b](must be tau > 0)[/b].
## [br][param revert: bool = false] If true, generates an envelope going from 0 to 1 instead.
func decay(duration: float, tau: float = 1.0, revert: bool = false) -> PackedFloat32Array:
	var n = int(duration * fs)
	var out = PackedFloat32Array()
	out.resize(n)
	
	if revert:
		for i in range(n):
			out[n-(i+1)] 	= (1 - (i+1)/float(n))**(tau)
	else:
		for i in range(n):
			out[i] 			= (1 - (i+1)/float(n))**(tau)
	return out

## Adds two numeric arrays element-wise of [b]same size[/b]
## [br]
## [br][param arr1: PackedFloat32Array] First input.
## [br][param arr2: PackedFloat32Array] Second input.
func add_arrays(arr1: PackedFloat32Array, arr2: PackedFloat32Array) -> PackedFloat32Array:
	var size: int = min(arr1.size(), arr2.size())
	var result = PackedFloat32Array()
	result.resize(size)
	for i in range(size):
		result[i] = arr1[i] + arr2[i]
	return result

## Multiplies two numeric arrays element-wise of [b]same size[/b]
## [br]
## [br][param arr1: PackedFloat32Array] First input.
## [br][param arr2: PackedFloat32Array] Second input.
func multiply_array(arr1: PackedFloat32Array, arr2: PackedFloat32Array) -> PackedFloat32Array:
	var result = PackedFloat32Array()
	for i in range(arr1.size()):
		result.append(arr1[i] * arr2[i])
	return result

## Applies a simple one-pole IIR low-pass filter to the input samples.
## [br]
## [br][param samples: PackedFloat32Array] Input of samples to be filtered.
## [br][param cutoff_hz: float] Cutoff frequency of the low-pass filter (Hz).
func lowpass_iir(samples: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	"""
		- rc = 1 / (2π * cutoff_hz)
		- dt = 1 / Fs
		- alpha = dt / (rc + dt)
		- y[n] = y[n-1] + alpha * (x[n] - y[n-1])
	"""
	var rc = 1.0 / (2.0 * PI * cutoff_hz)
	var dt = 1.0 / fs
	var alpha = dt / (rc + dt)
	
	var output = PackedFloat32Array()
	var last = samples[0]
	for s in samples:
		last = last + alpha * (s - last)
		output.append(last)
	return output

## Compute baked sound into Buffer
## [br]
## [br][param sound_data: PackedFloat32Array] Data of the sound.
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func play_baked_sound(sound_data: PackedFloat32Array, volume: float) -> void:
	var limit = min(buffer.size(), sound_data.size())
	for i in range(limit):
		buffer[i] += sound_data[i] * volume

## Compute squarewave lead sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float] Fundamental frequency (Hz).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func play_squarewave(duration: float, frequency: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(chirp(duration, frequency, frequency, WaveTypeEnum.SQUARE, 1.0), 5000.0)
	var out_bis = lowpass_iir(chirp(duration, 4.05*frequency, 4*frequency, WaveTypeEnum.SQUARE, 1.0), 5000.0)
	var decay_result = decay(duration, 2, false)

	if buffer.size() < out.size():
		for i in range(buffer.size()):
			out[i] *= decay_result[i] * volume * out_bis[i]
			buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay_result[i] * volume * out_bis[i]
			buffer[i] += out[i]

## Compute bass sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float] Fundamental frequency (Hz).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func play_bass(duration: float, frequency: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(chirp(duration, frequency, frequency, WaveTypeEnum.SAWTOOTH, 1.0), 5000.0)
	var out_bis = lowpass_iir(chirp(duration, 1.990*frequency, 2.01*frequency, WaveTypeEnum.SQUARE, 1), 5000.0)
	var decay_result = decay(duration, 1)

	if buffer.size() < out.size():
		for i in range(buffer.size()):
			out[i] *= decay_result[i] * volume * out_bis[i]
			buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay_result[i] * volume * out_bis[i]
			buffer[i] += out[i]
