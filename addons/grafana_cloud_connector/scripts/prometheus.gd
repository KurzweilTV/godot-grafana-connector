@tool
class_name prometheus
extends Node

@export var url = "https://your-prometheus-url/api/v1/push/influx/write"
@export var user_id = 000000
@export var api_key = 'glc.....abc'

var http_request : HTTPRequest = HTTPRequest.new()
var metric_queue = []
var is_request_in_progress = false

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func send_metric(measurement_name: String, field_value: float, tags: Dictionary = {}) -> void:
	# Add the metric to the queue
	metric_queue.append({
		"measurement_name": measurement_name,
		"field_key": "value",
		"field_value": field_value,
		"tags": tags
	})
	# Start processing the queue if not already in progress
	if not is_request_in_progress:
		_process_next_metric()

func _process_next_metric():
	if metric_queue.is_empty():
		is_request_in_progress = false
		return
	is_request_in_progress = true
	var metric = metric_queue.pop_front()
	
	# (Reusing existing http_request node)
	# Build the tag string
	var tag_string = ""
	for key in metric.tags.keys():
		tag_string += ",%s=%s" % [key, metric.tags[key]]
	
	# Construct the body
	var body = "%s%s %s=%s" % [metric.measurement_name, tag_string, metric.field_key, str(metric.field_value)]
	
	# Prepare headers
	var auth_str = "%s:%s" % [user_id, api_key]
	var auth_base64 = Marshalls.utf8_to_base64(auth_str)
	var headers = [
		"Authorization: Basic %s" % auth_base64,
		"Content-Type: text/plain"
	]
	
	# Send the request
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if err != OK:
		push_error("Failed to send HTTP request: %s" % err)
		is_request_in_progress = false
		_process_next_metric()  # Proceed to next metric even if there's an error

func _on_request_completed(result: int, response_code: int, headers, body) -> void:
	print("Response code: ", response_code)
	is_request_in_progress = false
	_process_next_metric()
