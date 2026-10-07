extends Node
## Tiny pooled sound player. All streams preloaded; no per-play allocation
## beyond picking an idle AudioStreamPlayer.

const SOUNDS := {
	"shoot": preload("res://audio/shoot.wav"),
	"hit": preload("res://audio/hit.wav"),
	"gem": preload("res://audio/gem.wav"),
	"levelup": preload("res://audio/levelup.wav"),
	"hurt": preload("res://audio/hurt.wav"),
	"death": preload("res://audio/death.wav"),
	"boss": preload("res://audio/boss.wav"),
	"nova": preload("res://audio/nova.wav"),
}

const VOLUMES := {
	"shoot": -14.0,
	"hit": -10.0,
	"gem": -12.0,
	"levelup": -6.0,
	"hurt": -8.0,
	"death": -6.0,
	"boss": -6.0,
	"nova": -8.0,
}

var _players: Array = []
var _cursor := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)


func play(sound_name: String) -> void:
	var stream: AudioStream = SOUNDS.get(sound_name)
	if stream == null:
		return
	# Round-robin: cheap, avoids scanning and never steals a playing voice.
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = stream
	p.volume_db = VOLUMES.get(sound_name, -8.0)
	p.play()


func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(0, m)
