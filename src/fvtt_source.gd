extends RefCounted

const _MAX_WORLD_JSON_BYTES: int = 16 * 1024 * 1024
const _MAX_CD_BYTES: int = 64 * 1024 * 1024
const _MAX_ENTRY_UNCOMP_BYTES: int = 512 * 1024 * 1024
const _MAX_DEFLATE_EXPANSION_RATIO: int = 1032
const _CL_ORDER: Array[int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
const _LEN_BASE: Array[int] = [
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13,
	15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
	67, 83, 99, 115, 131, 163, 195, 227, 258
]
const _LEN_EXTRA: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
	1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
	4, 4, 4, 4, 5, 5, 5, 5, 0
]
const _DIST_BASE: Array[int] = [
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25,
	33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
	1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
]
const _DIST_EXTRA: Array[int] = [
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3,
	4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
	9, 9, 10, 10, 11, 11, 12, 12, 13, 13
]

var _source_kind: String = ""
var _root_path: String = ""
var _root_name: String = ""
var _root_prefix: String = ""
var _zip_file: FileAccess = null
var _zip_file_len: int = 0
var _zip_entries: Dictionary = {}
var _zip_decoded_bytes: int = 0
var _last_read_error: String = ""
var _crc32_table: PackedInt64Array = PackedInt64Array()
var _fixed_lit_huff: Dictionary = {}
var _fixed_dist_huff: Dictionary = {}
var _exact_entries: Dictionary = {}
var _lower_to_exact: Dictionary = {}
var _dirs_set: Dictionary = {}
var _source_bytes: int = 0
var _dir_decoded_bytes: int = 0
var _world_json_bytes: PackedByteArray = PackedByteArray()
var _world_json: Dictionary = {}
var _open_warnings: Array[String] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _zip_file != null:
			_zip_file.close()
			_zip_file = null


func close() -> void:
	if _zip_file != null:
		_zip_file.close()
		_zip_file = null
	_zip_file_len = 0
	_zip_entries.clear()
	_zip_decoded_bytes = 0
	_last_read_error = ""
	_source_kind = ""
	_root_path = ""
	_root_name = ""
	_root_prefix = ""
	_exact_entries.clear()
	_lower_to_exact.clear()
	_dirs_set.clear()
	_source_bytes = 0
	_dir_decoded_bytes = 0
	_world_json_bytes = PackedByteArray()
	_world_json = {}
	_open_warnings.clear()


func get_warnings() -> Array[String]:
	return _open_warnings.duplicate()


func get_last_read_error() -> String:
	return _last_read_error


func get_source_kind() -> String:
	return _source_kind


func get_root_name() -> String:
	return _root_name


func get_world_json() -> Dictionary:
	return _world_json


static func is_valid_utf8(bytes: PackedByteArray) -> bool:
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


static func strip_utf8_bom(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		if bytes.size() == 3:
			return PackedByteArray()
		return bytes.slice(3, bytes.size())
	return bytes


static func _is_junk_name(name: String) -> bool:
	if name == "__MACOSX" or name == ".DS_Store" or name.begins_with("._"):
		return true
	return false


static func _is_safe_clean_rel_parts(parts: PackedStringArray) -> bool:
	if parts.is_empty():
		return false
	for seg: String in parts:
		if seg.is_empty() or seg == "." or seg == ".." or seg.contains(":") or _is_junk_name(seg):
			return false
	return true


static func _clean_zip_rel_parts(raw_name: String) -> PackedStringArray:
	var norm_entry: String = raw_name.replace("\\", "/")
	if norm_entry.is_empty() or norm_entry.begins_with("/") or norm_entry.contains(":"):
		return PackedStringArray()
	var raw_parts: PackedStringArray = norm_entry.split("/", false)
	var clean_parts: PackedStringArray = PackedStringArray()
	for seg: String in raw_parts:
		if seg == ".":
			continue
		if seg.is_empty() or seg == ".." or seg.contains(":") or _is_junk_name(seg):
			return PackedStringArray()
		clean_parts.append(seg)
	return clean_parts


static func _normalize_rel_path(rel_path: String) -> String:
	var s: String = rel_path.strip_edges().replace("\\", "/")
	while s.begins_with("/"):
		s = s.substr(1)
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	if s.is_empty() or s.contains(":"):
		return ""
	var raw_parts: PackedStringArray = s.split("/", false)
	var clean_parts: PackedStringArray = PackedStringArray()
	for seg: String in raw_parts:
		if seg == ".":
			continue
		if seg == ".." or seg.is_empty():
			return ""
		clean_parts.append(seg)
	return "/".join(clean_parts)


static func _hex_val(ch: int) -> int:
	if ch >= 48 and ch <= 57:
		return ch - 48
	if ch >= 65 and ch <= 70:
		return ch - 55
	if ch >= 97 and ch <= 102:
		return ch - 87
	return -1


static func _percent_decode_utf8(raw_text: String) -> Dictionary:
	var raw_bytes: PackedByteArray = raw_text.to_utf8_buffer()
	var out: PackedByteArray = PackedByteArray()
	var i: int = 0
	var n: int = raw_bytes.size()
	while i < n:
		var b: int = raw_bytes[i]
		if b == 37 and i + 2 < n:
			var hi: int = _hex_val(raw_bytes[i + 1])
			var lo: int = _hex_val(raw_bytes[i + 2])
			if hi >= 0 and lo >= 0:
				var decoded_byte: int = (hi << 4) | lo
				if decoded_byte == 0:
					return {"ok": false, "text": ""}
				out.append(decoded_byte)
				i += 3
				continue
		if b == 0:
			return {"ok": false, "text": ""}
		out.append(b)
		i += 1
	if not is_valid_utf8(out):
		return {"ok": false, "text": ""}
	return {"ok": true, "text": out.get_string_from_utf8()}


func _register_dir_parents(rel_file: String) -> void:
	var slash: int = rel_file.rfind("/")
	while slash > 0:
		var dir_rel: String = rel_file.substr(0, slash)
		if _dirs_set.has(dir_rel):
			break
		_dirs_set[dir_rel] = true
		slash = dir_rel.rfind("/")


func _parse_and_validate_world_json(raw_bytes: PackedByteArray) -> Dictionary:
	if raw_bytes.is_empty():
		return {"ok": false, "reason": "world.json 文件为空"}
	if raw_bytes.size() > _MAX_WORLD_JSON_BYTES:
		return {"ok": false, "reason": "world.json 体积超过上限"}
	var clean_bytes: PackedByteArray = strip_utf8_bom(raw_bytes)
	if not is_valid_utf8(clean_bytes):
		return {"ok": false, "reason": "world.json 不是有效的 UTF-8 文本"}
	var text: String = clean_bytes.get_string_from_utf8()
	var j := JSON.new()
	var err: Error = j.parse(text)
	if err != OK or not (j.data is Dictionary):
		return {"ok": false, "reason": "world.json 不是合法的 JSON 对象"}
	var doc: Dictionary = j.data
	var id_val: Variant = doc.get("id", "")
	var name_val: Variant = doc.get("name", "")
	var has_id: bool = (id_val is String and not str(id_val).strip_edges().is_empty())
	var has_name: bool = (name_val is String and not str(name_val).strip_edges().is_empty())
	if not (has_id or has_name):
		return {"ok": false, "reason": "world.json 缺少有效的 id 或 name 字段"}
	var has_fvtt_marker: bool = false
	for key: String in ["system", "coreVersion", "version", "title"]:
		var val: Variant = doc.get(key, null)
		if val is String and not str(val).strip_edges().is_empty():
			has_fvtt_marker = true
			break
	if not has_fvtt_marker:
		return {"ok": false, "reason": "JSON 文件不是有效的 FVTT 世界清单（缺少 system/coreVersion/title）"}
	return {"ok": true, "doc": doc}


func _scan_dir_recursive(abs_dir: String, rel_prefix: String, depth: int = 0) -> Dictionary:
	if depth > 32:
		_open_warnings.append("目录递归深度超过上限，已跳过：" + rel_prefix)
		return {"ok": true}
	if not DirAccess.dir_exists_absolute(abs_dir):
		if depth == 0:
			return {"ok": false, "reason": "世界目录不存在"}
		_open_warnings.append("子目录不存在，已跳过：" + rel_prefix)
		return {"ok": true}
	var da: DirAccess = DirAccess.open(abs_dir)
	if da == null:
		if depth == 0:
			return {"ok": false, "reason": "无法打开世界目录"}
		_open_warnings.append("无法打开子目录，已跳过：" + rel_prefix)
		return {"ok": true}
	da.include_hidden = false
	da.include_navigational = false
	var err: Error = da.list_dir_begin()
	if err != OK:
		if depth == 0:
			return {"ok": false, "reason": "无法遍历世界目录"}
		_open_warnings.append("无法遍历子目录，已跳过：" + rel_prefix)
		return {"ok": true}
	var has_is_link: bool = da.has_method("is_link")
	var subdirs: Array[String] = []
	while true:
		var entry: String = da.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == ".." or _is_junk_name(entry):
			continue
		var child_rel: String = entry if rel_prefix.is_empty() else (rel_prefix + "/" + entry)
		var child_abs: String = abs_dir.path_join(entry)
		if da.current_is_dir():
			if has_is_link and da.is_link(entry):
				_open_warnings.append("跳过符号链接或目录联接：" + child_rel)
				continue
			_dirs_set[child_rel] = true
			subdirs.append(entry)
		else:
			if FileAccess.file_exists(child_abs):
				var f: FileAccess = FileAccess.open(child_abs, FileAccess.READ)
				if f != null:
					_dir_decoded_bytes += int(f.get_length())
					f.close()
				_exact_entries[child_rel] = child_abs
				_lower_to_exact[child_rel.to_lower()] = child_rel
				_register_dir_parents(child_rel)
	da.list_dir_end()
	subdirs.sort()
	for sub: String in subdirs:
		var sub_rel: String = sub if rel_prefix.is_empty() else (rel_prefix + "/" + sub)
		var sub_res: Dictionary = _scan_dir_recursive(abs_dir.path_join(sub), sub_rel, depth + 1)
		if not bool(sub_res.get("ok", false)):
			return sub_res
	return {"ok": true}


static func _u16_le(buf: PackedByteArray, off: int) -> int:
	return int(buf[off]) | (int(buf[off + 1]) << 8)


static func _u32_le(buf: PackedByteArray, off: int) -> int:
	return (
		int(buf[off])
		| (int(buf[off + 1]) << 8)
		| (int(buf[off + 2]) << 16)
		| (int(buf[off + 3]) << 24)
	)


static func _read_file_slice(f: FileAccess, flen: int, offset: int, count: int) -> PackedByteArray:
	if f == null or offset < 0 or count <= 0 or offset >= flen:
		return PackedByteArray()
	var avail: int = flen - offset
	var to_read: int = mini(count, avail)
	if to_read <= 0:
		return PackedByteArray()
	f.seek(offset)
	return f.get_buffer(to_read)


static func _bytes_equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	var n: int = a.size()
	if n != b.size():
		return false
	for i: int in range(n):
		if a[i] != b[i]:
			return false
	return true


static func _decode_zip_filename(fn_bytes: PackedByteArray) -> String:
	if fn_bytes.is_empty():
		return ""
	for b: int in fn_bytes:
		if b == 0:
			return ""
	if is_valid_utf8(fn_bytes):
		return fn_bytes.get_string_from_utf8()
	var out: String = ""
	for b2: int in fn_bytes:
		out += char(b2)
	return out


static func _is_zip_junk_entry(raw_name: String) -> bool:
	var norm: String = raw_name.replace("\\", "/")
	if norm.ends_with("/"):
		return true
	var parts: PackedStringArray = norm.split("/", false)
	for seg: String in parts:
		if _is_junk_name(seg):
			return true
	return false


func _ensure_crc32_table() -> void:
	if _crc32_table.size() == 256:
		return
	_crc32_table.resize(256)
	for i: int in range(256):
		var c: int = i
		for _j: int in range(8):
			if (c & 1) != 0:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		_crc32_table[i] = c & 0xFFFFFFFF


func _crc32(data: PackedByteArray) -> int:
	_ensure_crc32_table()
	var tbl: PackedInt64Array = _crc32_table
	var crc: int = 0xFFFFFFFF
	var n: int = data.size()
	var i: int = 0
	while i + 4 <= n:
		var w: int = data.decode_u32(i)
		crc = tbl[(crc ^ (w & 0xFF)) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
		crc = tbl[(crc ^ ((w >> 8) & 0xFF)) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
		crc = tbl[(crc ^ ((w >> 16) & 0xFF)) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
		crc = tbl[(crc ^ ((w >> 24) & 0xFF)) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
		i += 4
	while i < n:
		var b: int = data[i]
		crc = tbl[(crc ^ b) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
		i += 1
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


static func _build_huffman(lengths: PackedInt32Array, allow_empty: bool = false) -> Dictionary:
	var num_syms: int = lengths.size()
	var bl_count := PackedInt32Array()
	bl_count.resize(16)
	var total_non_zero: int = 0
	for sym: int in range(num_syms):
		var cl: int = lengths[sym]
		if cl < 0 or cl > 15:
			return {"ok": false, "reason": "zip_deflate_bad_codelen"}
		if cl > 0:
			bl_count[cl] += 1
			total_non_zero += 1
	if total_non_zero == 0:
		if allow_empty:
			var empty_fast := PackedInt32Array()
			empty_fast.resize(512)
			empty_fast.fill(-1)
			return {"ok": true, "empty": true, "fast": empty_fast, "bl_count": bl_count, "sorted": PackedInt32Array()}
		return {"ok": false, "reason": "zip_deflate_empty_huffman"}
	var left: int = 1
	for bits: int in range(1, 16):
		left <<= 1
		left -= bl_count[bits]
		if left < 0:
			return {"ok": false, "reason": "zip_deflate_oversubscribed_huffman"}
	var next_code := PackedInt32Array()
	next_code.resize(16)
	var code: int = 0
	for bits2: int in range(1, 16):
		code = (code + bl_count[bits2 - 1]) << 1
		next_code[bits2] = code
	var offs := PackedInt32Array()
	offs.resize(16)
	var acc_off: int = 0
	for bits3: int in range(1, 16):
		offs[bits3] = acc_off
		acc_off += bl_count[bits3]
	var sorted_syms := PackedInt32Array()
	sorted_syms.resize(total_non_zero)
	var fast := PackedInt32Array()
	fast.resize(512)
	fast.fill(-1)
	for sym2: int in range(num_syms):
		var l: int = lengths[sym2]
		if l == 0:
			continue
		var s_idx: int = offs[l]
		offs[l] = s_idx + 1
		sorted_syms[s_idx] = sym2
		var c: int = next_code[l]
		next_code[l] = c + 1
		if l <= 9:
			var rev: int = 0
			var tmp: int = c
			for _b: int in range(l):
				rev = (rev << 1) | (tmp & 1)
				tmp >>= 1
			var val_packed: int = (sym2 << 4) | l
			var step: int = 1 << l
			var idx_f: int = rev
			while idx_f < 512:
				fast[idx_f] = val_packed
				idx_f += step
	return {
		"ok": true,
		"empty": false,
		"fast": fast,
		"bl_count": bl_count,
		"sorted": sorted_syms,
	}


func _ensure_fixed_huffman() -> void:
	if not _fixed_lit_huff.is_empty() and not _fixed_dist_huff.is_empty():
		return
	var lit_lens := PackedInt32Array()
	lit_lens.resize(288)
	for i: int in range(144):
		lit_lens[i] = 8
	for i2: int in range(144, 256):
		lit_lens[i2] = 9
	for i3: int in range(256, 280):
		lit_lens[i3] = 7
	for i4: int in range(280, 288):
		lit_lens[i4] = 8
	_fixed_lit_huff = _build_huffman(lit_lens, false)
	var dist_lens := PackedInt32Array()
	dist_lens.resize(32)
	for d: int in range(32):
		dist_lens[d] = 5
	_fixed_dist_huff = _build_huffman(dist_lens, false)


func _inflate_raw_deflate(src: PackedByteArray, expected_size: int) -> Dictionary:
	if expected_size < 0 or expected_size > _MAX_ENTRY_UNCOMP_BYTES:
		return {"ok": false, "reason": "zip_deflate_bad_expected_size"}
	var out := PackedByteArray()
	out.resize(expected_size)
	var out_pos: int = 0
	var src_len: int = src.size()
	var byte_pos: int = 0
	var bit_buf: int = 0
	var bit_cnt: int = 0
	var bfinal: int = 0

	while bfinal == 0:
		while bit_cnt < 3:
			if byte_pos >= src_len:
				return {"ok": false, "reason": "zip_deflate_truncated"}
			bit_buf |= int(src[byte_pos]) << bit_cnt
			byte_pos += 1
			bit_cnt += 8
		bfinal = bit_buf & 1
		var btype: int = (bit_buf >> 1) & 3
		bit_buf >>= 3
		bit_cnt -= 3

		if btype == 0:
			var discard: int = bit_cnt & 7
			if discard > 0:
				bit_buf >>= discard
				bit_cnt -= discard
			byte_pos -= (bit_cnt >> 3)
			bit_buf = 0
			bit_cnt = 0
			if byte_pos + 4 > src_len:
				return {"ok": false, "reason": "zip_deflate_truncated"}
			var block_len: int = _u16_le(src, byte_pos)
			var nlen: int = _u16_le(src, byte_pos + 2)
			byte_pos += 4
			if (block_len ^ 0xFFFF) != nlen:
				return {"ok": false, "reason": "zip_deflate_bad_stored_len"}
			if byte_pos + block_len > src_len:
				return {"ok": false, "reason": "zip_deflate_truncated"}
			if out_pos + block_len > expected_size:
				return {"ok": false, "reason": "zip_deflate_output_overflow"}
			for _k0: int in range(block_len):
				out[out_pos] = src[byte_pos]
				out_pos += 1
				byte_pos += 1
			continue

		if btype == 3:
			return {"ok": false, "reason": "zip_deflate_invalid_btype"}

		var lit_huff: Dictionary
		var dist_huff: Dictionary
		if btype == 1:
			_ensure_fixed_huffman()
			lit_huff = _fixed_lit_huff
			dist_huff = _fixed_dist_huff
		else:
			while bit_cnt < 14:
				if byte_pos >= src_len:
					return {"ok": false, "reason": "zip_deflate_truncated"}
				bit_buf |= int(src[byte_pos]) << bit_cnt
				byte_pos += 1
				bit_cnt += 8
			var hlit: int = (bit_buf & 31) + 257
			var hdist: int = ((bit_buf >> 5) & 31) + 1
			var hclen: int = ((bit_buf >> 10) & 15) + 4
			bit_buf >>= 14
			bit_cnt -= 14
			if hlit > 286 or hdist > 30:
				return {"ok": false, "reason": "zip_deflate_bad_dyn_counts"}

			var cl_lengths := PackedInt32Array()
			cl_lengths.resize(19)
			for c_i: int in range(hclen):
				while bit_cnt < 3:
					if byte_pos >= src_len:
						return {"ok": false, "reason": "zip_deflate_truncated"}
					bit_buf |= int(src[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				cl_lengths[_CL_ORDER[c_i]] = bit_buf & 7
				bit_buf >>= 3
				bit_cnt -= 3

			var cl_huff: Dictionary = _build_huffman(cl_lengths, false)
			if not bool(cl_huff.get("ok", false)):
				return cl_huff
			var cl_fast: PackedInt32Array = cl_huff["fast"]
			var cl_bl: PackedInt32Array = cl_huff["bl_count"]
			var cl_sorted: PackedInt32Array = cl_huff["sorted"]

			var total_codes: int = hlit + hdist
			var all_lengths := PackedInt32Array()
			all_lengths.resize(total_codes)
			var idx_len: int = 0
			while idx_len < total_codes:
				while bit_cnt < 15 and byte_pos < src_len:
					bit_buf |= int(src[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var csym: int = -1
				var cf_entry: int = cl_fast[bit_buf & 511]
				if cf_entry >= 0:
					var c_clen: int = cf_entry & 15
					if c_clen > bit_cnt:
						return {"ok": false, "reason": "zip_deflate_truncated"}
					csym = cf_entry >> 4
					bit_buf >>= c_clen
					bit_cnt -= c_clen
				else:
					var c_acc: int = 0
					var c_first: int = 0
					var c_soff: int = 0
					for cl_step: int in range(1, 16):
						if bit_cnt == 0:
							if byte_pos >= src_len:
								return {"ok": false, "reason": "zip_deflate_truncated"}
							bit_buf |= int(src[byte_pos]) << bit_cnt
							byte_pos += 1
							bit_cnt += 8
						c_acc |= (bit_buf & 1)
						bit_buf >>= 1
						bit_cnt -= 1
						var c_cntl: int = cl_bl[cl_step]
						if c_acc - c_cntl < c_first:
							csym = cl_sorted[c_soff + (c_acc - c_first)]
							break
						c_soff += c_cntl
						c_first = (c_first + c_cntl) << 1
						c_acc <<= 1
				if csym < 0:
					return {"ok": false, "reason": "zip_deflate_invalid_cl_code"}
				if csym < 16:
					all_lengths[idx_len] = csym
					idx_len += 1
				elif csym == 16:
					if idx_len == 0:
						return {"ok": false, "reason": "zip_deflate_bad_repeat"}
					while bit_cnt < 2:
						if byte_pos >= src_len:
							return {"ok": false, "reason": "zip_deflate_truncated"}
						bit_buf |= int(src[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep16: int = (bit_buf & 3) + 3
					bit_buf >>= 2
					bit_cnt -= 2
					if idx_len + rep16 > total_codes:
						return {"ok": false, "reason": "zip_deflate_repeat_overflow"}
					var prev_len: int = all_lengths[idx_len - 1]
					for _r16: int in range(rep16):
						all_lengths[idx_len] = prev_len
						idx_len += 1
				elif csym == 17:
					while bit_cnt < 3:
						if byte_pos >= src_len:
							return {"ok": false, "reason": "zip_deflate_truncated"}
						bit_buf |= int(src[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep17: int = (bit_buf & 7) + 3
					bit_buf >>= 3
					bit_cnt -= 3
					if idx_len + rep17 > total_codes:
						return {"ok": false, "reason": "zip_deflate_repeat_overflow"}
					idx_len += rep17
				else:
					while bit_cnt < 7:
						if byte_pos >= src_len:
							return {"ok": false, "reason": "zip_deflate_truncated"}
						bit_buf |= int(src[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep18: int = (bit_buf & 127) + 11
					bit_buf >>= 7
					bit_cnt -= 7
					if idx_len + rep18 > total_codes:
						return {"ok": false, "reason": "zip_deflate_repeat_overflow"}
					idx_len += rep18

			var lit_lens_dyn: PackedInt32Array = all_lengths.slice(0, hlit)
			if lit_lens_dyn.size() <= 256 or lit_lens_dyn[256] <= 0:
				return {"ok": false, "reason": "zip_deflate_missing_eob"}
			var dist_lens_dyn: PackedInt32Array = all_lengths.slice(hlit, total_codes)
			lit_huff = _build_huffman(lit_lens_dyn, false)
			if not bool(lit_huff.get("ok", false)):
				return lit_huff
			dist_huff = _build_huffman(dist_lens_dyn, true)
			if not bool(dist_huff.get("ok", false)):
				return dist_huff

		var lit_fast: PackedInt32Array = lit_huff["fast"]
		var lit_bl: PackedInt32Array = lit_huff["bl_count"]
		var lit_sorted: PackedInt32Array = lit_huff["sorted"]
		var dist_fast: PackedInt32Array = dist_huff["fast"]
		var dist_bl: PackedInt32Array = dist_huff["bl_count"]
		var dist_sorted: PackedInt32Array = dist_huff["sorted"]

		while true:
			while bit_cnt < 15 and byte_pos < src_len:
				bit_buf |= int(src[byte_pos]) << bit_cnt
				byte_pos += 1
				bit_cnt += 8
			var sym: int = -1
			var f_entry: int = lit_fast[bit_buf & 511]
			if f_entry >= 0:
				var l_clen: int = f_entry & 15
				if l_clen > bit_cnt:
					return {"ok": false, "reason": "zip_deflate_truncated"}
				sym = f_entry >> 4
				bit_buf >>= l_clen
				bit_cnt -= l_clen
			else:
				var l_acc: int = 0
				var l_first: int = 0
				var l_soff: int = 0
				for cl_l: int in range(1, 16):
					if bit_cnt == 0:
						if byte_pos >= src_len:
							return {"ok": false, "reason": "zip_deflate_truncated"}
						bit_buf |= int(src[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					l_acc |= (bit_buf & 1)
					bit_buf >>= 1
					bit_cnt -= 1
					var l_cntl: int = lit_bl[cl_l]
					if l_acc - l_cntl < l_first:
						sym = lit_sorted[l_soff + (l_acc - l_first)]
						break
					l_soff += l_cntl
					l_first = (l_first + l_cntl) << 1
					l_acc <<= 1
			if sym < 0:
				return {"ok": false, "reason": "zip_deflate_invalid_lit_code"}
			if sym < 256:
				if out_pos >= expected_size:
					return {"ok": false, "reason": "zip_deflate_output_overflow"}
				out[out_pos] = sym
				out_pos += 1
			elif sym == 256:
				break
			else:
				if sym > 285:
					return {"ok": false, "reason": "zip_deflate_bad_length_sym"}
				var lidx: int = sym - 257
				var lextra: int = _LEN_EXTRA[lidx]
				while bit_cnt < lextra:
					if byte_pos >= src_len:
						return {"ok": false, "reason": "zip_deflate_truncated"}
					bit_buf |= int(src[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var mlen: int = _LEN_BASE[lidx] + (bit_buf & ((1 << lextra) - 1))
				bit_buf >>= lextra
				bit_cnt -= lextra

				while bit_cnt < 15 and byte_pos < src_len:
					bit_buf |= int(src[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var dsym: int = -1
				var df_entry: int = dist_fast[bit_buf & 511]
				if df_entry >= 0:
					var d_clen: int = df_entry & 15
					if d_clen > bit_cnt:
						return {"ok": false, "reason": "zip_deflate_truncated"}
					dsym = df_entry >> 4
					bit_buf >>= d_clen
					bit_cnt -= d_clen
				else:
					var d_acc: int = 0
					var d_first: int = 0
					var d_soff: int = 0
					for cl_d: int in range(1, 16):
						if bit_cnt == 0:
							if byte_pos >= src_len:
								return {"ok": false, "reason": "zip_deflate_truncated"}
							bit_buf |= int(src[byte_pos]) << bit_cnt
							byte_pos += 1
							bit_cnt += 8
						d_acc |= (bit_buf & 1)
						bit_buf >>= 1
						bit_cnt -= 1
						var d_cntl: int = dist_bl[cl_d]
						if d_acc - d_cntl < d_first:
							dsym = dist_sorted[d_soff + (d_acc - d_first)]
							break
						d_soff += d_cntl
						d_first = (d_first + d_cntl) << 1
						d_acc <<= 1
				if dsym < 0 or dsym > 29:
					return {"ok": false, "reason": "zip_deflate_bad_dist_sym"}
				var dextra: int = _DIST_EXTRA[dsym]
				while bit_cnt < dextra:
					if byte_pos >= src_len:
						return {"ok": false, "reason": "zip_deflate_truncated"}
					bit_buf |= int(src[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var dist: int = _DIST_BASE[dsym] + (bit_buf & ((1 << dextra) - 1))
				bit_buf >>= dextra
				bit_cnt -= dextra

				if dist < 1 or dist > out_pos:
					return {"ok": false, "reason": "zip_deflate_bad_distance"}
				if out_pos + mlen > expected_size:
					return {"ok": false, "reason": "zip_deflate_output_overflow"}
				for _m: int in range(mlen):
					out[out_pos] = out[out_pos - dist]
					out_pos += 1

	if out_pos != expected_size:
		return {"ok": false, "reason": "zip_deflate_size_mismatch"}
	return {"ok": true, "data": out}


func _read_zip_entry_bytes(raw_entry_name: String) -> Dictionary:
	if _zip_file == null:
		return {"ok": false, "reason": "zip_source_closed"}
	if not _zip_entries.has(raw_entry_name):
		return {"ok": false, "reason": "zip_entry_not_found:" + raw_entry_name}
	var meta: Dictionary = _zip_entries[raw_entry_name]
	var comp_method: int = int(meta["comp_method"])
	var comp_size: int = int(meta["comp_size"])
	var uncomp_size: int = int(meta["uncomp_size"])
	var expected_crc: int = int(meta["crc32"])
	var data_off: int = int(meta["data_off"])

	if uncomp_size < 0 or uncomp_size > _MAX_ENTRY_UNCOMP_BYTES:
		return {"ok": false, "reason": "zip_entry_too_large:" + raw_entry_name}

	var comp_bytes := PackedByteArray()
	if comp_size > 0:
		comp_bytes = _read_file_slice(_zip_file, _zip_file_len, data_off, comp_size)
	if comp_bytes.size() != comp_size:
		return {"ok": false, "reason": "zip_entry_truncated:" + raw_entry_name}

	var out_bytes: PackedByteArray
	if comp_method == 0:
		if comp_bytes.size() != uncomp_size:
			return {"ok": false, "reason": "zip_stored_size_mismatch:" + raw_entry_name}
		out_bytes = comp_bytes
	elif comp_method == 8:
		var inf_res: Dictionary = _inflate_raw_deflate(comp_bytes, uncomp_size)
		if not bool(inf_res.get("ok", false)):
			return {"ok": false, "reason": str(inf_res.get("reason", "zip_deflate_error")) + ":" + raw_entry_name}
		out_bytes = inf_res["data"]
	else:
		return {"ok": false, "reason": "zip_unsupported_method:" + raw_entry_name}

	if _crc32(out_bytes) != expected_crc:
		return {"ok": false, "reason": "zip_crc32_mismatch:" + raw_entry_name}

	return {"ok": true, "data": out_bytes}


func _open_zip_archive(clean_path: String, src_len: int) -> Dictionary:
	var zf: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if zf == null:
		return {"ok": false, "reason": "无法打开 FVTT 压缩包"}
	var flen: int = maxi(0, int(zf.get_length()))
	if flen < 22:
		zf.close()
		return {"ok": false, "reason": "zip_too_short:压缩包格式无效或已截断"}

	var tail_len: int = mini(flen, 65557)
	var tail_off: int = flen - tail_len
	var tail: PackedByteArray = _read_file_slice(zf, flen, tail_off, tail_len)
	if tail.size() != tail_len:
		zf.close()
		return {"ok": false, "reason": "zip_read_tail_failed:无法读取压缩包尾部"}

	var eocd_pos: int = -1
	for i: int in range(tail.size() - 22, -1, -1):
		if tail[i] == 0x50 and tail[i + 1] == 0x4B and tail[i + 2] == 0x05 and tail[i + 3] == 0x06:
			var comment_len: int = _u16_le(tail, i + 20)
			if i + 22 + comment_len == tail.size():
				eocd_pos = i
				break
	if eocd_pos < 0:
		zf.close()
		return {"ok": false, "reason": "zip_missing_eocd:压缩包格式无效或已截断（缺少中央目录结束标记）"}

	var eocd_abs: int = tail_off + eocd_pos
	var disk_num: int = _u16_le(tail, eocd_pos + 4)
	var cd_disk: int = _u16_le(tail, eocd_pos + 6)
	var disk_entries: int = _u16_le(tail, eocd_pos + 8)
	var total_entries: int = _u16_le(tail, eocd_pos + 10)
	var cd_size: int = _u32_le(tail, eocd_pos + 12)
	var cd_offset: int = _u32_le(tail, eocd_pos + 16)

	if disk_num != 0 or cd_disk != 0 or disk_entries != total_entries:
		zf.close()
		return {"ok": false, "reason": "zip_multidisk_unsupported:不支持分卷 ZIP 压缩包"}
	if total_entries == 0xFFFF or cd_size == 0xFFFFFFFF or cd_offset == 0xFFFFFFFF:
		zf.close()
		return {"ok": false, "reason": "zip64_unsupported:不支持 ZIP64 归档"}
	if cd_size <= 0 or cd_size > _MAX_CD_BYTES or cd_offset < 0 or cd_offset > eocd_abs or cd_size > eocd_abs - cd_offset:
		zf.close()
		return {"ok": false, "reason": "zip_invalid_cd_bounds:压缩包中央目录边界无效"}

	var cd: PackedByteArray = _read_file_slice(zf, flen, cd_offset, cd_size)
	if cd.size() != cd_size:
		zf.close()
		return {"ok": false, "reason": "zip_cd_truncated:压缩包中央目录已截断"}

	var cd_items: Array[Dictionary] = []
	var p: int = 0
	for _idx: int in range(total_entries):
		if p + 46 > cd_size:
			zf.close()
			return {"ok": false, "reason": "zip_cd_truncated:压缩包中央目录条目越界"}
		if _u32_le(cd, p) != 0x02014B50:
			zf.close()
			return {"ok": false, "reason": "zip_cd_bad_sig:压缩包中央目录签名无效"}
		var flags: int = _u16_le(cd, p + 8)
		var comp_method: int = _u16_le(cd, p + 10)
		var crc32: int = _u32_le(cd, p + 16)
		var comp_size: int = _u32_le(cd, p + 20)
		var uncomp_size: int = _u32_le(cd, p + 24)
		var fn_len: int = _u16_le(cd, p + 28)
		var ex_len: int = _u16_le(cd, p + 30)
		var cm_len: int = _u16_le(cd, p + 32)
		var disk_start: int = _u16_le(cd, p + 34)
		var lfh_off: int = _u32_le(cd, p + 42)
		if p + 46 + fn_len + ex_len + cm_len > cd_size:
			zf.close()
			return {"ok": false, "reason": "zip_cd_entry_oob:压缩包中央目录条目长度越界"}
		if disk_start != 0:
			zf.close()
			return {"ok": false, "reason": "zip_multidisk_unsupported:不支持分卷 ZIP 条目"}
		if comp_size == 0xFFFFFFFF or uncomp_size == 0xFFFFFFFF or lfh_off == 0xFFFFFFFF:
			zf.close()
			return {"ok": false, "reason": "zip64_unsupported:不支持 ZIP64 条目"}
		var fn_bytes: PackedByteArray = cd.slice(p + 46, p + 46 + fn_len) if fn_len > 0 else PackedByteArray()
		var raw_name: String = _decode_zip_filename(fn_bytes)
		cd_items.append({
			"raw_name": raw_name,
			"fn_bytes": fn_bytes,
			"fn_len": fn_len,
			"flags": flags,
			"comp_method": comp_method,
			"crc32": crc32,
			"comp_size": comp_size,
			"uncomp_size": uncomp_size,
			"lfh_off": lfh_off,
		})
		p += 46 + fn_len + ex_len + cm_len

	if p != cd_size:
		zf.close()
		return {"ok": false, "reason": "zip_cd_size_mismatch:压缩包中央目录长度不匹配"}

	var validated_entries: Dictionary = {}
	var norm_to_raw: Dictionary = {}
	var norm_active_size: Dictionary = {}
	var nonclean_active_size: Dictionary = {}
	var decoded_total: int = 0
	var clean_entries: Array[String] = []
	var depth0_world: Array[String] = []
	var depth1_world: Array[String] = []

	for item: Dictionary in cd_items:
		var raw_name: String = item["raw_name"]
		var fn_bytes: PackedByteArray = item["fn_bytes"]
		var fn_len: int = int(item["fn_len"])
		var flags: int = int(item["flags"])
		var comp_method: int = int(item["comp_method"])
		var crc32: int = int(item["crc32"])
		var comp_size: int = int(item["comp_size"])
		var uncomp_size: int = int(item["uncomp_size"])
		var lfh_off: int = int(item["lfh_off"])

		if lfh_off < 0 or lfh_off + 30 > cd_offset:
			zf.close()
			return {"ok": false, "reason": "zip_lfh_oob:压缩包本地文件头越界"}
		var lfh: PackedByteArray = _read_file_slice(zf, flen, lfh_off, 30)
		if lfh.size() != 30 or _u32_le(lfh, 0) != 0x04034B50:
			zf.close()
			return {"ok": false, "reason": "zip_lfh_bad_sig:压缩包本地文件头损坏或签名无效"}

		var lfh_flags: int = _u16_le(lfh, 6)
		var lfh_comp: int = _u16_le(lfh, 8)
		var lfh_crc: int = _u32_le(lfh, 14)
		var lfh_csz: int = _u32_le(lfh, 18)
		var lfh_usz: int = _u32_le(lfh, 22)
		var lfh_fn_len: int = _u16_le(lfh, 26)
		var lfh_ex_len: int = _u16_le(lfh, 28)

		if lfh_comp != comp_method or lfh_flags != flags or lfh_fn_len != fn_len:
			zf.close()
			return {"ok": false, "reason": "zip_lfh_mismatch:压缩包本地文件头与中央目录不一致"}

		var data_off: int = lfh_off + 30 + lfh_fn_len + lfh_ex_len
		if data_off > cd_offset or comp_size > cd_offset - data_off:
			zf.close()
			return {"ok": false, "reason": "zip_entry_data_oob:压缩包条目数据区越界或已截断"}

		if lfh_fn_len > 0:
			var lfh_fn_bytes: PackedByteArray = _read_file_slice(zf, flen, lfh_off + 30, lfh_fn_len)
			if not _bytes_equal(lfh_fn_bytes, fn_bytes):
				zf.close()
				return {"ok": false, "reason": "zip_lfh_name_mismatch:压缩包本地文件头文件名与中央目录不一致"}

		if (flags & 0x0008) == 0:
			if lfh_crc != crc32 or lfh_csz != comp_size or lfh_usz != uncomp_size:
				zf.close()
				return {"ok": false, "reason": "zip_lfh_size_crc_mismatch:压缩包本地文件头校验信息不一致"}

		if raw_name.is_empty():
			zf.close()
			return {"ok": false, "reason": "zip_invalid_entry_name:压缩包存在空文件名或非法 NUL 字节"}

		if not raw_name.ends_with("/"):
			if (flags & 0x0001) != 0:
				zf.close()
				return {"ok": false, "reason": "zip_encrypted_unsupported:不支持加密的 ZIP 条目"}
			if comp_method != 0 and comp_method != 8:
				zf.close()
				return {"ok": false, "reason": "zip_unsupported_method:不支持的 ZIP 压缩算法（%d）" % comp_method}
			if comp_method == 0 and comp_size != uncomp_size:
				zf.close()
				return {"ok": false, "reason": "zip_stored_size_mismatch:压缩包未压缩条目长度异常"}
			if uncomp_size > _MAX_ENTRY_UNCOMP_BYTES:
				zf.close()
				return {"ok": false, "reason": "zip_entry_too_large:压缩包条目解压体积超过上限"}
			if comp_method == 8 and uncomp_size > comp_size * _MAX_DEFLATE_EXPANSION_RATIO + 1024:
				zf.close()
				return {"ok": false, "reason": "zip_suspicious_ratio:压缩包条目压缩比异常"}

			var is_junk: bool = _is_zip_junk_entry(raw_name)
			var clean_parts: PackedStringArray = _clean_zip_rel_parts(raw_name) if not is_junk else PackedStringArray()
			var is_clean_valid: bool = (not is_junk) and _is_safe_clean_rel_parts(clean_parts)
			var norm_key: String = "/".join(clean_parts) if is_clean_valid else ""

			validated_entries[raw_name] = {
				"data_off": data_off,
				"comp_method": comp_method,
				"flags": flags,
				"crc32": crc32,
				"comp_size": comp_size,
				"uncomp_size": uncomp_size,
			}
			if not is_junk:
				if is_clean_valid:
					if norm_active_size.has(norm_key):
						decoded_total -= int(norm_active_size[norm_key])
					norm_active_size[norm_key] = uncomp_size
				else:
					if nonclean_active_size.has(raw_name):
						decoded_total -= int(nonclean_active_size[raw_name])
					nonclean_active_size[raw_name] = uncomp_size
				decoded_total += uncomp_size

			if is_clean_valid:
				var is_new_norm: bool = not norm_to_raw.has(norm_key)
				norm_to_raw[norm_key] = raw_name
				if is_new_norm:
					clean_entries.append(norm_key)
					if clean_parts.size() == 1 and clean_parts[0].to_lower() == "world.json":
						depth0_world.append(norm_key)
					elif clean_parts.size() == 2 and clean_parts[1].to_lower() == "world.json":
						depth1_world.append(norm_key)

	var root_prefix: String = ""
	var root_name: String = clean_path.get_file().get_basename()
	var wj_norm_key: String = ""
	if depth0_world.size() == 1:
		root_prefix = ""
		wj_norm_key = depth0_world[0]
	elif depth0_world.size() > 1:
		zf.close()
		return {"ok": false, "reason": "归档包含多个候选 world.json，无法唯一确定世界根目录"}
	elif depth1_world.size() == 1:
		var d1_parts: PackedStringArray = depth1_world[0].split("/", false)
		root_prefix = d1_parts[0] + "/"
		root_name = d1_parts[0]
		wj_norm_key = depth1_world[0]
	elif depth1_world.size() > 1:
		zf.close()
		return {"ok": false, "reason": "归档包含多个候选 world.json，无法唯一确定世界根目录"}
	else:
		zf.close()
		return {"ok": false, "reason": "归档内未在根目录或一级子目录找到 world.json"}

	var wj_zip_entry: String = str(norm_to_raw[wj_norm_key])
	var wj_meta: Dictionary = validated_entries[wj_zip_entry]
	if int(wj_meta["uncomp_size"]) > _MAX_WORLD_JSON_BYTES:
		zf.close()
		return {"ok": false, "reason": "world.json 体积超过上限"}

	_zip_file = zf
	_zip_file_len = flen
	_zip_entries = validated_entries
	_zip_decoded_bytes = decoded_total

	var wj_read_res: Dictionary = _read_zip_entry_bytes(wj_zip_entry)
	if not bool(wj_read_res.get("ok", false)):
		var wj_err: String = str(wj_read_res.get("reason", "zip_world_json_read_failed"))
		close()
		return {"ok": false, "reason": wj_err}

	var wbytes_zip: PackedByteArray = wj_read_res["data"]
	var parsed_zip: Dictionary = _parse_and_validate_world_json(wbytes_zip)
	if not bool(parsed_zip.get("ok", false)):
		close()
		return {"ok": false, "reason": str(parsed_zip.get("reason", "world.json 无效"))}

	_source_kind = "zip"
	_root_path = clean_path
	_root_name = root_name
	_root_prefix = root_prefix
	_source_bytes = src_len
	_world_json_bytes = wbytes_zip
	_world_json = parsed_zip["doc"]

	for norm_e: String in clean_entries:
		var norm2: String = norm_e
		if not root_prefix.is_empty():
			if not norm2.begins_with(root_prefix):
				continue
			norm2 = norm2.substr(root_prefix.length())
		if norm2.is_empty():
			continue
		_exact_entries[norm2] = str(norm_to_raw[norm_e])
		_lower_to_exact[norm2.to_lower()] = norm2
		_register_dir_parents(norm2)

	return {
		"ok": true,
		"source_kind": _source_kind,
		"root_name": _root_name,
		"world_json_bytes": _world_json_bytes,
		"world_json": _world_json,
		"source_bytes": _source_bytes,
		"decoded_bytes": _zip_decoded_bytes,
		"file_count": _exact_entries.size(),
		"warnings": _open_warnings.duplicate(),
	}


func open(path: String) -> Dictionary:
	close()
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
		return {"ok": false, "reason": "源文件不存在：" + clean_path.get_file()}
	var sf: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if sf == null:
		return {"ok": false, "reason": "无法读取源文件：" + clean_path.get_file()}
	var src_len: int = maxi(0, int(sf.get_length()))
	sf.close()

	var ext: String = clean_path.get_extension().to_lower()
	if ext == "json":
		if clean_path.get_file().to_lower() != "world.json":
			return {"ok": false, "reason": "请选择 FVTT 世界清单文件 world.json（当前：%s）" % clean_path.get_file()}
		var wf: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
		if wf == null:
			return {"ok": false, "reason": "无法读取 world.json"}
		var wf_len: int = maxi(0, int(wf.get_length()))
		var wbytes: PackedByteArray = wf.get_buffer(wf_len) if wf_len > 0 else PackedByteArray()
		wf.close()
		var parsed: Dictionary = _parse_and_validate_world_json(wbytes)
		if not bool(parsed.get("ok", false)):
			return {"ok": false, "reason": str(parsed.get("reason", "world.json 无效"))}
		var base_dir: String = clean_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(base_dir):
			return {"ok": false, "reason": "world.json 所在目录不存在"}
		_source_kind = "dir"
		_root_path = base_dir
		_root_name = base_dir.get_file()
		_root_prefix = ""
		_source_bytes = src_len
		_world_json_bytes = wbytes
		_world_json = parsed["doc"]
		var scan_res: Dictionary = _scan_dir_recursive(base_dir, "")
		if not bool(scan_res.get("ok", false)):
			close()
			return scan_res
		return {
			"ok": true,
			"source_kind": _source_kind,
			"root_name": _root_name,
			"world_json_bytes": _world_json_bytes,
			"world_json": _world_json,
			"source_bytes": _source_bytes,
			"decoded_bytes": _dir_decoded_bytes,
			"file_count": _exact_entries.size(),
			"warnings": _open_warnings.duplicate(),
		}
	elif ext == "zip":
		return _open_zip_archive(clean_path, src_len)

	return {"ok": false, "reason": "不支持的文件格式：%s" % ext}


func _resolve_exact_key(rel_path: String) -> String:
	var norm: String = _normalize_rel_path(rel_path)
	if norm.is_empty():
		return ""
	if _exact_entries.has(norm):
		return norm
	var low: String = norm.to_lower()
	if _lower_to_exact.has(low):
		return str(_lower_to_exact[low])
	return ""


func has_file(rel_path: String) -> bool:
	return not _resolve_exact_key(rel_path).is_empty()


func read_bytes(rel_path: String) -> PackedByteArray:
	_last_read_error = ""
	var key: String = _resolve_exact_key(rel_path)
	if key.is_empty():
		return PackedByteArray()
	if _source_kind == "zip":
		if _zip_file == null:
			_last_read_error = "zip_source_closed"
			return PackedByteArray()
		var raw_entry: String = str(_exact_entries[key])
		var read_res: Dictionary = _read_zip_entry_bytes(raw_entry)
		if not bool(read_res.get("ok", false)):
			_last_read_error = str(read_res.get("reason", "zip_read_failed"))
			return PackedByteArray()
		return read_res["data"]
	elif _source_kind == "dir":
		var abs_file: String = str(_exact_entries[key])
		if not FileAccess.file_exists(abs_file):
			return PackedByteArray()
		var f: FileAccess = FileAccess.open(abs_file, FileAccess.READ)
		if f == null:
			return PackedByteArray()
		var length: int = maxi(0, int(f.get_length()))
		var data: PackedByteArray = f.get_buffer(length) if length > 0 else PackedByteArray()
		f.close()
		return data
	return PackedByteArray()


func read_text(rel_path: String) -> String:
	var raw: PackedByteArray = read_bytes(rel_path)
	if raw.is_empty():
		return ""
	var clean: PackedByteArray = strip_utf8_bom(raw)
	if not is_valid_utf8(clean):
		return ""
	return clean.get_string_from_utf8()


func list_files(prefix: String = "") -> PackedStringArray:
	var norm_prefix: String = _normalize_rel_path(prefix)
	var out: Array[String] = []
	if norm_prefix.is_empty():
		for k: Variant in _exact_entries.keys():
			out.append(str(k))
	else:
		var match_prefix: String = norm_prefix + "/"
		for k: Variant in _exact_entries.keys():
			var ks: String = str(k)
			if ks.begins_with(match_prefix) or ks == norm_prefix:
				out.append(ks)
	out.sort()
	return PackedStringArray(out)


func list_subdirs(prefix: String = "") -> PackedStringArray:
	var norm_prefix: String = _normalize_rel_path(prefix)
	var out: Array[String] = []
	var seen: Dictionary = {}
	if norm_prefix.is_empty():
		for d: Variant in _dirs_set.keys():
			var ds: String = str(d)
			var slash: int = ds.find("/")
			var top: String = ds if slash < 0 else ds.substr(0, slash)
			if not top.is_empty() and not seen.has(top):
				seen[top] = true
				out.append(top)
	else:
		var match_prefix: String = norm_prefix + "/"
		for d: Variant in _dirs_set.keys():
			var ds2: String = str(d)
			if ds2.begins_with(match_prefix):
				var rest: String = ds2.substr(match_prefix.length())
				var slash2: int = rest.find("/")
				var child: String = rest if slash2 < 0 else rest.substr(0, slash2)
				if not child.is_empty():
					var full_child: String = match_prefix + child
					if not seen.has(full_child):
						seen[full_child] = true
						out.append(full_child)
	out.sort()
	return PackedStringArray(out)


func resolve_asset_ref(ref: String, world_id: String = "") -> Dictionary:
	var s: String = ref.strip_edges()
	if s.is_empty():
		return {"kind": "empty", "rel_path": "", "url": "", "exists": false, "unsafe": false, "ext": ""}
	var low: String = s.to_lower()
	if low.begins_with("http://") or low.begins_with("https://"):
		var url_no_q: String = s
		var q_pos: int = url_no_q.find("?")
		var h_pos: int = url_no_q.find("#")
		var cut: int = -1
		if q_pos >= 0 and h_pos >= 0:
			cut = mini(q_pos, h_pos)
		elif q_pos >= 0:
			cut = q_pos
		elif h_pos >= 0:
			cut = h_pos
		if cut >= 0:
			url_no_q = url_no_q.substr(0, cut)
		return {
			"kind": "remote",
			"rel_path": "",
			"url": s,
			"exists": true,
			"unsafe": false,
			"ext": url_no_q.get_extension().to_lower(),
		}
	if low.begins_with("user://") or low.begins_with("file://") or low.begins_with("res://") or low.begins_with("data:"):
		return {"kind": "unsafe", "rel_path": "", "url": s, "exists": false, "unsafe": true, "ext": ""}

	var stripped: String = s
	var q2: int = stripped.find("?")
	var h2: int = stripped.find("#")
	var cut2: int = -1
	if q2 >= 0 and h2 >= 0:
		cut2 = mini(q2, h2)
	elif q2 >= 0:
		cut2 = q2
	elif h2 >= 0:
		cut2 = h2
	if cut2 >= 0:
		stripped = stripped.substr(0, cut2)

	var dec_res: Dictionary = _percent_decode_utf8(stripped)
	if not bool(dec_res.get("ok", false)):
		return {"kind": "unsafe", "rel_path": "", "url": s, "exists": false, "unsafe": true, "ext": ""}
	var decoded: String = str(dec_res["text"]).replace("\\", "/").strip_edges()
	while decoded.begins_with("/"):
		decoded = decoded.substr(1)
	if decoded.is_empty():
		return {"kind": "empty", "rel_path": "", "url": "", "exists": false, "unsafe": false, "ext": ""}
	if decoded.contains(":"):
		return {"kind": "unsafe", "rel_path": "", "url": s, "exists": false, "unsafe": true, "ext": ""}
	for seg: String in decoded.split("/", false):
		if seg == "..":
			return {"kind": "unsafe", "rel_path": "", "url": s, "exists": false, "unsafe": true, "ext": ""}

	var norm: String = _normalize_rel_path(decoded)
	if norm.is_empty():
		return {"kind": "unsafe", "rel_path": "", "url": s, "exists": false, "unsafe": true, "ext": ""}

	var candidates: Array[String] = []
	var norm_low: String = norm.to_lower()
	if not world_id.strip_edges().is_empty():
		var wp: String = "worlds/" + world_id.strip_edges().to_lower() + "/"
		if norm_low.begins_with(wp):
			candidates.append(norm.substr(wp.length()))
	if not _root_name.strip_edges().is_empty():
		var rp: String = "worlds/" + _root_name.strip_edges().to_lower() + "/"
		if norm_low.begins_with(rp):
			var cand_r: String = norm.substr(rp.length())
			if not (cand_r in candidates):
				candidates.append(cand_r)
	if not (norm in candidates):
		candidates.append(norm)

	for cand: String in candidates:
		var exact: String = _resolve_exact_key(cand)
		if not exact.is_empty():
			return {
				"kind": "local",
				"rel_path": exact,
				"url": "",
				"exists": true,
				"unsafe": false,
				"ext": exact.get_extension().to_lower(),
			}

	var primary: String = candidates[0] if not candidates.is_empty() else norm
	var primary_low: String = primary.to_lower()
	if (
		primary_low.begins_with("assets/")
		or primary_low.begins_with("systems/")
		or primary_low.begins_with("icons/")
		or primary_low.begins_with("modules/")
	):
		return {
			"kind": "system",
			"rel_path": primary,
			"url": "",
			"exists": false,
			"unsafe": false,
			"ext": primary.get_extension().to_lower(),
		}

	return {
		"kind": "local",
		"rel_path": primary,
		"url": "",
		"exists": false,
		"unsafe": false,
		"ext": primary.get_extension().to_lower(),
	}
