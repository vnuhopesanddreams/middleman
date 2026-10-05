@tool
extends EditorPlugin

## Adds the NfcFriends Android plugin (built from android_plugin/ into bin/) to Android
## exports. Those need "Use Gradle Build" switched on in the export preset.

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return "NfcFriends"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Paths are relative to res://addons/.
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["nfc_friends/bin/nfc_friends-debug.aar"])
		return PackedStringArray(["nfc_friends/bin/nfc_friends-release.aar"])
