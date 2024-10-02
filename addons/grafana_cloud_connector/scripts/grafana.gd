extends Node

var loki : loki = preload("res://addons/grafana_cloud_connector/scenes/loki.tscn").instantiate()
var prometheus : prometheus = preload("res://addons/grafana_cloud_connector/scenes/prometheus.tscn").instantiate()

func _ready() -> void:
	add_child(loki)
	add_child(prometheus)
