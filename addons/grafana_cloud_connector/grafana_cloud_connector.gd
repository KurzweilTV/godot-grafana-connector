@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Grafana"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/grafana_cloud_connector/scripts/grafana.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
