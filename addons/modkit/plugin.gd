@tool
extends EditorPlugin
## Registers the ModKit singletons when the plugin is enabled in a project.

const SINGLETONS := {
	"Events": "res://addons/modkit/events.gd",
	"Registry": "res://addons/modkit/registry.gd",
	"ModLoader": "res://addons/modkit/mod_loader.gd",
}


func _enter_tree() -> void:
	for name in SINGLETONS:
		if not ProjectSettings.has_setting("autoload/" + name):
			add_autoload_singleton(name, SINGLETONS[name])


func _exit_tree() -> void:
	for name in SINGLETONS:
		if ProjectSettings.has_setting("autoload/" + name):
			remove_autoload_singleton(name)
