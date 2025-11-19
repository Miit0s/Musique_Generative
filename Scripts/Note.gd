@icon("uid://dn4tqx7mbfmob")

extends Resource
## Classe contenant les données d'une note musicale.
##
## [member Instrument (string)] Pour quel instrument est cette note ? (ex : "drum", "synth", etc.)
## [br]
## [member Duration (float)] Durée de la note en secondes.
## [br]
## [member Soundtype (string)] Type de son (varie selon l'instrument : "sine", "square", "noise" pour un synthé, "kick", "snare" pour une batterie, etc.).
## [br]
## [member Frequency (float = 440.0)] Fréquence de la note (Hz).
## [br]
## [member Volume (float = 1.0)] Volume de la note (0.0 à 1.0).
## [br]
## Exemple d'utilisation :
##
## [code]var my_note = Note.new("synth", 0.5, 12.0, "sine", 0.8)[/code]
class_name Note

enum InstrumentEnum {
	DRUM,
	SYNTH,
	BASS
}

enum SoundTypeEnum {
	HITHAT,
	KICK,
	SNARE,
	SQUARE,
	BASS
}

@export var instrument: InstrumentEnum = InstrumentEnum.DRUM  ## [Instrument (string)] Pour quel instrument est cette note ? (ex : "drum", "synth", etc.)     
@export var duration: float = 1                               ## [Duration (float)] Durée de la note en secondes.
@export var sound_type: SoundTypeEnum = SoundTypeEnum.KICK    ## [Soundtype (string)] Type de son (varie selon l'instrument : "sine", "square", "noise" pour un synthé, "kick", "snare" pour une batterie, etc.).
@export var frequency: float = 440.0                          ## [Frequency (float = 440.0)] Fréquence de la note (Hz).      
@export var volume: float = 1.0                               ## [Volume (float = 1.0)] Volume de la note (0.0 à 1.0).

func _init(_instrument: InstrumentEnum = InstrumentEnum.DRUM, _duration: float = 1, _soundType: SoundTypeEnum = SoundTypeEnum.KICK, _frequency: float = 440.0, _volume: float = 1.0):
	instrument = _instrument
	duration = _duration
	sound_type = _soundType
	frequency = _frequency
	volume = _volume
