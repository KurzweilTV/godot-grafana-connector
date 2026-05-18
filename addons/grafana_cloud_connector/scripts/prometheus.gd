class_name prometheus # Class for handling Metrics
extends Node

# Configuration

var influx_url : String = "https://<your-instance>.grafana.net>/api/v1/push/influx/write"
var influx_user_id : int = 0000000
var influx_api_key : String = 'glc...'


var game_name : String = "game_name"
var collection_time: float = 60.0
var active: bool = true  # Toggle metrics collection

###################################

var timer: Timer


var http_request : HTTPRequest = HTTPRequest.new()
var metrics: Dictionary = {}
var is_request_in_progress = false
var env: String:
	get:
		if OS.is_debug_build():
			return "dev"
		else:
			return "live"
var metric_prefix: String = "godot_"

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	# Set up the Timer
	timer = Timer.new()
	timer.wait_time = collection_time  # Collect metrics every 60 seconds
	timer.one_shot = false
	timer.autostart = active
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)


func _on_timer_timeout() -> void:
	_collect_engine_metrics()
	send_metrics()

func _collect_engine_metrics() -> void:
	var labels = {"game": game_name}
	
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

	# Store metrics in a list to be sent later
	record_gauge("engine_fps", fps, labels)
	record_gauge("engine_process_time", process_time, labels)
	record_gauge("engine_physics_time", physics_time, labels)
	record_gauge("engine_memory_usage", memory_usage, labels)
	record_gauge("engine_memory_peak_usage", memory_peak, labels)
	record_gauge("engine_video_memory_used", video_mem_used, labels)
	record_gauge("engine_draw_calls", draw_calls, labels)
	record_gauge("engine_node_count", node_count, labels)
	record_gauge("engine_object_count", object_count, labels)
	record_gauge("engine_orphan_node_count", orphan_node_count, labels)

func record_gauge(measurement_name: String, field_value: float, tags: Dictionary = {}) -> void: 	
	metrics [measurement_name] = { "field_value": field_value, "tags": tags }

func record_counter(measurement_name: String, field_value: float, tags: Dictionary = {}) -> void: 
	measurement_name = measurement_name + "_total" # Suffix for counters
	if measurement_name in metrics: 
		metrics[measurement_name]["field_value"] += field_value 
	else: 
		metrics[measurement_name] = { "field_value": field_value, "tags": tags }


	

func send_metrics() -> void:
	if metrics.is_empty():
		return

	if is_request_in_progress:
		return

	is_request_in_progress = true

	var lines = []

	var metrics_snapshot = metrics.duplicate(true)

	for measurement_name in metrics_snapshot.keys():
		var metric = metrics_snapshot[measurement_name]
		var tags = metric["tags"].duplicate(true)

		# Global labels
		tags["environment"] = env
		tags["game"] = game_name

		var tag_string = ""

		for key in tags.keys():
			tag_string += ",%s=%s" % [
				str(key),
				str(tags[key])
			]

		var line = "%s%s value=%s" % [
			metric_prefix + measurement_name,
			tag_string,
			str(metric["field_value"])
		]

		lines.append(line)

	var body = "\n".join(lines)


	var auth_str = "%s:%s" % [
		influx_user_id,
		influx_api_key
	]

	var auth_base64 = Marshalls.utf8_to_base64(auth_str)

	var headers = [
		"Authorization: Basic %s" % auth_base64,
		"Content-Type: text/plain"
	]

	var err = http_request.request(
		influx_url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		is_request_in_progress = false
		push_error(
			"Failed to send HTTP request: %s"
			% error_string(err)
		)


func _on_request_completed(result: int, response_code: int, headers, body) -> void:
	if result != OK or response_code >= 300:
		push_error(
			"Failed to send metrics: HTTP %s, Result: %s, Body: %s"
			% [response_code, result, body.get_string_from_utf8()]
		)
	is_request_in_progress = false