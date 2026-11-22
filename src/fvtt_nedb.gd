extends RefCounted


static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var n: int = bytes.size()
	var i: int = 0
	while i < n:
		var b0: int = bytes[i]
		if b0 <= 0x7F:
			i += 1
		elif (b0 & 0xE0) == 0xC0:
			if i + 1 >= n:
				return false
			var b1: int = bytes[i + 1]
			if (b1 & 0xC0) != 0x80:
				return false
			var cp2: int = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
			if cp2 < 0x80:
				return false
			i += 2
		elif (b0 & 0xF0) == 0xE0:
			if i + 2 >= n:
				return false
			var b1e: int = bytes[i + 1]
			var b2e: int = bytes[i + 2]
			if (b1e & 0xC0) != 0x80 or (b2e & 0xC0) != 0x80:
				return false
			var cp3: int = ((b0 & 0x0F) << 12) | ((b1e & 0x3F) << 6) | (b2e & 0x3F)
			if cp3 < 0x800 or (cp3 >= 0xD800 and cp3 <= 0xDFFF):
				return false
			i += 3
		elif (b0 & 0xF8) == 0xF0:
			if i + 3 >= n:
				return false
			var b1f: int = bytes[i + 1]
			var b2f: int = bytes[i + 2]
			var b3f: int = bytes[i + 3]
			if (b1f & 0xC0) != 0x80 or (b2f & 0xC0) != 0x80 or (b3f & 0xC0) != 0x80:
				return false
			var cp4: int = ((b0 & 0x07) << 18) | ((b1f & 0x3F) << 12) | ((b2f & 0x3F) << 6) | (b3f & 0x3F)
			if cp4 < 0x10000 or cp4 > 0x10FFFF:
				return false
			i += 4
		else:
			return false
	return true


static func _is_ascii_whitespace_only(bytes: PackedByteArray) -> bool:
	for b: int in bytes:
		if b != 0x20 and b != 0x09 and b != 0x0D and b != 0x0A:
			return false
	return true


static func _is_truthy_deleted(val: Variant) -> bool:
	if val is bool:
		return val
	if val is int:
		return val == 1
	if val is float:
		return is_finite(val) and val == 1.0
	return false


func parse_jsonl(raw_bytes: PackedByteArray) -> Dictionary:
	var n: int = raw_bytes.size()
	var pos: int = 0
	if n >= 3 and raw_bytes[0] == 0xEF and raw_bytes[1] == 0xBB and raw_bytes[2] == 0xBF:
		pos = 3

	var docs_by_id: Dictionary = {}
	var order: Array[String] = []
	var warnings: Array[String] = []
	var raw_lines: int = 0
	var deleted_count: int = 0
	var parse_errors: int = 0
	var line_no: int = 0

	while pos < n:
		var line_start: int = pos
		var nl: int = raw_bytes.find(0x0A, line_start)
		var line_end: int = nl if nl >= 0 else n
		pos = (nl + 1) if nl >= 0 else n
		line_no += 1

		var trim_end: int = line_end
		if trim_end > line_start and raw_bytes[trim_end - 1] == 0x0D:
			trim_end -= 1
		if trim_end <= line_start:
			continue

		var line_bytes: PackedByteArray = raw_bytes.slice(line_start, trim_end)
		if _is_ascii_whitespace_only(line_bytes):
			continue
		raw_lines += 1

		if not _is_valid_utf8(line_bytes):
			parse_errors += 1
			warnings.append("NeDB 第 %d 行包含非法 UTF-8 字节，已跳过" % line_no)
			continue

		var line_str: String = line_bytes.get_string_from_utf8().strip_edges()
		if line_str.begins_with(char(0xFEFF)):
			line_str = line_str.substr(1).strip_edges()
		if line_str.is_empty():
			continue

		var j := JSON.new()
		var err: Error = j.parse(line_str)
		if err != OK or not (j.data is Dictionary):
			parse_errors += 1
			warnings.append("NeDB 第 %d 行 JSON 解析失败，已跳过" % line_no)
			continue

		var doc: Dictionary = j.data
		if _is_truthy_deleted(doc.get("$$deleted", false)):
			deleted_count += 1
			var del_id_var: Variant = doc.get("_id", "")
			if del_id_var is String and not str(del_id_var).is_empty():
				var del_key: String = "id:" + str(del_id_var)
				docs_by_id.erase(del_key)
				order.erase(del_key)
			continue
		if doc.has("$$indexCreated") or doc.has("$$indexRemoved"):
			continue

		var id_var: Variant = doc.get("_id", null)
		var key: String = ""
		if id_var is String and not str(id_var).is_empty():
			key = "id:" + str(id_var)
		else:
			key = "anon:%d" % line_no
		if not docs_by_id.has(key):
			order.append(key)
		docs_by_id[key] = doc

	var docs: Array[Dictionary] = []
	for key_item: String in order:
		if docs_by_id.has(key_item):
			docs.append(docs_by_id[key_item])

	return {
		"ok": true,
		"docs": docs,
		"raw_lines": raw_lines,
		"deleted_count": deleted_count,
		"parse_errors": parse_errors,
		"warnings": warnings,
	}


func read_collection(source: RefCounted, collection_name: String, session: RefCounted = null) -> Dictionary:
	var rel_path: String = "data/%s.db" % collection_name
	if source == null or not source.has_file(rel_path):
		return {
			"ok": false,
			"reason": "nedb_collection_not_found:" + rel_path,
			"docs": [] as Array[Dictionary],
			"raw_lines": 0,
			"deleted_count": 0,
			"parse_errors": 0,
			"warnings": [] as Array[String],
		}
	var raw_bytes: PackedByteArray = source.read_bytes(rel_path)
	if source.has_method("get_last_read_error"):
		var read_err: String = str(source.get_last_read_error())
		if not read_err.is_empty():
			return {
				"ok": false,
				"reason": read_err,
				"docs": [] as Array[Dictionary],
				"raw_lines": 0,
				"deleted_count": 0,
				"parse_errors": 0,
				"warnings": [] as Array[String],
			}
	var res: Dictionary = parse_jsonl(raw_bytes)
	if session != null and session.has_method("add_warning"):
		for w: String in res.get("warnings", []):
			session.add_warning(w)
	return res
