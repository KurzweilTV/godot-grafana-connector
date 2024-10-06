@tool
class_name loki # Class for handling Logs
extends Node

# Configuration
var loki_url : String = "https://<grafana-provided-url>.grafana.net/loki/api/v1/push"
var loki_user_id : int = 000000
var loki_api_key : String = 'glc...'
const game_name : String = "grafana_plugin"

###################################

@onready var http_request: HTTPRequest = HTTPRequest.new()

var message_queue = []
var is_request_in_progress = false

var env: String:
	get:
		if OS.is_debug_build():
			return "dev"
		else:
			return "live"

var labels: Dictionary = {  # default labels for every log
	"job": "godot",
	"game": game_name,
	"environment": env,
}

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# TIP: Grafana colors debug, info, warning, error log levels.
func send_log(log_line: String, level: String, custom_labels: Dictionary = {}) -> void:
	# Add the log message to the queue
	message_queue.append({
		"log_line": log_line,
		"level": level,
		"custom_labels": custom_labels
	})
	# Start processing the queue if not already in progress
	if not is_request_in_progress:
		_process_next_log()

func _process_next_log() -> void:
	if message_queue.is_empty():
		is_request_in_progress = false
		return
	is_request_in_progress = true
	var message = message_queue.pop_front()

	var log_line = message["log_line"]
	var level = message["level"]
	var custom_labels = message["custom_labels"]

	var timestamp = Time.get_unix_time_from_system() * 1000000000
	var values = [[str(timestamp), log_line]]
	var level_dict = {"level": level}

	# Create a new labels dictionary for this log
	var current_labels = labels.duplicate()
	current_labels.merge(level_dict)
	current_labels.merge(custom_labels)

	var payload = {
		"streams": [
			{
				"stream": current_labels,
				"values": values
			}
		]
	}

	# Encode the user_id and api_key for Basic Authentication
	var auth_str = "%s:%s" % [loki_user_id, loki_api_key]
	var auth_base64 = Marshalls.utf8_to_base64(auth_str)
	var headers = [
		"Authorization: Basic %s" % auth_base64,  # Basic Authentication
		"Content-Type: application/json"          # JSON content type
	]

	# Send the request
	var err = http_request.request(loki_url, headers, HTTPClient.METHOD_POST, str(payload))
	if err != OK:
		push_error("Failed to send HTTP request: %s" % err)
		is_request_in_progress = false
		_process_next_log()  # Proceed to next log even if there's an error

# Fires when the HTTP request signals it's done
func _on_request_completed(result: int, response_code: int, headers, body) -> void:
	if response_code != 204:
		printerr("Failed to push log. Response:", body)
	is_request_in_progress = false
	_process_next_log()
