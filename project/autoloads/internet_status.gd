# project/autoloads/internet_status.gd
class_name InternetStatus # Assuming you might want to use this as a type elsewhere
extends Node

signal has_internet
signal no_internet

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	Log.info("Internet status checker (HTTPRequest) initialized", {}, [Log.TAG_NETWORK])

func get_status() -> void:
	var error_code: Error = http_request.request("https://www.google.com/generate_204", [], HTTPClient.METHOD_GET)
	if error_code != OK:
		Log.error("Failed to start HTTPRequest for internet check", {"error_code": error_code}, [Log.TAG_NETWORK, Log.TAG_ERROR])
		no_internet.emit()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		Log.info("Internet check successful (HTTP %s)" % response_code, {}, [Log.TAG_NETWORK])
		has_internet.emit()
	else:
		Log.warning("Internet check failed", {"result": result, "response_code": response_code}, [Log.TAG_NETWORK, Log.TAG_ERROR])
		no_internet.emit()
