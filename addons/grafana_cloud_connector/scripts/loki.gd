@tool
class_name loki 
extends Node 

@onready var http_request : HTTPRequest = HTTPRequest.new()

@export var loki_url := "https://your-loki-url/loki/api/v1/push"
@export var user_id := 00000 
@export var api_key = 'glc.......abc'

const game_name : String = "grafana_plugin"

var message_queue = []

var env: String:
	get:
		if OS.is_debug_build():
			return "dev"
		else:
			return "live"
			
var labels: Dictionary = { # default labels for every log
		"job": "godot",
		"game": game_name,
		"environment": env,
	}

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

#TIP: Grafana colors debug, info, warning, error log levels.
func send_log(log_line: String, level: String, custom_labels: Dictionary = {}) -> void:
	print("Sending log with log level %s" % level)
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
	var auth_str = "%s:%s" % [user_id, api_key]
	var auth_base64 = Marshalls.utf8_to_base64(auth_str)
	var headers = [
	"Authorization: Basic %s" % auth_base64,  # Basic Authentication
	"Content-Type: application/json"          # JSON content type
	]

	http_request.request(loki_url, headers, HTTPClient.METHOD_POST, str(payload))

# fires when the HTTP request signals it's done
func _on_request_completed(result, response_code, headers, body):
	print("Response code:", response_code)
	if response_code == 204:
		print("Log pushed to Loki successfully.")
	else:
		printerr("Failed to push log. Response:", body)
