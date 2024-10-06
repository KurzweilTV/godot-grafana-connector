class_name EngineMetricsCollector
extends Node

# Configurable properties
@export var active: bool = true  # Toggle metrics collection
@export var game_label: String = "grafana_plugin"  # Configurable 'game' label for Grafana
@export var collection_time: float = 60.0


var timer: Timer

func _ready() -> void:
	# Set up the Timer
	timer = Timer.new()
	timer.wait_time = collection_time  # Collect metrics every 60 seconds
	timer.one_shot = false
	timer.autostart = active
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	if not active:
		return
		
	var labels = {"game": game_label}
	
	# Collect additional engine metrics using Performance monitors
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var memory_usage = Performance.get_monitor(Performance.MEMORY_STATIC)  # In bytes
	var memory_peak = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)  # In bytes
	var video_mem_used = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)  # In bytes
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var node_count = get_tree().get_node_count()
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphan_node_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	# Send additional metrics via Grafana.prometheus
	Grafana.prometheus.send_metric("godot_engine_fps", fps, labels)
	Grafana.prometheus.send_metric("godot_engine_process_time", process_time, labels)
	Grafana.prometheus.send_metric("godot_engine_physics_time", physics_time, labels)
	Grafana.prometheus.send_metric("godot_engine_memory_usage", memory_usage, labels)
	Grafana.prometheus.send_metric("godot_engine_memory_peak_usage", memory_peak, labels)
	Grafana.prometheus.send_metric("godot_engine_video_memory_used", video_mem_used, labels)
	Grafana.prometheus.send_metric("godot_engine_draw_calls", draw_calls, labels)
	Grafana.prometheus.send_metric("godot_engine_node_count", node_count, labels)
	Grafana.prometheus.send_metric("godot_engine_object_count", object_count, labels)
	Grafana.prometheus.send_metric("godot_engine_orphan_node_count", orphan_node_count, labels)

func set_active(new_active: bool) -> void:
	active = new_active
	if active:
		timer.start()
	else:
		timer.stop()
