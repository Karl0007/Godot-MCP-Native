class_name McpHttpServer
extends McpTransportBase

# HTTP 传输实现 - 支持 JSON-RPC over HTTP
# 符合 MCP 2025-03-26 规范（Streamable HTTP）
# 使用 Godot TCPServer 实现 HTTP 服务器

# ==============================================================================
# 信号继承自 McpTransportBase（不要在此重新定义，避免遮蔽父类信号）
# - message_received(message: Dictionary, context: Variant)
# - server_error(error: String)
# - server_started()
# - server_stopped()
# ==============================================================================


# ==============================================================================
# 常量
# ==============================================================================

## 最大请求大小（1MB）
const MAX_REQUEST_SIZE: int = 1024 * 1024

## 请求超时时间（30秒）
const REQUEST_TIMEOUT: float = 30.0

## HTTP 认证头名称
const AUTH_HEADER: String = "authorization"

## Bearer 认证方案
const AUTH_SCHEME: String = "Bearer"


# ==============================================================================
# 状态变量（带类型提示 - 根据 godot-dev-guide）
# ==============================================================================

## TCP 服务器实例
var _tcp_server: TCPServer = null

## 监听端口
var _port: int = 9080

## 是否正在运行
var _active: bool = false

## 主循环帧泵（HTTP 服务完全跑在主线程上，见 _connect_frame_pump）
var _frame_tree: SceneTree = null

## 每连接已收字节（非阻塞累积，凑齐整请求才处理）
var _pending_requests: Dictionary = {}  # peer -> PackedByteArray

## 每连接收到首字节的时刻（REQUEST_TIMEOUT 判据）
var _request_started_ms: Dictionary = {}  # peer -> int

## SSE 心跳计时
var _last_keepalive_ms: int = 0

## 活跃连接列表
var _connections: Array[StreamPeerTCP] = []

## SSE 连接列表（保持打开的连接）
var _sse_connections: Dictionary = {}  # peer -> session_id

## 认证管理器
var _auth_manager: McpAuthManager = null

## 会话管理
var _sessions: Dictionary = {}  # session_id -> session_data

## 远程访问配置
var _allow_remote: bool = false
var _cors_origin: String = "*"


## 日志回调函数（由 McpServerCore 设置，用于替代 printerr）
var _log_callback: Callable = Callable()


# ==============================================================================
# McpTransportBase 接口实现
# ==============================================================================

## 设置端口
## @param port: int - 监听端口
func set_port(port: int) -> void:
	if _active:
		push_error("Cannot change port while server is running")
		return
	_port = port

## 设置日志回调
## @param callback: Callable - 日志回调函数，接受 level (String) 和 message (String) 参数
func set_log_callback(callback: Callable) -> void:
	_log_callback = callback

## 设置认证管理器
## @param manager: RefCounted - 认证管理器实例（与父类签名一致）
func set_auth_manager(manager: RefCounted) -> void:
	_auth_manager = manager as McpAuthManager

## 启动 HTTP 服务器
## @returns: bool - 启动成功返回 true，失败返回 false
func start() -> bool:
	var conflict_info: String = _check_port_conflict(_port)
	if not conflict_info.is_empty():
		var error_msg: String = "Port " + str(_port) + " is already in use! " + conflict_info + " Please change the port in MCP settings or close the conflicting application."
		server_error.emit(error_msg)
		if _log_callback.is_valid():
			_log_callback.call("ERROR", error_msg)
		push_error(error_msg)
		return false
	
	_tcp_server = TCPServer.new()
	
	var error: Error = _tcp_server.listen(_port)
	if error != OK:
		var error_msg: String = "Failed to listen on port " + str(_port) + ": " + str(error)
		server_error.emit(error_msg)
		if _log_callback.is_valid():
			_log_callback.call("ERROR", error_msg)
		return false
	
	_active = true
	_last_keepalive_ms = Time.get_ticks_msec()
	_connect_frame_pump()
	
	server_started.emit()
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Server started on port " + str(_port))
	
	return true

func _check_port_conflict(port: int) -> String:
	var os_name: String = OS.get_name()
	if os_name == "Windows":
		return _check_port_conflict_windows(port)
	elif os_name == "Linux" or os_name == "FreeBSD":
		return _check_port_conflict_linux(port)
	elif os_name == "macOS":
		return _check_port_conflict_macos(port)
	return ""

func _check_port_conflict_windows(port: int) -> String:
	var output: Array = []
	var exit_code: int = OS.execute("netstat", ["-ano"], output)
	if exit_code != OK or output.is_empty():
		return ""
	var port_str: String = ":" + str(port) + " "
	var lines: PackedStringArray = output[0].split("\n")
	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.find(port_str) >= 0 and stripped.find("LISTENING") >= 0:
			var parts: PackedStringArray = stripped.split(" ", false)
			var pid: String = ""
			if parts.size() >= 5:
				pid = parts[parts.size() - 1]
			if pid.is_empty() or not pid.is_valid_int():
				continue
			var proc_output: Array = []
			var proc_exit: int = OS.execute("tasklist", ["/FI", "PID eq " + pid, "/FO", "CSV", "/NH"], proc_output)
			if proc_exit == OK and not proc_output.is_empty():
				var proc_line: String = proc_output[0].strip_edges().replace("\"", "")
				if proc_line.find("INFO:") >= 0:
					return "(PID " + pid + ")"
				var proc_parts: PackedStringArray = proc_line.split(",")
				if proc_parts.size() >= 2:
					var proc_name: String = proc_parts[0]
					return "(PID " + pid + ", process: " + proc_name + ")"
			return "(PID " + pid + ")"
	return ""

func _check_port_conflict_linux(port: int) -> String:
	var output: Array = []
	var exit_code: int = OS.execute("ss", ["-tlnp"], output)
	if exit_code != OK or output.is_empty():
		exit_code = OS.execute("netstat", ["-tlnp"], output)
		if exit_code != OK or output.is_empty():
			return ""
	var port_str: String = ":" + str(port)
	var lines: PackedStringArray = output[0].split("\n")
	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.find(port_str) >= 0 and stripped.find("LISTEN") >= 0:
			var pid_start: int = stripped.find("pid=")
			if pid_start >= 0:
				var pid_section: String = stripped.substr(pid_start + 4)
				var pid_end: int = pid_section.find(",")
				if pid_end < 0:
					pid_end = pid_section.find(")")
				var pid: String = pid_section.substr(0, pid_end) if pid_end >= 0 else pid_section
				if pid.is_valid_int():
					return _resolve_process_name_linux(pid)
			return ""
	return ""

func _check_port_conflict_macos(port: int) -> String:
	var output: Array = []
	var exit_code: int = OS.execute("lsof", ["-i", ":" + str(port), "-sTCP:LISTEN", "-P", "-n"], output)
	if exit_code != OK or output.is_empty():
		return ""
	var lines: PackedStringArray = output[0].split("\n")
	if lines.size() >= 2:
		var parts: PackedStringArray = lines[1].strip_edges().split(" ", false)
		if parts.size() >= 2:
			var proc_name: String = parts[0]
			var pid: String = parts[1]
			if pid.is_valid_int():
				return "(PID " + pid + ", process: " + proc_name + ")"
			return "(PID " + pid + ")"
	return ""

func _resolve_process_name_linux(pid: String) -> String:
	var proc_output: Array = []
	var proc_exit: int = OS.execute("ps", ["-p", pid, "-o", "comm=", "--no-headers"], proc_output)
	if proc_exit == OK and not proc_output.is_empty():
		var proc_name: String = proc_output[0].strip_edges()
		if not proc_name.is_empty():
			return "(PID " + pid + ", process: " + proc_name + ")"
	return "(PID " + pid + ")"

## 停止 HTTP 服务器
func stop() -> void:
	_active = false
	
	# 停止 TCP 服务器（不再接受新连接）
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null
	
	# 先摘掉帧泵，再动共享数据（此时不会再有轮询进到这些容器）
	_disconnect_frame_pump()
	
	for peer in _connections:
		if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
	
	_connections.clear()
	_pending_requests.clear()
	_request_started_ms.clear()
	_cleanup_all_sse_connections()
	
	server_stopped.emit()
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Server stopped")

## 检查传输层是否正在运行
## @returns: bool - 运行中返回 true，否则返回 false
func is_running() -> bool:
	return _active and _tcp_server != null and _tcp_server.is_listening()


# ==============================================================================
# HTTP 服务器核心逻辑
# ==============================================================================

## 把 HTTP 轮询挂到主循环的每帧信号上。
## 必须在主线程：轮询会回调 GDScript（日志回调/信号/工具执行）并读写共享容器，
## 交给工作线程并发跑同一批脚本对象会在 4.7.x 上 AV（godot.exe 内 0xC0000005）。
func _connect_frame_pump() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		_frame_tree = loop as SceneTree
		if not _frame_tree.process_frame.is_connected(_poll_http_server):
			_frame_tree.process_frame.connect(_poll_http_server)
		if _log_callback.is_valid():
			_log_callback.call("INFO", "HTTP frame pump connected to main loop")
	else:
		if _log_callback.is_valid():
			_log_callback.call("ERROR", "HTTP frame pump needs a SceneTree main loop")


func _disconnect_frame_pump() -> void:
	if _frame_tree and _frame_tree.process_frame.is_connected(_poll_http_server):
		_frame_tree.process_frame.disconnect(_poll_http_server)
	_frame_tree = null


## 每帧一轮：接新连接、收已到字节、发 SSE 心跳。整条路径全在主线程上。
func _poll_http_server() -> void:
	if not _active:
		return
	if not _tcp_server:
		_active = false
		_disconnect_frame_pump()
		return
	
	# 检查新连接
	if _tcp_server.is_connection_available():
		var peer: StreamPeerTCP = _tcp_server.take_connection()
		if peer:
			_connections.append(peer)
			if _log_callback.is_valid():
				_log_callback.call("INFO", "New connection: " + str(peer.get_status()))
	
	# 处理所有活跃连接（复制一份避免迭代中被改）
	var disconnected: Array[StreamPeerTCP] = []
	for p in _connections.duplicate():
		if not _active:
			break
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			disconnected.append(p)
			if _sse_connections.has(p):
				_close_sse_connection(p)
			continue
		
		if p.get_available_bytes() > 0:
			_read_peer_request(p)
	
	# 移除已断开的连接
	var now: int = Time.get_ticks_msec()
	for d in disconnected:
		_connections.erase(d)
		_pending_requests.erase(d)
		_request_started_ms.erase(d)
	
	# 收了一半的请求按 REQUEST_TIMEOUT 判超时（没有后续字节也要判，否则半开连接会一直留着）
	for waiting_peer in _request_started_ms.keys():
		if not _active:
			break
		if now - int(_request_started_ms[waiting_peer]) > int(REQUEST_TIMEOUT * 1000.0):
			_pending_requests.erase(waiting_peer)
			_request_started_ms.erase(waiting_peer)
			_connections.erase(waiting_peer)
			_send_http_error(waiting_peer, 408, "Request timeout. Please ensure the request is sent completely within " + str(REQUEST_TIMEOUT) + " seconds.")
	
	# 处理 SSE 连接的心跳
	if now - _last_keepalive_ms > 30000:
		_send_sse_keepalive()
		_last_keepalive_ms = now

## 发送 SSE 心跳
func _send_sse_keepalive() -> void:
	var disconnected_peers: Array[StreamPeerTCP] = []
	
	for peer in _sse_connections.keys():
		var message: String = ": keepalive\r\n\r\n"
		var error: Error = peer.put_data(message.to_utf8_buffer())
		
		if error != OK:
			if _log_callback.is_valid():
				_log_callback.call("WARN", "Failed to send keepalive, closing connection")
			disconnected_peers.append(peer)
	
	# 清理断开的连接
	for peer in disconnected_peers:
		_close_sse_connection(peer)

## 清理所有 SSE 连接
func _cleanup_all_sse_connections() -> void:
	var peers: Array = _sse_connections.keys()
	for peer in peers:
		_close_sse_connection(peer)
	
	_sse_connections.clear()
	_sessions.clear()
	
	if _log_callback.is_valid():
		_log_callback.call("INFO", "All SSE connections cleaned up")

## 收一帧已到的字节并累积；凑齐完整请求才交出去处理。
## 非阻塞：主线程上不能等（等待会冻结编辑器）。
## @param peer: StreamPeerTCP - 客户端连接
func _read_peer_request(peer: StreamPeerTCP) -> void:
	var available: int = peer.get_available_bytes()
	if available <= 0:
		return
	var chunk: PackedByteArray = peer.get_data(available)[1]
	if chunk.is_empty():
		return
	
	if not _pending_requests.has(peer):
		_pending_requests[peer] = PackedByteArray()
		_request_started_ms[peer] = Time.get_ticks_msec()
	var buffer: PackedByteArray = _pending_requests[peer]
	buffer.append_array(chunk)
	_pending_requests[peer] = buffer
	
	if buffer.size() > MAX_REQUEST_SIZE:
		_pending_requests.erase(peer)
		_request_started_ms.erase(peer)
		_connections.erase(peer)
		_send_http_error(peer, 413, "Request too large. Maximum size is " + str(MAX_REQUEST_SIZE / 1024) + "KB")
		return
	
	var request: String = _complete_request_or_empty(buffer)
	if request.is_empty():
		return
	_pending_requests.erase(peer)
	_request_started_ms.erase(peer)
	_handle_http_request(peer, request)


## 累积字节里是否有完整请求（头部结束 + body 达 Content-Length）。不完整返回 ""。
## 按字节判界：分帧收字节时字符串解码会在多字节字符中间断开。
## @param buffer: PackedByteArray - 该连接已累积的字节
## @returns: String - 完整请求文本，未收完则为 ""
func _complete_request_or_empty(buffer: PackedByteArray) -> String:
	var header_end: int = _header_end_offset(buffer)
	if header_end < 0:
		return ""
	
	var content_length: int = -1
	for line in buffer.slice(0, header_end).get_string_from_utf8().split("\r\n"):
		var lower_line: String = line.to_lower()
		if lower_line.begins_with("content-length:"):
			content_length = line.substr(15).strip_edges().to_int()
			break
	
	if content_length >= 0 and buffer.size() - header_end < content_length:
		return ""
	return buffer.get_string_from_utf8()


## 头部结束位置（"\r\n\r\n" 之后的字节偏移）；未找到返回 -1。
## @param buffer: PackedByteArray - 该连接已累积的字节
## @returns: int - body 起始字节偏移，或 -1
func _header_end_offset(buffer: PackedByteArray) -> int:
	var size: int = buffer.size()
	var i: int = 0
	while i + 3 < size:
		if buffer[i] == 13 and buffer[i + 1] == 10 and buffer[i + 2] == 13 and buffer[i + 3] == 10:
			return i + 4
		i += 1
	return -1


## 处理完整 HTTP 请求
## @param peer: StreamPeerTCP - 客户端连接
## @param request: String - 完整请求文本
func _handle_http_request(peer: StreamPeerTCP, request: String) -> void:
	if request.is_empty():
		return
	
	# 解析 HTTP 请求
	var parsed: Dictionary = _parse_http_request(request)
	
	# 检查认证（如果启用了认证）
	if _auth_manager and not _auth_manager.validate_request(parsed["headers"]):
		_send_http_error(peer, 401, "Unauthorized. Please provide a valid Bearer token in the Authorization header.")
		return
	
	# 路由请求
	match parsed["method"]:
		"POST":
			_handle_post_request(peer, parsed)
		"GET":
			_handle_get_request(peer, parsed)
		"OPTIONS":
			_handle_options_request(peer, parsed)
		_:
			_send_http_error(peer, 405, "Method not allowed. Only POST, GET, and OPTIONS are supported.")

## 解析 HTTP 请求
## @param raw: String - 原始 HTTP 请求字符串
## @returns: Dictionary - 解析后的请求信息（method, path, headers, body）
func _parse_http_request(raw: String) -> Dictionary:
	var lines: PackedStringArray = raw.split("\r\n")
	var request_line: PackedStringArray = lines[0].split(" ")
	
	var method: String = request_line[0]
	var path: String = request_line[1]
	var version: String = request_line[2] if request_line.size() > 2 else "HTTP/1.1"
	
	# 解析头部
	var headers: Dictionary = {}
	var body_start: int = -1
	
	for i in range(1, lines.size()):
		if lines[i].is_empty():
			body_start = i + 1
			break
		
		var colon_pos: int = lines[i].find(":")
		if colon_pos > 0:
			var header_name: String = lines[i].left(colon_pos).to_lower()
			var header_value: String = lines[i].substr(colon_pos + 1).strip_edges()
			headers[header_name] = header_value
	
	# 提取正文
	var body: String = ""
	if body_start != -1 and body_start < lines.size():
		var body_parts: PackedStringArray = []
		for i in range(body_start, lines.size()):
			body_parts.append(lines[i])
		body = "\r\n".join(body_parts)
	
	return {
		"method": method,
		"path": path,
		"version": version,
		"headers": headers,
		"body": body
	}

## 处理 POST 请求（JSON-RPC over HTTP）
## @param peer: StreamPeerTCP - 客户端连接
## @param parsed: Dictionary - 解析后的 HTTP 请求
func _handle_post_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	# 检查路径
	if parsed["path"] != "/mcp" and parsed["path"] != "/":
		_send_http_error(peer, 404, "Not found. Please use path '/mcp' for MCP requests.")
		return
	
	var content_type: String = parsed["headers"].get("content-type", "")
	var body: String = parsed["body"]
	
	if not body.is_empty() and not content_type.contains("application/json"):
		_send_http_error(peer, 415, "Unsupported media type. Please use 'Content-Type: application/json'.")
		return
	
	if body.is_empty():
		_send_http_error(peer, 400, "Empty request body")
		return
	
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(body)
	
	if parse_error != OK:
		_send_http_error(peer, 400, "Invalid JSON: " + json.get_error_message())
		return
	
	var message: Dictionary = json.get_data()
	
	var is_notification: bool = not message.has("id")
	
	call_deferred("_emit_message_received", message, peer)
	
	if is_notification:
		_send_http_accepted(peer)

## 处理 GET 请求（SSE 或健康检查）
## @param peer: StreamPeerTCP - 客户端连接
## @param parsed: Dictionary - 解析后的 HTTP 请求
func _handle_get_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	# 检查是否是 SSE 请求
	if parsed["headers"].get("accept", "") == "text/event-stream":
		_handle_sse_request(peer, parsed)
		return
	
	# 普通 GET 请求，返回服务器信息
	var info: Dictionary = {
		"name": "Godot MCP Native",
		"version": "1.0.0",
		"transport": "http",
		"protocol": "MCP 2025-03-26",
		"endpoints": {
			"mcp": "/mcp (POST)",
			"sse": "/mcp (GET, SSE)"
		}
	}
	
	_send_http_response(peer, info)

## 处理 OPTIONS 请求（CORS 预检）
## @param peer: StreamPeerTCP - 客户端连接
## @param parsed: Dictionary - 解析后的 HTTP 请求
func _handle_options_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	var response: String = "HTTP/1.1 204 No Content\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
	response += "Access-Control-Max-Age: 86400\r\n"
	response += "\r\n"
	
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()

## 处理 SSE 请求（Server-sent Events）
## @param peer: StreamPeerTCP - 客户端连接
## @param parsed: Dictionary - 解析后的 HTTP 请求
func _handle_sse_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	# 验证认证
	if _auth_manager and not _auth_manager.validate_request(parsed["headers"]):
		_send_http_error(peer, 401, "Unauthorized")
		return
	
	# 生成会话 ID
	var session_id: String = _generate_session_id()
	
	# 发送 SSE 响应头
	var response_header: String = "HTTP/1.1 200 OK\r\n"
	response_header += "Content-Type: text/event-stream\r\n"
	response_header += "Cache-Control: no-cache\r\n"
	response_header += "Connection: keep-alive\r\n"
	response_header += "Access-Control-Allow-Origin: " + _cors_origin + "\r\n"
	response_header += "\r\n"
	
	peer.put_data(response_header.to_utf8_buffer())
	
	# 发送初始消息
	_send_sse_event(peer, "connected", {"session_id": session_id})
	
	# 保存 SSE 连接
	_sse_connections[peer] = session_id
	_sessions[session_id] = {
		"peer": peer,
		"created_at": Time.get_time_dict_from_system()
	}
	
	if _log_callback.is_valid():
		_log_callback.call("INFO", "SSE connection established: " + session_id)

## 发送原始 JSON-RPC 消息（通过 SSE 广播到所有连接）
## @param message: Dictionary - 完整的 JSON-RPC 消息
func send_raw_message(message: Dictionary) -> void:
	var disconnected_peers: Array[StreamPeerTCP] = []
	for peer in _sse_connections.keys():
		_send_sse_event(peer, "message", message)
		if not _sse_connections.has(peer):
			disconnected_peers.append(peer)
	if _log_callback.is_valid():
		_log_callback.call("DEBUG", "Raw message broadcast to " + str(_sse_connections.size()) + " SSE connections")

## 发送 SSE 事件
## @param peer: StreamPeerTCP - 客户端连接
## @param event: String - 事件名称
## @param data: Dictionary - 事件数据
func _send_sse_event(peer: StreamPeerTCP, event: String, data: Dictionary) -> void:
	var message: String = "event: " + event + "\r\n"
	message += "data: " + JSON.stringify(data) + "\r\n"
	message += "\r\n"
	
	var error: Error = peer.put_data(message.to_utf8_buffer())
	if error != OK:
		if _log_callback.is_valid():
			_log_callback.call("ERROR", "Failed to send SSE event: " + str(error))
		_close_sse_connection(peer)

## 关闭 SSE 连接
## @param peer: StreamPeerTCP - 客户端连接
func _close_sse_connection(peer: StreamPeerTCP) -> void:
	if _sse_connections.has(peer):
		var session_id: String = _sse_connections[peer]
		_sse_connections.erase(peer)
		_sessions.erase(session_id)
		if _log_callback.is_valid():
			_log_callback.call("INFO", "SSE connection closed: " + session_id)
	
	peer.disconnect_from_host()

## 生成会话 ID
## @returns: String - 唯一会话 ID
func _generate_session_id() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	var chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var session_id: String = ""
	
	for i in range(32):
		var idx: int = rng.randi() % chars.length()
		session_id += chars[idx]
	
	return session_id

## 设置远程访问配置
## @param allow_remote: bool - 是否允许远程访问
## @param cors_origin: String - CORS 允许的源
func set_remote_config(allow_remote: bool, cors_origin: String = "*") -> void:
	_allow_remote = allow_remote
	_cors_origin = cors_origin
	
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Remote access config: allow_remote=" + str(allow_remote) + ", cors=" + cors_origin)


# ==============================================================================
# 信号发射（线程安全）
# ==============================================================================

## 在主线程中发送消息接收信号
## @param message: Dictionary - JSON-RPC 消息
## @param peer: StreamPeerTCP - 客户端连接
func _emit_message_received(message: Dictionary, peer: StreamPeerTCP) -> void:
	message_received.emit(message, peer as Variant)


# ==============================================================================
# HTTP 响应处理
# ==============================================================================

## 发送 HTTP 响应（从主线程调用）
## @param peer: StreamPeerTCP - 客户端连接
## @param data: Dictionary - 要发送的 JSON 数据
func send_response(response: Dictionary, context: Variant) -> void:
	var peer: StreamPeerTCP = context as StreamPeerTCP
	if not peer:
		if _log_callback.is_valid():
			_log_callback.call("ERROR", "Cannot send response: invalid peer context")
		return
	_send_http_response(peer, response)

## 构建并发送 HTTP 响应
## @param peer: StreamPeerTCP - 客户端连接
## @param data: Dictionary - 要发送的 JSON 数据
func _send_http_response(peer: StreamPeerTCP, data: Dictionary) -> void:
	var json_string: String = JSON.stringify(data)
	var json_bytes: PackedByteArray = json_string.to_utf8_buffer()
	
	var http_response: String = "HTTP/1.1 200 OK\r\n"
	http_response += "Content-Type: application/json; charset=utf-8\r\n"
	http_response += "Content-Length: " + str(json_bytes.size()) + "\r\n"
	http_response += "Access-Control-Allow-Origin: *\r\n"
	http_response += "\r\n"
	
	var header_bytes: PackedByteArray = http_response.to_utf8_buffer()
	var full_response: PackedByteArray = header_bytes + json_bytes
	
	var error: Error = peer.put_data(full_response)
	if error != OK:
		server_error.emit("Failed to send HTTP response: " + str(error))
		if _log_callback.is_valid():
			_log_callback.call("ERROR", "Failed to send response: " + str(error))
	
	peer.disconnect_from_host()

## 发送 HTTP 错误响应
## @param peer: StreamPeerTCP - 客户端连接
## @param status_code: int - HTTP 状态码
## @param message: String - 错误消息
func _send_http_accepted(peer: StreamPeerTCP) -> void:
	var response: String = "HTTP/1.1 202 Accepted\r\n"
	response += "Content-Length: 0\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "\r\n"
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()

func _send_http_error(peer: StreamPeerTCP, status_code: int, message: String) -> void:
	var status_text: String = ""
	match status_code:
		400: status_text = "Bad Request"
		401: status_text = "Unauthorized"
		404: status_text = "Not Found"
		405: status_text = "Method Not Allowed"
		408: status_text = "Request Timeout"
		413: status_text = "Request Too Large"
		415: status_text = "Unsupported Media Type"
		500: status_text = "Internal Server Error"
		501: status_text = "Not Implemented"
		_: status_text = "Error"
	
	var response_header: String = "HTTP/1.1 " + str(status_code) + " " + status_text + "\r\n"
	response_header += "Content-Type: text/plain; charset=utf-8\r\n"
	response_header += "Content-Length: " + str(message.to_utf8_buffer().size()) + "\r\n"
	response_header += "Access-Control-Allow-Origin: *\r\n"
	response_header += "\r\n"
	
	peer.put_data(response_header.to_utf8_buffer() + message.to_utf8_buffer())
	peer.disconnect_from_host()
	
	if _log_callback.is_valid():
		_log_callback.call("WARN", "Error response sent: " + str(status_code) + " " + message)
