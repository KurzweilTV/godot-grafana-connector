@tool
extends EditorPlugin

const GRAFANA_SCRIPT = "Grafana"

func _enter_tree():
	add_autoload_singleton(GRAFANA_SCRIPT, "res://addons/grafana_cloud_connector/scripts/grafana.gd")

func _exit_tree():
	remove_autoload_singleton(GRAFANA_SCRIPT)
