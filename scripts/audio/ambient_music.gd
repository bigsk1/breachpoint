class_name AmbientMusic
extends AudioStreamPlayer

const MIX_RATE := 22050
const DURATION_SECONDS := 16.0

func configure(style := "bank") -> void:
	name = "OperationBackgroundMusic"
	bus = &"Music"
	# The generated waveform is intentionally gentle, so attenuation belongs on
	# the dedicated Music bus instead of making the source nearly inaudible.
	volume_db = -2.0
	stream = _build_stream(style)
	autoplay = true

func _build_stream(style: String) -> AudioStreamWAV:
	var chords: Array = [
		[130.81, 164.81, 196.00, 246.94],
		[110.00, 146.83, 174.61, 220.00],
		[146.83, 174.61, 220.00, 261.63],
		[98.00, 123.47, 146.83, 196.00],
	]
	var melody: Array = [523.25, 587.33, 659.25, 587.33, 493.88, 440.00, 392.00, 440.00, 523.25, 659.25, 698.46, 659.25, 587.33, 493.88, 440.00, 392.00]
	if style == "museum":
		chords = [
			[146.83, 185.00, 220.00, 277.18],
			[123.47, 164.81, 196.00, 246.94],
			[164.81, 196.00, 246.94, 293.66],
			[110.00, 146.83, 185.00, 220.00],
		]
		melody = [587.33, 659.25, 739.99, 659.25, 554.37, 493.88, 440.00, 493.88, 587.33, 739.99, 783.99, 739.99, 659.25, 554.37, 493.88, 440.00]
	elif style == "gas_station":
		chords = [
			[110.00, 138.59, 164.81, 220.00],
			[98.00, 130.81, 164.81, 196.00],
			[123.47, 146.83, 185.00, 246.94],
			[92.50, 123.47, 146.83, 185.00],
		]
		melody = [440.00, 493.88, 523.25, 493.88, 392.00, 440.00, 349.23, 392.00, 440.00, 523.25, 587.33, 523.25, 493.88, 440.00, 392.00, 349.23]
	elif style == "pawn_shop":
		chords = [
			[130.81, 155.56, 196.00, 233.08],
			[116.54, 146.83, 174.61, 220.00],
			[138.59, 164.81, 207.65, 246.94],
			[103.83, 130.81, 155.56, 207.65],
		]
		melody = [523.25, 622.25, 659.25, 622.25, 466.16, 523.25, 415.30, 466.16, 523.25, 659.25, 698.46, 659.25, 622.25, 523.25, 466.16, 415.30]
	elif style == "zombie_island":
		chords = [
			[73.42, 92.50, 110.00, 138.59],
			[65.41, 82.41, 98.00, 123.47],
			[69.30, 87.31, 103.83, 130.81],
			[61.74, 77.78, 92.50, 116.54],
		]
		melody = [293.66, 311.13, 349.23, 311.13, 277.18, 246.94, 233.08, 246.94, 293.66, 349.23, 369.99, 349.23, 311.13, 277.18, 246.94, 233.08]
	var frame_count := int(MIX_RATE * DURATION_SECONDS)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 4)
	for frame in frame_count:
		var t := float(frame) / float(MIX_RATE)
		var chord: Array = chords[int(t / 4.0) % chords.size()]
		var sample := sin(TAU * float(chord[0]) * 0.5 * t) * 0.045
		for frequency_value in chord:
			var frequency := float(frequency_value)
			sample += sin(TAU * frequency * t) * (0.018 + 0.003 * sin(TAU * 0.16 * t))
		var beat_phase := fmod(t, 1.0)
		var note := float(melody[int(t) % melody.size()])
		sample += sin(TAU * note * t) * exp(-4.8 * beat_phase) * 0.027
		var fade := minf(1.0, minf(t * 2.0, (DURATION_SECONDS - t) * 2.0))
		var value := clampi(roundi(sample * fade * 32767.0), -32768, 32767)
		pcm.encode_s16(frame * 4, value)
		pcm.encode_s16(frame * 4 + 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = true
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frame_count
	return wav
