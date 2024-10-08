extends Node

@onready var line_edit: LineEdit = %LineEdit
@onready var spin_box: SpinBox = %SpinBox
@onready var custom_button: Button = %CustomButton

var log_types = ["info", "warning", "error", "debug"]

func _ready() -> void:
	randomize()

func _on_test_log_pressed() -> void:
	var random_index : int = randi_range(0, 3)
	Grafana.loki.send_log("Testing Logs: This is a log line with number %d" % randi_range(0,100), log_types[random_index])


func _on_test_metric_button_pressed() -> void:
	Grafana.prometheus.send_metric("test_metric", randf_range(0, 50),{"game":"grafana_plugin"})


func _on_custom_button_pressed() -> void:
	Grafana.prometheus.send_metric(line_edit.text, spin_box.value, {"game":"grafana_plugin"})
