extends SceneTree
## Tiny HTTPS static server for playtesting the Web build on a phone.
## Browsers only run Godot web builds in a "secure context", so plain http://
## over Wi-Fi won't work — this serves build/web over https with a
## self-signed certificate (your phone will warn once; choose "proceed").
##
## Run:  godot --headless --path . --script res://tools/serve_web.gd -- [port]
## (or just double-click playtest_mobile.bat on Windows)

const ROOT := "res://build/web"
const CERT := "user://dev_https.crt"
const KEY := "user://dev_https.key"
const CHUNK := 65536

var _server := TCPServer.new()
var _tls_opts: TLSOptions
var _conns: Array[Dictionary] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var port := int(args[0]) if args.size() > 0 else 8443
	if not FileAccess.file_exists(ROOT + "/index.html"):
		printerr("No web build found at %s. Export the 'Web' preset first." % ROOT)
		quit(1)
		return
	_tls_opts = TLSOptions.server(_load_or_make_key(), _load_or_make_cert())
	var err := _server.listen(port, "*")
	if err != OK:
		printerr("Could not listen on port %d (error %d)." % [port, err])
		quit(1)
		return
	print("\n=== Card Sharks mobile playtest server ===")
	print("Phone and PC must be on the same Wi-Fi. Open one of these on your phone:")
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			print("   https://%s:%d" % [ip, port])
	print("The certificate is self-signed: tap 'Advanced' -> 'Proceed' (Android) or")
	print("'Show Details' -> 'visit this website' (iPhone). Ctrl+C to stop.\n")


func _process(_delta: float) -> bool:
	while _server.is_connection_available():
		var tls := StreamPeerTLS.new()
		if tls.accept_stream(_server.take_connection(), _tls_opts) == OK:
			_conns.append({"tls": tls, "req": "", "out": PackedByteArray(), "file": null, "t": Time.get_ticks_msec()})
	for c in _conns.duplicate():
		if not _step(c):
			(c["tls"] as StreamPeerTLS).disconnect_from_stream()
			_conns.erase(c)
	OS.delay_msec(2)
	return false


## Returns false when the connection is finished.
func _step(c: Dictionary) -> bool:
	var tls: StreamPeerTLS = c["tls"]
	tls.poll()
	var st := tls.get_status()
	if st == StreamPeerTLS.STATUS_HANDSHAKING:
		return Time.get_ticks_msec() - c["t"] < 10000
	if st != StreamPeerTLS.STATUS_CONNECTED:
		return false
	if c["file"] == null and c["out"].is_empty():
		var avail := tls.get_available_bytes()
		if avail > 0:
			c["req"] += tls.get_utf8_string(avail)
		if not c["req"].contains("\r\n\r\n"):
			return Time.get_ticks_msec() - c["t"] < 10000
		_prepare_response(c)
	# Send buffered header / file data.
	if c["out"].is_empty() and c["file"] != null:
		var f: FileAccess = c["file"]
		c["out"] = f.get_buffer(CHUNK)
		if f.eof_reached() or c["out"].is_empty():
			c["file"] = null
	if not c["out"].is_empty():
		var res := tls.put_partial_data(c["out"])
		if res[0] != OK:
			return false
		c["out"] = c["out"].slice(res[1])
		c["t"] = Time.get_ticks_msec()
	return not (c["out"].is_empty() and c["file"] == null) or Time.get_ticks_msec() - c["t"] < 200


func _prepare_response(c: Dictionary) -> void:
	var line: String = c["req"].get_slice("\r\n", 0)
	var path := line.get_slice(" ", 1).get_slice("?", 0).uri_decode()
	if path == "/" or path == "":
		path = "/index.html"
	var full := ROOT + path.simplify_path() if not path.contains("..") else ""
	if full == "" or not FileAccess.file_exists(full):
		c["out"] = ("HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nNot found").to_utf8_buffer()
		return
	var f := FileAccess.open(full, FileAccess.READ)
	var head := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\n" % [_mime(full), f.get_length()]
	head += "Cross-Origin-Opener-Policy: same-origin\r\nCross-Origin-Embedder-Policy: require-corp\r\nConnection: close\r\n\r\n"
	c["out"] = head.to_utf8_buffer()
	c["file"] = f
	print("  ", path)


func _mime(p: String) -> String:
	match p.get_extension():
		"html": return "text/html"
		"js": return "application/javascript"
		"wasm": return "application/wasm"
		"pck": return "application/octet-stream"
		"png": return "image/png"
		"json": return "application/json"
	return "application/octet-stream"


func _load_or_make_key() -> CryptoKey:
	var key := CryptoKey.new()
	if FileAccess.file_exists(KEY) and key.load(KEY) == OK:
		return key
	key = Crypto.new().generate_rsa(2048)
	key.save(KEY)
	return key


func _load_or_make_cert() -> X509Certificate:
	var cert := X509Certificate.new()
	if FileAccess.file_exists(CERT) and cert.load(CERT) == OK:
		return cert
	var key := CryptoKey.new()
	key.load(KEY)
	cert = Crypto.new().generate_self_signed_certificate(key, "CN=card-sharks-dev,O=Card Sharks,C=IL", "20250101000000", "20350101000000")
	cert.save(CERT)
	return cert
