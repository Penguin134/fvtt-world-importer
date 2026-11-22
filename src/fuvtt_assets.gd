extends RefCounted

const _MAX_IMAGE_BYTES: int = 512 * 1024 * 1024
const _MAX_SVG_BYTES: int = 2 * 1024 * 1024
const _MAX_SVG_USE_NODES: int = 10000
const _MAX_IMAGE_SIDE: int = 32768
const _MAX_IMAGE_PIXELS: int = 134217728
const _SHARED_ASSET_STORE_PATH: String = "res://services/storage/SharedAssetStore.cs"
const _SVG_NAMESPACE: String = "http://www.w3.org/2000/svg"
const _PNG_CL_ORDER: Array[int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
const _PNG_LEN_BASE: Array[int] = [
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13,
	15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
	67, 83, 99, 115, 131, 163, 195, 227, 258
]
const _PNG_LEN_EXTRA: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
	1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
	4, 4, 4, 4, 5, 5, 5, 5, 0
]
const _PNG_DIST_BASE: Array[int] = [
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25,
	33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
	1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
]
const _PNG_DIST_EXTRA: Array[int] = [
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3,
	4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
	9, 9, 10, 10, 11, 11, 12, 12, 13, 13
]
const _VP8L_CL_ORDER: Array[int] = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const _VP8L_CODE_TO_PLANE_HEX: String = (
	"1807171928062729161a262a38053739151b363a252b48044749141c353b464a"
	+ "242c58454b343c035759131d565a232d444c555b333d68026769121e666a222e"
	+ "545c434d656b323e78017779535d111f646c424e767a212f757b313f636d525e"
	+ "00747c414f1020626e30737d515f40727e616f50717f6070"
)
const _VP8_COEFF_BANDS: Array[int] = [0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7]
const _VP8_PCAT_FLAT: Array[int] = [
	159,
	165, 145,
	173, 148, 140,
	176, 155, 140, 135,
	180, 157, 141, 134, 130,
	254, 254, 243, 230, 196, 177, 153, 140, 133, 130, 129,
]
const _VP8_PCAT_OFFS: Array[int] = [0, 1, 3, 6, 10, 15, 26]
const _VP8_DEFAULT_COEFF_HEX: String = (
	"8080808080808080808080808080808080808080808080808080808080808080"
	+ "80fd88feffe4db8080808080bd81f2ffe3d5ffdb8080806a7ee3fcd6d1ffff80"
	+ "80800162f8ffece2ffff808080b585eefeddeaff9a8080804e86caf7c6b4ffdb"
	+ "80808001b9f9fff3ff8080808080b896f7ffece080808080804d6ed8ffece680"
	+ "808080800165fbfff1ff8080808080aa8bf1fcecd1ffff8080802574c4f3e4ff"
	+ "ffff80808001ccfefff5ff8080808080cfa0faffee8080808080806667e7ffd3"
	+ "ab80808080800198fcfff0ff8080808080b187f3ffeae180808080805081d3ff"
	+ "c2e080808080800101ff8080808080808080f601ff8080808080808080ff8080"
	+ "8080808080808080c623eddfc1bba2a0919b3e832dc6ddacb0dc9dfcdd01442f"
	+ "92d095a7dda2ffdf800195f1ffdde0ffff808080b88deafddedcffc780808051"
	+ "63b5f2b0bef9caffff800181e8fdd6c5f2c4ffff806379d2fac9c6ffca808080"
	+ "175ba3f2aabbf7d2ffff8001c8f6ffeaff80808080806db2f1ffe7f5ffff8080"
	+ "802c82c9fdcdc0ffff8080800184effbdbd1ffa58080805e88e1fbdabeffff80"
	+ "80801664aef5baa1ffc780808001b6f9ffe8eb80808080807c8ff1ffe3ea8080"
	+ "808080234db5fbc1d3ffcd808080019df7ffece7ffff808080798debffe1e3ff"
	+ "ff8080802d63bcfbc3d9ffe08080800101fbffd5ff8080808080cb01f8ffff80"
	+ "80808080808901b1ffe0ff8080808080fd09f8fbcfd0ffc0808080af0de0f3c1"
	+ "b9f9c6ffff804911abdda1b3eca7ffea80015ff7fdd4b7ffff808080ef5af4fa"
	+ "d3d1ffff8080809b4dc3f8bcc3ffff8080800118effbdadbffcd808080c933db"
	+ "ffc4ba8080808080452ebeefc9daffe480808001bffbffff808080808080dfa5"
	+ "f9ffd5ff80808080808d7cf8ffff8080808080800110f8ffff808080808080be"
	+ "24e6ffecff80808080809501ff808080808080808001e2ff8080808080808080"
	+ "f7c0ff8080808080808080f080ff80808080808080800186fcffff8080808080"
	+ "80d53efaffff808080808080375dff8080808080808080808080808080808080"
	+ "808080808080808080808080808080808080808080808080ca18d5ebbabfdca0"
	+ "f0afff7e26b6e8a9b8e4aeffbb803d2e8adb97b2f0aaffd8800170e6fac7bff7"
	+ "9fffff80a66de4fcd3d7ffae808080274da2e8acb4f5b2ffff800134dcf6c6c7"
	+ "f9dcffff807c4abff3b7c1faddffff80184782db9aaaf3b6ffff8001b6e1f9db"
	+ "f0ffe08080809596e2fcd8cdffab8080801c6caaf2b7c2fedfffff800151e6fc"
	+ "cccbffc08080807b66d1f7bcc4ffe9808080145f99f3a4adffcb80808001def8"
	+ "ffd8d58080808080a8aff6fcebcdffff8080802f74d7ffd3d4ffff8080800179"
	+ "ecfdd4d6ffff8080808d54d5fcc9caffdb8080802a50a0f0a2b9ffcd80808001"
	+ "01ff8080808080808080f401ff8080808080808080ee01ff8080808080808080"
)
const _VP8_KF_BMODE_HEX: String = (
	"e7783059737178987098b3407eaa762e465faf458f505552489b67383a0aabda"
	+ "bd110d9890470a26abd590221a721a11a32cc3150aad791850c31a3e2c4055aa"
	+ "2e371388a021ce473f14087272d00c09e251280b60b6541d102486b759896265"
	+ "6aa59448bb64829d6f204b504266a7634a3e28ea80293509b2f18d1a086b684f"
	+ "0c1bd9ff5711074a2b1a9249a631179d412669a033341f73805744472c72330f"
	+ "ba172f290e6eb6b71511c2422d1966c5bd171216585893962a2e2dc4cd2b61b7"
	+ "75552623b33d2735c8571a152be8ab3822336872661d5d4d6b36201a3301512b"
	+ "1f271c55ab3aa55a6240221674ce17222ba64944196a1640ab24e17222131566"
	+ "84bc104c7c3e124e5f5539323033c165239fd76f592e6f3c941facdbe415126f"
	+ "70714d55b3ff267872282a01c4f5d10a196d6450082b9a01331a47582b1d8ca6"
	+ "d5252b9a3d3f1e9b432d4401d18e4e4e10ff8022c5ab29280566d3b70401dd33"
	+ "3211a8d1c01719527d622a58685575af525f543559806471652d4b4f7b2f3380"
	+ "51ab013911054766393529317315020a66ffa6170626210d7939491a0155290a"
	+ "438a4d6e5a2f72651d100a558065c41a39120a6666d522142b75140f24a38044"
	+ "011a8a1f24ab1ba6262ce543573aa952731a3bb33f3b5ab43ba65d499a282815"
	+ "748fd12227af392e161880013611252f0f10b722df312db72e1121b706620f20"
	+ "b7412049731c801780cd2803097333c01206df572509733b4d40152f68372cda"
	+ "09363582e2405a46cd2829171a39363970b8052926a6d51e221a8598740a2086"
	+ "4b200c33c0ffa02b33271335dd1a722049ff1f0941ea020f017649581f234366"
	+ "5537ba553815176f3bcd2d25c03726467c4966012262663d472522351ff3c045"
	+ "3c472649771cde25442d8022012f0bf5ab3e1113469255373e464b0f090940ff"
	+ "b87710252b259a64a355a0013f095c881c4020c95556061c0540ff19f8013808"
	+ "118489ff3774803a0f145287391a7928a4321f899a851923da33672c83837b1f"
	+ "069e5628408794e02db780161a1183f09a0e01d1530c0d36c0ff442f1c2d1015"
	+ "5b40de0701c53815279b3c8a1766d5551a555580802092ab120b073f90ab0404"
	+ "f6231b0a92aeab0c1a80be502363b4507e362d557e2f57b033291420654b808b"
	+ "769274805538290fb0ec5525093e9224131eabff611b14471e117776ff11128a"
	+ "65263c8a37462b1a8e8a2d3d3edb0151bc4020291475978e1415a370130c3dc3"
	+ "80300418"
)
const _VP8_COEFF_UPDATE_HEX: String = (
	"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "ffb0f6ffffffffffffffffffdff1fcfffffffffffffffff9fdfdffffffffffff"
	+ "fffffff4fcffffffffffffffffeafefefffffffffffffffffdffffffffffffff"
	+ "fffffffff6feffffffffffffffffeffdfefffffffffffffffffefffeffffffff"
	+ "fffffffffff8fefffffffffffffffffbfffeffffffffffffffffffffffffffff"
	+ "fffffffffffffdfefffffffffffffffffbfefefffffffffffffffffefffeffff"
	+ "fffffffffffffffefdfffefffffffffffffafffefffefffffffffffffeffffff"
	+ "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "ffffffffffffffffd9ffffffffffffffffffffe1fcf1fdfffffeffffffffeafa"
	+ "f1fafdfffdfefffffffffeffffffffffffffffffdffefeffffffffffffffffee"
	+ "fdfefefffffffffffffffff8fefffffffffffffffff9feffffffffffffffffff"
	+ "fffffffffffffffffffffffffdfffffffffffffffffff7feffffffffffffffff"
	+ "fffffffffffffffffffffffffffdfefffffffffffffffffcffffffffffffffff"
	+ "fffffffffffffffffffffffffffffefefffffffffffffffffdffffffffffffff"
	+ "fffffffffffffffffffffffffffffffefdfffffffffffffffffaffffffffffff"
	+ "fffffffffeffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "ffffffffffffffffffffffffffffffffbafbfaffffffffffffffffeafbf4feff"
	+ "fffffffffffffbfbf3fdfefffefffffffffffdfeffffffffffffffffecfdfeff"
	+ "fffffffffffffffbfdfdfefefffffffffffffffefefffffffffffffffffefefe"
	+ "fffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffefe"
	+ "fffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffe"
	+ "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	+ "fffffffffffffffffffffffffffffffffffffffffffffffff8ffffffffffffff"
	+ "fffffffafefcfefffffffffffffff8fef9fdfffffffffffffffffdfdffffffff"
	+ "fffffffff6fdfdfffffffffffffffffcfefbfefefffffffffffffffefcffffff"
	+ "fffffffffff8fefdfffffffffffffffffdfffefefffffffffffffffffbfeffff"
	+ "fffffffffffff5fbfefffffffffffffffffdfdfefffffffffffffffffffbfdff"
	+ "fffffffffffffffcfdfefffffffffffffffffffefffffffffffffffffffffcff"
	+ "fffffffffffffffff9fffefffffffffffffffffffffeffffffffffffffffffff"
	+ "fdfffffffffffffffffaffffffffffffffffffffffffffffffffffffffffffff"
	+ "fffffffffffffffffffffeffffffffffffffffffffffffffffffffffffffffff"
)

var _ref_cache: Dictionary = {}
var _hash_cache: Dictionary = {}
var _prep_cache: Dictionary = {}
var _published_files: Array[String] = []
var _shared_asset_store: Variant = null
var _allow_mock_store: bool = false
var _crc32_table: PackedInt64Array = PackedInt64Array()
var _png_fixed_lit: Dictionary = {}
var _png_fixed_dist: Dictionary = {}
var _vp8l_code_to_plane: PackedByteArray = PackedByteArray()
var _vp8_default_coeffs: PackedInt32Array = PackedInt32Array()
var _vp8_kf_bmode: PackedInt32Array = PackedInt32Array()
var _vp8_coeff_update: PackedInt32Array = PackedInt32Array()
var _vp8_norm_shift: PackedInt32Array = PackedInt32Array()
var _vp8_pcat_flat: PackedInt32Array = PackedInt32Array()


func set_shared_asset_store(store: Variant, allow_mock: bool = false) -> void:
	_shared_asset_store = store
	_allow_mock_store = allow_mock


func cleanup_published() -> void:
	for p: String in _published_files:
		if not p.is_empty() and FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_published_files.clear()
	_ref_cache.clear()
	_hash_cache.clear()
	_prep_cache.clear()


func _coerce_bool(value: Variant, fallback: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value == true
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			var num: float = float(value)
			if is_nan(num):
				return fallback
			return num != 0.0
		TYPE_STRING:
			var normalized: String = str(value).strip_edges().to_lower()
			match normalized:
				"true", "1", "yes", "on":
					return true
				"false", "0", "no", "off":
					return false
				_:
					return fallback
		_:
			return fallback


func _coerce_string(value: Variant, fallback: String = "") -> String:
	if typeof(value) == TYPE_STRING:
		return str(value)
	return fallback


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		ctx.update(bytes)
	return ctx.finish().hex_encode()


func _u16_le(bytes: PackedByteArray, off: int) -> int:
	return int(bytes[off]) | (int(bytes[off + 1]) << 8)


func _u32_le(bytes: PackedByteArray, off: int) -> int:
	return (
		int(bytes[off])
		| (int(bytes[off + 1]) << 8)
		| (int(bytes[off + 2]) << 16)
		| (int(bytes[off + 3]) << 24)
	)


func _u16_be(bytes: PackedByteArray, off: int) -> int:
	return (int(bytes[off]) << 8) | int(bytes[off + 1])


func _u32_be(bytes: PackedByteArray, off: int) -> int:
	return (
		(int(bytes[off]) << 24)
		| (int(bytes[off + 1]) << 16)
		| (int(bytes[off + 2]) << 8)
		| int(bytes[off + 3])
	)


func _valid_dimensions(w: int, h: int) -> bool:
	if w < 1 or h < 1 or w > _MAX_IMAGE_SIDE or h > _MAX_IMAGE_SIDE:
		return false
	if w * h > _MAX_IMAGE_PIXELS:
		return false
	return true


func _strip_bom(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		if bytes.size() == 3:
			return PackedByteArray()
		return bytes.slice(3, bytes.size())
	return bytes


func _parse_svg_length(raw: String) -> float:
	var s: String = raw.strip_edges().to_lower()
	if s.is_empty() or s.ends_with("%"):
		return -1.0
	var scale: float = 1.0
	if s.ends_with("px"):
		s = s.substr(0, s.length() - 2).strip_edges()
	elif s.ends_with("pt"):
		s = s.substr(0, s.length() - 2).strip_edges()
		scale = 96.0 / 72.0
	elif s.ends_with("pc"):
		s = s.substr(0, s.length() - 2).strip_edges()
		scale = 16.0
	elif s.ends_with("in"):
		s = s.substr(0, s.length() - 2).strip_edges()
		scale = 96.0
	elif s.ends_with("cm"):
		s = s.substr(0, s.length() - 2).strip_edges()
		scale = 96.0 / 2.54
	elif s.ends_with("mm"):
		s = s.substr(0, s.length() - 2).strip_edges()
		scale = 96.0 / 25.4
	elif s.ends_with("q"):
		s = s.substr(0, s.length() - 1).strip_edges()
		scale = 96.0 / 101.6
	if s.is_empty() or not s.is_valid_float():
		return -1.0
	var v: float = s.to_float() * scale
	if not is_finite(v) or v <= 0.0:
		return -1.0
	return v


func _ensure_crc32_table() -> PackedInt64Array:
	if _crc32_table.size() == 256:
		return _crc32_table
	var tbl := PackedInt64Array()
	tbl.resize(256)
	for n_i: int in range(256):
		var c: int = n_i
		for k: int in range(8):
			if (c & 1) != 0:
				c = 0xEDB88320 ^ ((c >> 1) & 0x7FFFFFFF)
			else:
				c = (c >> 1) & 0x7FFFFFFF
		tbl[n_i] = c & 0xFFFFFFFF
	_crc32_table = tbl
	return _crc32_table


func _crc32_range(bytes: PackedByteArray, start: int, length: int) -> int:
	var tbl: PackedInt64Array = _ensure_crc32_table()
	var c: int = 0xFFFFFFFF
	for i: int in range(start, start + length):
		var idx: int = (c ^ int(bytes[i])) & 0xFF
		c = ((c >> 8) & 0x00FFFFFF) ^ int(tbl[idx])
	return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF


func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var n: int = bytes.size()
	var i: int = 0
	while i < n:
		var b0: int = int(bytes[i])
		if b0 <= 0x7F:
			if b0 < 0x20 and b0 != 0x09 and b0 != 0x0A and b0 != 0x0D:
				return false
			i += 1
		elif b0 >= 0xC2 and b0 <= 0xDF:
			if i + 1 >= n:
				return false
			var b1: int = int(bytes[i + 1])
			if b1 < 0x80 or b1 > 0xBF:
				return false
			i += 2
		elif b0 >= 0xE0 and b0 <= 0xEF:
			if i + 2 >= n:
				return false
			var b1: int = int(bytes[i + 1])
			var b2: int = int(bytes[i + 2])
			if b2 < 0x80 or b2 > 0xBF:
				return false
			if b0 == 0xE0:
				if b1 < 0xA0 or b1 > 0xBF:
					return false
			elif b0 == 0xED:
				if b1 < 0x80 or b1 > 0x9F:
					return false
			else:
				if b1 < 0x80 or b1 > 0xBF:
					return false
			i += 3
		elif b0 >= 0xF0 and b0 <= 0xF4:
			if i + 3 >= n:
				return false
			var b1: int = int(bytes[i + 1])
			var b2: int = int(bytes[i + 2])
			var b3: int = int(bytes[i + 3])
			if b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF:
				return false
			if b0 == 0xF0:
				if b1 < 0x90 or b1 > 0xBF:
					return false
			elif b0 == 0xF4:
				if b1 < 0x80 or b1 > 0x8F:
					return false
			else:
				if b1 < 0x80 or b1 > 0xBF:
					return false
			i += 4
		else:
			return false
	return true


func _is_valid_xml_name(name: String) -> bool:
	if name.is_empty():
		return false
	for i: int in range(name.length()):
		var c: int = name.unicode_at(i)
		if c <= 0x20 or c == 0x3C or c == 0x3E or c == 0x2F or c == 0x22 or c == 0x27 or c == 0x3D or c == 0x26:
			return false
	return true


func _is_valid_xml_qname(name: String) -> bool:
	if not _is_valid_xml_name(name):
		return false
	var colon_idx: int = name.find(":")
	if colon_idx == 0 or colon_idx == name.length() - 1:
		return false
	if colon_idx > 0 and name.find(":", colon_idx + 1) >= 0:
		return false
	return true


func _has_malformed_xml_tags(text: String) -> bool:
	var n: int = text.length()
	var i: int = 0
	while i < n:
		var lt: int = text.find("<", i)
		if lt < 0:
			break
		if text.substr(lt, 4) == "<!--":
			var end_c: int = text.find("-->", lt + 4)
			if end_c < 0:
				return true
			i = end_c + 3
			continue
		if text.substr(lt, 9) == "<![CDATA[":
			var end_cd: int = text.find("]]>", lt + 9)
			if end_cd < 0:
				return true
			i = end_cd + 3
			continue
		if text.substr(lt, 2) == "<?":
			var end_pi: int = text.find("?>", lt + 2)
			if end_pi < 0:
				return true
			i = end_pi + 2
			continue
		var j: int = lt + 1
		var closed: bool = false
		while j < n:
			var ch: int = text.unicode_at(j)
			if ch == 0x22 or ch == 0x27:
				var q_char: String = "\"" if ch == 0x22 else "'"
				var next_q: int = text.find(q_char, j + 1)
				if next_q < 0:
					return true
				var next_lt: int = text.find("<", j + 1)
				if next_lt >= 0 and next_lt < next_q:
					return true
				j = next_q + 1
				continue
			if ch == 0x3C:
				return true
			if ch == 0x3E:
				closed = true
				j += 1
				break
			j += 1
		if not closed:
			return true
		i = j
	return false


func _escape_xml_text(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


func _escape_xml_attr(s: String) -> String:
	return _escape_xml_text(s).replace("\"", "&quot;")


func _normalize_namespaced_svg(clean_bytes: PackedByteArray, root_ns_prefix: String) -> PackedByteArray:
	var parser := XMLParser.new()
	if parser.open_buffer(clean_bytes) != OK:
		return clean_bytes
	var scope_stack: Array[Dictionary] = []
	var parts: PackedStringArray = PackedStringArray()
	var is_root: bool = true
	while true:
		var r: Error = parser.read()
		if r == ERR_FILE_EOF:
			break
		if r != OK:
			return clean_bytes
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var parent_scope: Dictionary = (scope_stack.back() as Dictionary) if not scope_stack.is_empty() else {}
				var cur_scope: Dictionary = parent_scope.duplicate()
				var attr_count: int = parser.get_attribute_count()
				var has_default_xmlns: bool = false
				for a_i: int in range(attr_count):
					var aname: String = parser.get_attribute_name(a_i)
					var aval: String = parser.get_attribute_value(a_i)
					if aname == "xmlns":
						has_default_xmlns = true
						cur_scope[""] = aval
					elif aname.begins_with("xmlns:"):
						var pfx: String = aname.substr(6)
						if not pfx.is_empty():
							cur_scope[pfx] = aval
				if is_root and not root_ns_prefix.is_empty() and not cur_scope.has(root_ns_prefix):
					cur_scope[root_ns_prefix] = _SVG_NAMESPACE
				var node_name: String = parser.get_node_name()
				var out_name: String = node_name
				var c_idx: int = node_name.find(":")
				if c_idx > 0:
					var elem_pfx: String = node_name.substr(0, c_idx)
					if str(cur_scope.get(elem_pfx, "")) == _SVG_NAMESPACE:
						out_name = node_name.substr(c_idx + 1)
				var parent_has_svg_default: bool = str(parent_scope.get("", "")) == _SVG_NAMESPACE
				var emitted_default_xmlns: bool = has_default_xmlns or parent_has_svg_default
				var tag_buf: String = "<" + out_name
				for a_i: int in range(attr_count):
					var aname: String = parser.get_attribute_name(a_i)
					var aval: String = parser.get_attribute_value(a_i)
					if aname.begins_with("xmlns:"):
						var decl_pfx: String = aname.substr(6)
						if not decl_pfx.is_empty() and aval == _SVG_NAMESPACE:
							if not emitted_default_xmlns:
								tag_buf += " xmlns=\"%s\"" % _escape_xml_attr(aval)
								emitted_default_xmlns = true
								cur_scope[""] = _SVG_NAMESPACE
							continue
					tag_buf += " %s=\"%s\"" % [aname, _escape_xml_attr(aval)]
				tag_buf += "/>" if parser.is_empty() else ">"
				parts.append(tag_buf)
				if not parser.is_empty():
					scope_stack.append(cur_scope)
				is_root = false
			XMLParser.NODE_ELEMENT_END:
				var end_scope: Dictionary = (scope_stack.pop_back() as Dictionary) if not scope_stack.is_empty() else {}
				var end_name: String = parser.get_node_name()
				var out_end: String = end_name
				var ec_idx: int = end_name.find(":")
				if ec_idx > 0:
					var end_pfx: String = end_name.substr(0, ec_idx)
					if str(end_scope.get(end_pfx, "")) == _SVG_NAMESPACE:
						out_end = end_name.substr(ec_idx + 1)
				parts.append("</%s>" % out_end)
			XMLParser.NODE_TEXT:
				parts.append(_escape_xml_text(parser.get_node_data()))
			XMLParser.NODE_CDATA:
				parts.append("<![CDATA[%s]]>" % parser.get_node_name())
			_:
				pass
	return "".join(parts).to_utf8_buffer()


func _validate_svg_use_graph(id_deps: Dictionary, top_uses: Array[String], all_uses: Array[String]) -> Dictionary:
	if id_deps.is_empty() and all_uses.is_empty():
		return {"ok": true}
	if all_uses.size() > _MAX_SVG_USE_NODES * 5:
		return {"ok": false, "unsupported": false, "reason": "svg_use_limit_exceeded"}

	var state: Dictionary = {}
	var memo: Dictionary = {}
	for start_var: Variant in id_deps.keys():
		var start_id: String = str(start_var)
		if int(state.get(start_id, 0)) == 2:
			continue
		var dfs_stack: Array = [[start_id, 0]]
		state[start_id] = 1
		while not dfs_stack.is_empty():
			var frame: Array = dfs_stack.back() as Array
			var cur: String = str(frame[0])
			var idx: int = int(frame[1])
			var children: Array = id_deps.get(cur, []) as Array
			if idx < children.size():
				frame[1] = idx + 1
				var nxt: String = str(children[idx])
				if not id_deps.has(nxt):
					continue
				var nst: int = int(state.get(nxt, 0))
				if nst == 1:
					return {"ok": false, "unsupported": false, "reason": "svg_use_cycle"}
				if nst == 0:
					state[nxt] = 1
					dfs_stack.append([nxt, 0])
			else:
				var total: int = 1
				for ch_var: Variant in children:
					total += int(memo.get(str(ch_var), 1))
					if total > _MAX_SVG_USE_NODES:
						return {"ok": false, "unsupported": false, "reason": "svg_use_limit_exceeded"}
				memo[cur] = total
				state[cur] = 2
				dfs_stack.pop_back()

	var top_total: int = 0
	for u_id: String in top_uses:
		top_total += int(memo.get(u_id, 1))
		if top_total > _MAX_SVG_USE_NODES:
			return {"ok": false, "unsupported": false, "reason": "svg_use_limit_exceeded"}

	var all_total: int = 0
	var all_cap: int = _MAX_SVG_USE_NODES * 5
	for u_all: String in all_uses:
		all_total += int(memo.get(u_all, 1))
		if all_total > all_cap:
			return {"ok": false, "unsupported": false, "reason": "svg_use_limit_exceeded"}

	return {"ok": true}


func _inspect_svg_bytes(raw_bytes: PackedByteArray) -> Dictionary:
	if raw_bytes.size() > _MAX_SVG_BYTES:
		return {"ok": false, "unsupported": false, "reason": "svg_too_large"}
	var clean_bytes: PackedByteArray = _strip_bom(raw_bytes)
	if clean_bytes.is_empty():
		return {"ok": false, "unsupported": false, "reason": "empty_image_bytes"}
	# Binary guard: SVG text must not contain NUL bytes and must be valid UTF-8.
	if clean_bytes.find(0) != -1:
		return {"ok": false, "unsupported": false, "reason": "unknown_or_corrupt_image"}
	if not _is_valid_utf8(clean_bytes):
		return {"ok": false, "unsupported": false, "reason": "invalid_svg_utf8"}

	# Safe to decode UTF-8 now that _is_valid_utf8 succeeded.
	var text: String = clean_bytes.get_string_from_utf8()
	var lower: String = text.to_lower()
	if lower.find("svg") < 0:
		return {"ok": false, "unsupported": false, "reason": "unknown_or_corrupt_image"}
	if lower.contains("<!entity") or lower.contains("<!doctype"):
		return {"ok": false, "unsupported": false, "reason": "unsafe_svg_dtd_or_entity"}
	if _has_malformed_xml_tags(text):
		return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}

	var parser := XMLParser.new()
	if parser.open_buffer(clean_bytes) != OK:
		return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}

	var tag_stack: Array[String] = []
	var tag_id_stack: Array[String] = []
	var id_deps: Dictionary = {}
	var top_uses: Array[String] = []
	var all_uses: Array[String] = []
	var root_seen: bool = false
	var root_closed: bool = false
	var ns_prefix: String = ""
	var needs_ns_norm: bool = false
	var svg_w_attr: String = ""
	var svg_h_attr: String = ""
	var svg_vb_attr: String = ""

	while true:
		var r: Error = parser.read()
		if r == ERR_FILE_EOF:
			break
		if r != OK:
			return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
		var ntype: XMLParser.NodeType = parser.get_node_type()
		match ntype:
			XMLParser.NODE_ELEMENT:
				var node_name: String = parser.get_node_name()
				if root_closed:
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
				if not root_seen:
					if not _is_valid_xml_name(node_name):
						return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
				else:
					if not _is_valid_xml_qname(node_name):
						return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
				var colon_pos: int = node_name.find(":")
				var local_name: String = node_name.substr(colon_pos + 1) if colon_pos >= 0 else node_name
				var is_use_elem: bool = (local_name == "use")
				var elem_id: String = ""
				var elem_use_refs: Array[String] = []
				var attr_count: int = parser.get_attribute_count()
				for a_i: int in range(attr_count):
					var aname: String = parser.get_attribute_name(a_i)
					var aval: String = parser.get_attribute_value(a_i)
					if not _is_valid_xml_qname(aname):
						return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
					if aname.begins_with("xmlns:") and aval == _SVG_NAMESPACE:
						var decl_pfx: String = aname.substr(6)
						if not decl_pfx.is_empty():
							needs_ns_norm = true
					if aname == "id":
						var tid_s: String = aval.strip_edges()
						if not tid_s.is_empty():
							elem_id = tid_s
					if is_use_elem:
						var aname_u_l: String = aname.to_lower()
						if aname_u_l == "href" or aname_u_l.ends_with(":href"):
							var href_s: String = aval.strip_edges()
							if href_s.begins_with("#") and href_s.length() > 1:
								elem_use_refs.append(href_s.substr(1))
					if not root_seen:
						var aname_l: String = aname.to_lower()
						if aname_l == "width":
							svg_w_attr = aval
						elif aname_l == "height":
							svg_h_attr = aval
						elif aname_l == "viewbox":
							svg_vb_attr = aval
				if not elem_id.is_empty() and not id_deps.has(elem_id):
					id_deps[elem_id] = []
				if not elem_use_refs.is_empty():
					for target_id: String in elem_use_refs:
						all_uses.append(target_id)
						var has_anc_id: bool = false
						for anc_id: String in tag_id_stack:
							if not anc_id.is_empty():
								(id_deps[anc_id] as Array).append(target_id)
								has_anc_id = true
						if not elem_id.is_empty():
							(id_deps[elem_id] as Array).append(target_id)
							has_anc_id = true
						if not has_anc_id:
							top_uses.append(target_id)
				if not root_seen:
					var colon_idx: int = node_name.find(":")
					var valid_root_qname: bool = (
						node_name == "svg"
						or (
							node_name.ends_with(":svg")
							and colon_idx > 0
							and node_name.find(":", colon_idx + 1) < 0
						)
					)
					if not valid_root_qname:
						return {"ok": false, "unsupported": false, "reason": "missing_svg_root"}
					if colon_idx > 0:
						ns_prefix = node_name.substr(0, colon_idx)
						needs_ns_norm = true
						var root_xmlns_key: String = "xmlns:" + ns_prefix
						var root_declared_ns_uri: String = ""
						for a_i: int in range(attr_count):
							if parser.get_attribute_name(a_i) == root_xmlns_key:
								root_declared_ns_uri = parser.get_attribute_value(a_i)
								break
						if not root_declared_ns_uri.is_empty() and root_declared_ns_uri != _SVG_NAMESPACE:
							return {"ok": false, "unsupported": false, "reason": "missing_svg_root"}
					root_seen = true
				if parser.is_empty():
					if tag_stack.is_empty():
						root_closed = true
				else:
					tag_stack.append(node_name)
					tag_id_stack.append(elem_id)
			XMLParser.NODE_ELEMENT_END:
				var end_name: String = parser.get_node_name()
				if not _is_valid_xml_qname(end_name) or tag_stack.is_empty():
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
				var top: String = tag_stack.pop_back()
				tag_id_stack.pop_back()
				if top != end_name:
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
				if tag_stack.is_empty():
					root_closed = true
			XMLParser.NODE_UNKNOWN:
				var unk: String = parser.get_node_name().strip_edges().to_lower()
				if unk.begins_with("!doctype") or unk.begins_with("!entity") or unk.begins_with("!element") or unk.begins_with("!attlist") or unk.begins_with("!notation"):
					return {"ok": false, "unsupported": false, "reason": "unsafe_svg_dtd_or_entity"}
				if not unk.begins_with("?"):
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
			XMLParser.NODE_TEXT:
				if (not root_seen or root_closed) and not parser.get_node_data().strip_edges().is_empty():
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
			XMLParser.NODE_CDATA:
				if not root_seen or root_closed:
					return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}
			_:
				pass

	if not root_seen or not root_closed or not tag_stack.is_empty():
		return {"ok": false, "unsupported": false, "reason": "malformed_svg_xml"}

	var use_res: Dictionary = _validate_svg_use_graph(id_deps, top_uses, all_uses)
	if not bool(use_res.get("ok", false)):
		return use_res

	var w_val: float = _parse_svg_length(svg_w_attr) if not svg_w_attr.is_empty() else -1.0
	var h_val: float = _parse_svg_length(svg_h_attr) if not svg_h_attr.is_empty() else -1.0

	if (w_val <= 0.0 or h_val <= 0.0) and not svg_vb_attr.is_empty():
		var vb_norm: String = svg_vb_attr.replace(",", " ").replace("\t", " ").replace("\n", " ").replace("\r", " ")
		var vb_parts: PackedStringArray = vb_norm.split(" ", false)
		if vb_parts.size() == 4 and vb_parts[2].is_valid_float() and vb_parts[3].is_valid_float():
			var vb_w: float = vb_parts[2].to_float()
			var vb_h: float = vb_parts[3].to_float()
			if is_finite(vb_w) and is_finite(vb_h) and vb_w > 0.0 and vb_h > 0.0:
				if w_val <= 0.0:
					w_val = vb_w
				if h_val <= 0.0:
					h_val = vb_h

	if w_val <= 0.0 or h_val <= 0.0:
		return {"ok": false, "unsupported": false, "reason": "invalid_svg_dimensions"}
	if w_val > float(_MAX_IMAGE_SIDE) or h_val > float(_MAX_IMAGE_SIDE):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
	var w_int: int = int(ceil(w_val))
	var h_int: int = int(ceil(h_val))
	if not _valid_dimensions(w_int, h_int):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
	var out: Dictionary = {"ok": true, "format": "svg", "w": w_int, "h": h_int}
	if needs_ns_norm:
		out["normalized_bytes"] = _normalize_namespaced_svg(clean_bytes, ns_prefix)
	return out


func _png_build_huffman(lengths: PackedInt32Array, tree_kind: int) -> Dictionary:
	var num_syms: int = lengths.size()
	var bl_count := PackedInt32Array()
	bl_count.resize(16)
	var total_non_zero: int = 0
	var max_len: int = 0
	for sym: int in range(num_syms):
		var cl: int = lengths[sym]
		if cl < 0 or cl > 15:
			return {"ok": false, "unsupported": false, "reason": "png_deflate_bad_codelen"}
		if cl > 0:
			bl_count[cl] += 1
			total_non_zero += 1
			if cl > max_len:
				max_len = cl
	if total_non_zero == 0:
		if tree_kind == 2:
			var empty_fast := PackedInt32Array()
			empty_fast.resize(512)
			empty_fast.fill(-1)
			return {"ok": true, "empty": true, "fast": empty_fast, "bl_count": bl_count, "sorted": PackedInt32Array()}
		return {"ok": false, "unsupported": false, "reason": "png_deflate_empty_huffman"}
	var left: int = 1
	for bits: int in range(1, 16):
		left <<= 1
		left -= bl_count[bits]
		if left < 0:
			return {"ok": false, "unsupported": false, "reason": "png_deflate_oversubscribed_huffman"}
	if left > 0:
		if tree_kind == 0 or max_len != 1:
			return {"ok": false, "unsupported": false, "reason": "png_deflate_incomplete_huffman"}
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


func _png_ensure_fixed_huffman() -> void:
	if not _png_fixed_lit.is_empty() and not _png_fixed_dist.is_empty():
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
	_png_fixed_lit = _png_build_huffman(lit_lens, 1)
	var dist_lens := PackedInt32Array()
	dist_lens.resize(32)
	for d: int in range(32):
		dist_lens[d] = 5
	_png_fixed_dist = _png_build_huffman(dist_lens, 2)


func _validate_png_idat_zlib(
	idat_bytes: PackedByteArray,
	expected_raw_bytes: int,
	pass_ends: Array[int],
	pass_strides: Array[int]
) -> Dictionary:
	var src_len: int = idat_bytes.size()
	if src_len < 7:
		return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
	var cmf: int = int(idat_bytes[0])
	var flg: int = int(idat_bytes[1])
	if (cmf & 0x0F) != 8 or (cmf >> 4) > 7 or (flg & 0x20) != 0 or (((cmf << 8) | flg) % 31) != 0:
		return {"ok": false, "unsupported": false, "reason": "invalid_png_zlib_header"}

	var max_win_dist: int = 1 << (((cmf >> 4) & 0x0F) + 8)
	var win := PackedByteArray()
	win.resize(32768)
	var out_pos: int = 0
	var s1: int = 1
	var s2: int = 0

	var pass_count: int = pass_ends.size()
	var p_idx: int = 0
	var next_filter_pos: int = 0
	var cur_pass_end: int = pass_ends[0]
	var cur_stride: int = pass_strides[0]

	var byte_pos: int = 2
	var bit_buf: int = 0
	var bit_cnt: int = 0
	var bfinal: int = 0

	while bfinal == 0:
		while bit_cnt < 3:
			if byte_pos >= src_len:
				return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
			bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
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
				return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
			var block_len: int = _u16_le(idat_bytes, byte_pos)
			var nlen: int = _u16_le(idat_bytes, byte_pos + 2)
			byte_pos += 4
			if (block_len ^ 0xFFFF) != nlen:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_stored_len"}
			if byte_pos + block_len > src_len:
				return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
			if out_pos + block_len > expected_raw_bytes:
				return {"ok": false, "unsupported": false, "reason": "png_idat_overflow"}
			for _k0: int in range(block_len):
				var b0: int = int(idat_bytes[byte_pos])
				byte_pos += 1
				if out_pos == next_filter_pos:
					if b0 > 4:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_filter"}
					next_filter_pos += cur_stride
					while p_idx < pass_count and next_filter_pos >= cur_pass_end:
						p_idx += 1
						if p_idx < pass_count:
							cur_pass_end = pass_ends[p_idx]
							cur_stride = pass_strides[p_idx]
				win[out_pos & 32767] = b0
				out_pos += 1
				s1 += b0
				if s1 >= 65521:
					s1 -= 65521
				s2 += s1
				if s2 >= 65521:
					s2 -= 65521
			continue

		if btype == 3:
			return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_btype"}

		var lit_huff: Dictionary
		var dist_huff: Dictionary
		if btype == 1:
			_png_ensure_fixed_huffman()
			lit_huff = _png_fixed_lit
			dist_huff = _png_fixed_dist
		else:
			while bit_cnt < 14:
				if byte_pos >= src_len:
					return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
				bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
				byte_pos += 1
				bit_cnt += 8
			var hlit: int = (bit_buf & 31) + 257
			var hdist: int = ((bit_buf >> 5) & 31) + 1
			var hclen: int = ((bit_buf >> 10) & 15) + 4
			bit_buf >>= 14
			bit_cnt -= 14
			if hlit > 286 or hdist > 30:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_counts"}

			var cl_lengths := PackedInt32Array()
			cl_lengths.resize(19)
			for c_i: int in range(hclen):
				while bit_cnt < 3:
					if byte_pos >= src_len:
						return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
					bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				cl_lengths[_PNG_CL_ORDER[c_i]] = bit_buf & 7
				bit_buf >>= 3
				bit_cnt -= 3

			var cl_huff: Dictionary = _png_build_huffman(cl_lengths, 0)
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
					bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var csym: int = -1
				var cf_entry: int = cl_fast[bit_buf & 511]
				if cf_entry >= 0:
					var c_clen: int = cf_entry & 15
					if c_clen > bit_cnt:
						return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
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
								return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
							bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
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
					return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_cl_code"}
				if csym < 16:
					all_lengths[idx_len] = csym
					idx_len += 1
				elif csym == 16:
					if idx_len == 0:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_repeat"}
					while bit_cnt < 2:
						if byte_pos >= src_len:
							return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
						bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep16: int = (bit_buf & 3) + 3
					bit_buf >>= 2
					bit_cnt -= 2
					if idx_len + rep16 > total_codes:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_repeat"}
					var prev_len: int = all_lengths[idx_len - 1]
					for _r16: int in range(rep16):
						all_lengths[idx_len] = prev_len
						idx_len += 1
				elif csym == 17:
					while bit_cnt < 3:
						if byte_pos >= src_len:
							return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
						bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep17: int = (bit_buf & 7) + 3
					bit_buf >>= 3
					bit_cnt -= 3
					if idx_len + rep17 > total_codes:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_repeat"}
					idx_len += rep17
				else:
					while bit_cnt < 7:
						if byte_pos >= src_len:
							return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
						bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
						byte_pos += 1
						bit_cnt += 8
					var rep18: int = (bit_buf & 127) + 11
					bit_buf >>= 7
					bit_cnt -= 7
					if idx_len + rep18 > total_codes:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_repeat"}
					idx_len += rep18

			var lit_lens_dyn: PackedInt32Array = all_lengths.slice(0, hlit)
			if lit_lens_dyn.size() <= 256 or lit_lens_dyn[256] <= 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_eob"}
			var dist_lens_dyn: PackedInt32Array = all_lengths.slice(hlit, total_codes)
			lit_huff = _png_build_huffman(lit_lens_dyn, 1)
			if not bool(lit_huff.get("ok", false)):
				return lit_huff
			dist_huff = _png_build_huffman(dist_lens_dyn, 2)
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
				bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
				byte_pos += 1
				bit_cnt += 8
			var sym: int = -1
			var f_entry: int = lit_fast[bit_buf & 511]
			if f_entry >= 0:
				var l_clen: int = f_entry & 15
				if l_clen > bit_cnt:
					return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
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
							return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
						bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
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
				return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_lit_code"}
			if sym < 256:
				if out_pos >= expected_raw_bytes:
					return {"ok": false, "unsupported": false, "reason": "png_idat_overflow"}
				if out_pos == next_filter_pos:
					if sym > 4:
						return {"ok": false, "unsupported": false, "reason": "invalid_png_filter"}
					next_filter_pos += cur_stride
					while p_idx < pass_count and next_filter_pos >= cur_pass_end:
						p_idx += 1
						if p_idx < pass_count:
							cur_pass_end = pass_ends[p_idx]
							cur_stride = pass_strides[p_idx]
				win[out_pos & 32767] = sym
				out_pos += 1
				s1 += sym
				if s1 >= 65521:
					s1 -= 65521
				s2 += s1
				if s2 >= 65521:
					s2 -= 65521
			elif sym == 256:
				break
			else:
				if sym > 285:
					return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_len_sym"}
				var lidx: int = sym - 257
				var lextra: int = _PNG_LEN_EXTRA[lidx]
				while bit_cnt < lextra:
					if byte_pos >= src_len:
						return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
					bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var mlen: int = _PNG_LEN_BASE[lidx] + (bit_buf & ((1 << lextra) - 1))
				bit_buf >>= lextra
				bit_cnt -= lextra

				while bit_cnt < 15 and byte_pos < src_len:
					bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var dsym: int = -1
				var df_entry: int = dist_fast[bit_buf & 511]
				if df_entry >= 0:
					var d_clen: int = df_entry & 15
					if d_clen > bit_cnt:
						return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
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
								return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
							bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
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
					return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_dist_sym"}
				var dextra: int = _PNG_DIST_EXTRA[dsym]
				while bit_cnt < dextra:
					if byte_pos >= src_len:
						return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
					bit_buf |= int(idat_bytes[byte_pos]) << bit_cnt
					byte_pos += 1
					bit_cnt += 8
				var dist: int = _PNG_DIST_BASE[dsym] + (bit_buf & ((1 << dextra) - 1))
				bit_buf >>= dextra
				bit_cnt -= dextra

				if dist < 1 or dist > max_win_dist or dist > out_pos:
					return {"ok": false, "unsupported": false, "reason": "invalid_png_deflate_distance"}
				if out_pos + mlen > expected_raw_bytes:
					return {"ok": false, "unsupported": false, "reason": "png_idat_overflow"}
				for _m: int in range(mlen):
					var mb: int = int(win[(out_pos - dist) & 32767])
					if out_pos == next_filter_pos:
						if mb > 4:
							return {"ok": false, "unsupported": false, "reason": "invalid_png_filter"}
						next_filter_pos += cur_stride
						while p_idx < pass_count and next_filter_pos >= cur_pass_end:
							p_idx += 1
							if p_idx < pass_count:
								cur_pass_end = pass_ends[p_idx]
								cur_stride = pass_strides[p_idx]
					win[out_pos & 32767] = mb
					out_pos += 1
					s1 += mb
					if s1 >= 65521:
						s1 -= 65521
					s2 += s1
					if s2 >= 65521:
						s2 -= 65521

	if out_pos != expected_raw_bytes:
		return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}

	var end_discard: int = bit_cnt & 7
	if end_discard > 0:
		bit_buf >>= end_discard
		bit_cnt -= end_discard
	byte_pos -= (bit_cnt >> 3)
	if byte_pos + 4 > src_len:
		return {"ok": false, "unsupported": false, "reason": "truncated_png_idat"}
	var expected_adler: int = _u32_be(idat_bytes, byte_pos)
	var actual_adler: int = ((s2 << 16) | s1) & 0xFFFFFFFF
	if actual_adler != expected_adler:
		return {"ok": false, "unsupported": false, "reason": "invalid_png_adler32"}
	return {"ok": true}


func _inspect_png_bytes(bytes: PackedByteArray) -> Dictionary:
	var n: int = bytes.size()
	if n < 33:
		return {"ok": false, "unsupported": false, "reason": "truncated_png"}
	var ihdr_len: int = _u32_be(bytes, 8)
	if ihdr_len != 13:
		return {"ok": false, "unsupported": false, "reason": "invalid_png_ihdr_length"}
	if bytes[12] != 0x49 or bytes[13] != 0x48 or bytes[14] != 0x44 or bytes[15] != 0x52:
		return {"ok": false, "unsupported": false, "reason": "missing_png_ihdr"}
	var w: int = _u32_be(bytes, 16)
	var h: int = _u32_be(bytes, 20)
	if not _valid_dimensions(w, h):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}

	var bit_depth: int = int(bytes[24])
	var color_type: int = int(bytes[25])
	var comp: int = int(bytes[26])
	var filt: int = int(bytes[27])
	var interlace: int = int(bytes[28])
	var valid_depth: bool = false
	var channels: int = 0
	match color_type:
		0:
			valid_depth = bit_depth in [1, 2, 4, 8, 16]
			channels = 1
		2:
			valid_depth = bit_depth in [8, 16]
			channels = 3
		3:
			valid_depth = bit_depth in [1, 2, 4, 8]
			channels = 1
		4:
			valid_depth = bit_depth in [8, 16]
			channels = 2
		6:
			valid_depth = bit_depth in [8, 16]
			channels = 4
		_:
			valid_depth = false
	if not valid_depth or comp != 0 or filt != 0 or (interlace != 0 and interlace != 1):
		return {"ok": false, "unsupported": false, "reason": "invalid_png_ihdr_fields"}

	var offset: int = 8
	var seen_iend: bool = false
	var seen_idat: bool = false
	var idat_finished: bool = false
	var has_nonempty_idat: bool = false
	var total_idat_len: int = 0
	var has_plte: bool = false
	var idat_bytes: PackedByteArray = PackedByteArray()

	while offset < n:
		if offset + 12 > n:
			return {"ok": false, "unsupported": false, "reason": "truncated_png_chunk"}
		var chunk_len: int = _u32_be(bytes, offset)
		if chunk_len < 0 or chunk_len > n - offset - 12:
			return {"ok": false, "unsupported": false, "reason": "truncated_png_chunk"}
		for t_i: int in range(4):
			var tb: int = int(bytes[offset + 4 + t_i])
			if not ((tb >= 65 and tb <= 90) or (tb >= 97 and tb <= 122)):
				return {"ok": false, "unsupported": false, "reason": "invalid_png_chunk_type"}
		var expected_crc: int = _u32_be(bytes, offset + 8 + chunk_len)
		var actual_crc: int = _crc32_range(bytes, offset + 4, 4 + chunk_len)
		if actual_crc != expected_crc:
			return {"ok": false, "unsupported": false, "reason": "invalid_png_crc"}

		var c0: int = int(bytes[offset + 4])
		var c1: int = int(bytes[offset + 5])
		var c2: int = int(bytes[offset + 6])
		var c3: int = int(bytes[offset + 7])

		if c0 == 0x49 and c1 == 0x48 and c2 == 0x44 and c3 == 0x52:
			# IHDR
			if offset > 8:
				return {"ok": false, "unsupported": false, "reason": "duplicate_png_ihdr"}
		elif c0 == 0x50 and c1 == 0x4C and c2 == 0x54 and c3 == 0x45:
			# PLTE
			if color_type == 0 or color_type == 4:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_plte"}
			if seen_idat:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_plte_order"}
			if has_plte:
				return {"ok": false, "unsupported": false, "reason": "duplicate_png_plte"}
			if chunk_len < 3 or chunk_len > 768 or (chunk_len % 3) != 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_plte"}
			if color_type == 3 and (chunk_len / 3) > (1 << bit_depth):
				return {"ok": false, "unsupported": false, "reason": "invalid_png_plte"}
			has_plte = true
		elif c0 == 0x49 and c1 == 0x44 and c2 == 0x41 and c3 == 0x54:
			# IDAT
			if idat_finished:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_idat_order"}
			if color_type == 3 and not has_plte:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_plte_order"}
			seen_idat = true
			if chunk_len > 0:
				has_nonempty_idat = true
				total_idat_len += chunk_len
				if total_idat_len > _MAX_IMAGE_BYTES:
					return {"ok": false, "unsupported": false, "reason": "image_too_large"}
				idat_bytes.append_array(bytes.slice(offset + 8, offset + 8 + chunk_len))
		elif c0 == 0x49 and c1 == 0x45 and c2 == 0x4E and c3 == 0x44:
			# IEND
			if chunk_len != 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_png_iend"}
			seen_iend = true
			break
		else:
			if not seen_idat:
				if (c2 & 0x20) != 0:
					return {"ok": false, "unsupported": false, "reason": "invalid_png_chunk_type"}
				if (c0 & 0x20) == 0:
					return {"ok": false, "unsupported": true, "reason": "unsupported_png_critical_chunk"}
			else:
				idat_finished = true

		offset += 12 + chunk_len

	if not seen_iend:
		return {"ok": false, "unsupported": false, "reason": "missing_png_iend"}
	if not has_nonempty_idat or total_idat_len < 7:
		return {"ok": false, "unsupported": false, "reason": "missing_png_idat"}
	if color_type == 3 and not has_plte:
		return {"ok": false, "unsupported": false, "reason": "missing_png_plte"}

	var bpp: int = bit_depth * channels
	var expected_raw_bytes: int = 0
	var pass_ends: Array[int] = []
	var pass_strides: Array[int] = []
	if interlace == 0:
		var stride: int = 1 + ((w * bpp + 7) / 8)
		expected_raw_bytes = stride * h
		pass_ends.append(expected_raw_bytes)
		pass_strides.append(stride)
	else:
		var adam7: Array = [
			[0, 8, 0, 8],
			[4, 8, 0, 8],
			[0, 4, 4, 8],
			[2, 4, 0, 4],
			[0, 2, 2, 4],
			[1, 2, 0, 2],
			[0, 1, 1, 2],
		]
		for ap: Array in adam7:
			var x_off: int = int(ap[0])
			var x_step: int = int(ap[1])
			var y_off: int = int(ap[2])
			var y_step: int = int(ap[3])
			if w > x_off and h > y_off:
				var pw: int = (w - x_off + x_step - 1) / x_step
				var ph: int = (h - y_off + y_step - 1) / y_step
				var p_stride: int = 1 + ((pw * bpp + 7) / 8)
				expected_raw_bytes += p_stride * ph
				pass_ends.append(expected_raw_bytes)
				pass_strides.append(p_stride)

	var idat_res: Dictionary = _validate_png_idat_zlib(idat_bytes, expected_raw_bytes, pass_ends, pass_strides)
	if not bool(idat_res.get("ok", false)):
		return idat_res

	return {"ok": true, "format": "png", "w": w, "h": h}


func _validate_jpg_dht_segment(
	bytes: PackedByteArray,
	seg_pos: int,
	seg_len: int,
	defined_dht_dc: Dictionary,
	defined_dht_ac: Dictionary
) -> String:
	if seg_len <= 2:
		return "invalid_jpg_dht"
	var off: int = seg_pos + 2
	var seg_end: int = seg_pos + seg_len
	while off < seg_end:
		if off + 17 > seg_end:
			return "invalid_jpg_dht"
		var tc_th: int = int(bytes[off])
		var tc: int = (tc_th >> 4) & 0x0F
		var th: int = tc_th & 0x0F
		if tc > 1 or th > 3:
			return "invalid_jpg_dht"
		var count: int = 0
		var kraft_sum: int = 0
		for i: int in range(1, 17):
			var c: int = int(bytes[off + i])
			count += c
			kraft_sum += c << (16 - i)
		if count > 256 or kraft_sum >= 65536 or off + 17 + count > seg_end:
			return "invalid_jpg_dht"
		if tc == 0:
			for k: int in range(count):
				if int(bytes[off + 17 + k]) > 15:
					return "invalid_jpg_dht"
			defined_dht_dc[th] = true
		else:
			defined_dht_ac[th] = true
		off += 17 + count
	if off != seg_end:
		return "invalid_jpg_dht"
	return ""


func _validate_jpg_dqt_segment(bytes: PackedByteArray, seg_pos: int, seg_len: int, defined_dqt: Dictionary) -> String:
	var q_off: int = seg_pos + 2
	var q_end: int = seg_pos + seg_len
	if q_off >= q_end:
		return "invalid_jpg_dqt"
	while q_off < q_end:
		var pq_tq: int = int(bytes[q_off])
		var pq: int = (pq_tq >> 4) & 0x0F
		var tq: int = pq_tq & 0x0F
		if pq > 1 or tq > 3:
			return "invalid_jpg_dqt"
		var tbl_bytes: int = 64 if pq == 0 else 128
		if q_off + 1 + tbl_bytes > q_end:
			return "invalid_jpg_dqt"
		defined_dqt[tq] = true
		q_off += 1 + tbl_bytes
	if q_off != q_end:
		return "invalid_jpg_dqt"
	return ""


func _validate_jpg_sos_header(
	bytes: PackedByteArray,
	sos_pos: int,
	n: int,
	sof_marker: int,
	sof_ncomp: int,
	sof_comp_blocks: Dictionary,
	sof_comp_order: Dictionary,
	defined_dht_dc: Dictionary,
	defined_dht_ac: Dictionary,
	seq_scanned_cs: Dictionary
) -> Dictionary:
	if sos_pos + 2 > n:
		return {"ok": false, "unsupported": false, "reason": "truncated_jpg_sos"}
	var sos_len: int = _u16_be(bytes, sos_pos)
	if sos_len < 6 or sos_pos + sos_len > n:
		return {"ok": false, "unsupported": false, "reason": "invalid_jpg_segment_length"}
	var ncomp_s: int = int(bytes[sos_pos + 2])
	if ncomp_s < 1 or ncomp_s > 4 or ncomp_s > sof_ncomp or sos_len != 6 + 2 * ncomp_s:
		return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
	var seen_cs: Dictionary = {}
	var mcu_blocks: int = 0
	var prev_order: int = -1
	for j: int in range(ncomp_s):
		var cs_id: int = int(bytes[sos_pos + 3 + 2 * j])
		var td_ta: int = int(bytes[sos_pos + 3 + 2 * j + 1])
		var td_s: int = (td_ta >> 4) & 0x0F
		var ta_s: int = td_ta & 0x0F
		if td_s > 3 or ta_s > 3:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		if sof_marker != 0xC2:
			if (td_s > 1 and not defined_dht_dc.has(td_s)) or (ta_s > 1 and not defined_dht_ac.has(ta_s)):
				return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		if not sof_comp_blocks.has(cs_id) or seen_cs.has(cs_id):
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		var cur_order: int = int(sof_comp_order.get(cs_id, -1))
		if cur_order <= prev_order:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		prev_order = cur_order
		if sof_marker != 0xC2 and seq_scanned_cs.has(cs_id):
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		seen_cs[cs_id] = true
		mcu_blocks += int(sof_comp_blocks[cs_id])
	if ncomp_s > 1 and mcu_blocks > 10:
		return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
	var ss: int = int(bytes[sos_pos + 3 + 2 * ncomp_s])
	var se: int = int(bytes[sos_pos + 4 + 2 * ncomp_s])
	var ah_al: int = int(bytes[sos_pos + 5 + 2 * ncomp_s])
	var ah: int = (ah_al >> 4) & 0x0F
	var al: int = ah_al & 0x0F
	if sof_marker == 0xC2:
		if (
			ss > 63
			or se > 63
			or ss > se
			or ah > 13
			or al > 13
			or (ss == 0 and se != 0)
			or (ss != 0 and ncomp_s != 1)
			or (ah != 0 and al != ah - 1)
		):
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
		for j: int in range(ncomp_s):
			var comp_td_ta: int = int(bytes[sos_pos + 3 + 2 * j + 1])
			var td: int = (comp_td_ta >> 4) & 0x0F
			var ta: int = comp_td_ta & 0x0F
			if ss == 0 and ah == 0 and not defined_dht_dc.has(td):
				return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
			if ss > 0 and not defined_dht_ac.has(ta):
				return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sos"}
	if sof_marker != 0xC2:
		for cs_key in seen_cs.keys():
			seq_scanned_cs[cs_key] = true
	return {"ok": true, "sos_len": sos_len}


func _inspect_jpg_bytes(bytes: PackedByteArray) -> Dictionary:
	var n: int = bytes.size()
	if n < 4 or bytes[2] != 0xFF:
		return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
	var pos: int = 2
	var has_sof: bool = false
	var has_dqt: bool = false
	var defined_dqt: Dictionary = {}
	var defined_dht_dc: Dictionary = {}
	var defined_dht_ac: Dictionary = {}
	var sof_marker: int = 0
	var sof_w: int = 0
	var sof_h: int = 0
	var sof_ncomp: int = 0
	var sof_comp_blocks: Dictionary = {}
	var sof_comp_order: Dictionary = {}
	var sof_tqs: Dictionary = {}
	var adobe_transform: int = -1
	var seq_scanned_cs: Dictionary = {}

	while pos < n:
		if bytes[pos] != 0xFF:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
		while pos < n and bytes[pos] == 0xFF:
			pos += 1
		if pos >= n:
			return {"ok": false, "unsupported": false, "reason": "truncated_jpg_marker"}
		var marker: int = int(bytes[pos])
		pos += 1
		if marker == 0x00:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
		if marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
			continue
		if marker == 0xD8:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
		if marker == 0xD9:
			return {"ok": false, "unsupported": false, "reason": "missing_jpg_sos"}
		if marker == 0xDA:
			# SOS (Start of Scan)
			if not has_sof:
				return {"ok": false, "unsupported": false, "reason": "missing_jpg_sof"}
			if not has_dqt:
				return {"ok": false, "unsupported": false, "reason": "missing_jpg_dqt"}
			for tq_key in sof_tqs.keys():
				if not defined_dqt.has(tq_key):
					return {"ok": false, "unsupported": false, "reason": "missing_jpg_dqt"}
			if sof_ncomp == 3 and adobe_transform >= 0 and adobe_transform != 0 and adobe_transform != 1:
				return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_colorspace"}
			var first_sos_res: Dictionary = _validate_jpg_sos_header(
				bytes,
				pos,
				n,
				sof_marker,
				sof_ncomp,
				sof_comp_blocks,
				sof_comp_order,
				defined_dht_dc,
				defined_dht_ac,
				seq_scanned_cs
			)
			if not bool(first_sos_res.get("ok", false)):
				return first_sos_res
			var scan_pos: int = pos + int(first_sos_res["sos_len"])
			var entropy_bytes: int = 0
			while scan_pos < n:
				var b: int = int(bytes[scan_pos])
				if b != 0xFF:
					entropy_bytes += 1
					scan_pos += 1
					continue
				while scan_pos < n and bytes[scan_pos] == 0xFF:
					scan_pos += 1
				if scan_pos >= n:
					return {"ok": false, "unsupported": false, "reason": "missing_jpg_eoi"}
				var sm: int = int(bytes[scan_pos])
				scan_pos += 1
				if sm == 0x00:
					entropy_bytes += 1
					continue
				if sm >= 0xD0 and sm <= 0xD7:
					continue
				if sm == 0xD9:
					if entropy_bytes <= 0:
						return {"ok": false, "unsupported": false, "reason": "empty_jpg_scan"}
					return {"ok": true, "format": "jpg", "w": sof_w, "h": sof_h}
				if sm == 0xDA:
					# Progressive or multi-scan SOS
					var next_sos_res: Dictionary = _validate_jpg_sos_header(
						bytes,
						scan_pos,
						n,
						sof_marker,
						sof_ncomp,
						sof_comp_blocks,
						sof_comp_order,
						defined_dht_dc,
						defined_dht_ac,
						seq_scanned_cs
					)
					if not bool(next_sos_res.get("ok", false)):
						return next_sos_res
					scan_pos += int(next_sos_res["sos_len"])
					continue
				if sm == 0x01:
					continue
				if sm == 0xD8:
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
				if (sm >= 0xC0 and sm <= 0xCF) and sm != 0xC4 and sm != 0xC8 and sm != 0xCC:
					return {"ok": false, "unsupported": false, "reason": "duplicate_jpg_sof"}
				if sm == 0xC8 or sm == 0xCC or sm == 0xDE or sm == 0xDF:
					return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_marker"}
				if sm < 0xC0 or (sm >= 0xF0 and sm <= 0xFD):
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}
				# Other marker between progressive scans (DHT, DQT, DNL, DRI, APPn, COM)
				if scan_pos + 2 > n:
					return {"ok": false, "unsupported": false, "reason": "truncated_jpg_segment"}
				var mid_len: int = _u16_be(bytes, scan_pos)
				if mid_len < 2 or scan_pos + mid_len > n:
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_segment_length"}
				if sm == 0xC4:
					var mid_dht_err: String = _validate_jpg_dht_segment(bytes, scan_pos, mid_len, defined_dht_dc, defined_dht_ac)
					if not mid_dht_err.is_empty():
						return {"ok": false, "unsupported": false, "reason": mid_dht_err}
				elif sm == 0xDB:
					var mid_dqt_err: String = _validate_jpg_dqt_segment(bytes, scan_pos, mid_len, defined_dqt)
					if not mid_dqt_err.is_empty():
						return {"ok": false, "unsupported": false, "reason": mid_dqt_err}
				elif sm == 0xDD:
					if mid_len != 4:
						return {"ok": false, "unsupported": false, "reason": "invalid_jpg_dri"}
				elif sm == 0xE0:
					if (
						mid_len >= 16
						and bytes[scan_pos + 2] == 0x4A
						and bytes[scan_pos + 3] == 0x46
						and bytes[scan_pos + 4] == 0x49
						and bytes[scan_pos + 5] == 0x46
						and bytes[scan_pos + 6] == 0x00
						and int(bytes[scan_pos + 7]) != 1
					):
						return {"ok": false, "unsupported": false, "reason": "unsupported_jpg_jfif_version"}
				scan_pos += mid_len
			return {"ok": false, "unsupported": false, "reason": "missing_jpg_eoi"}

		if marker == 0xC8 or marker == 0xCC or marker == 0xDE or marker == 0xDF:
			return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_marker"}
		if marker < 0xC0 or (marker >= 0xF0 and marker <= 0xFD):
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_marker"}

		if pos + 2 > n:
			return {"ok": false, "unsupported": false, "reason": "truncated_jpg_segment"}
		var seg_len: int = _u16_be(bytes, pos)
		if seg_len < 2 or pos + seg_len > n:
			return {"ok": false, "unsupported": false, "reason": "invalid_jpg_segment_length"}
		if marker == 0xC4:
			var dht_err: String = _validate_jpg_dht_segment(bytes, pos, seg_len, defined_dht_dc, defined_dht_ac)
			if not dht_err.is_empty():
				return {"ok": false, "unsupported": false, "reason": dht_err}
		elif marker == 0xDB:
			var dqt_err: String = _validate_jpg_dqt_segment(bytes, pos, seg_len, defined_dqt)
			if not dqt_err.is_empty():
				return {"ok": false, "unsupported": false, "reason": dqt_err}
			has_dqt = true
		elif marker == 0xDD:
			if seg_len != 4:
				return {"ok": false, "unsupported": false, "reason": "invalid_jpg_dri"}
		elif marker == 0xE0:
			if (
				seg_len >= 16
				and bytes[pos + 2] == 0x4A
				and bytes[pos + 3] == 0x46
				and bytes[pos + 4] == 0x49
				and bytes[pos + 5] == 0x46
				and bytes[pos + 6] == 0x00
				and int(bytes[pos + 7]) != 1
			):
				return {"ok": false, "unsupported": false, "reason": "unsupported_jpg_jfif_version"}
		elif marker == 0xEE:
			if (
				seg_len >= 14
				and bytes[pos + 2] == 0x41
				and bytes[pos + 3] == 0x64
				and bytes[pos + 4] == 0x6F
				and bytes[pos + 5] == 0x62
				and bytes[pos + 6] == 0x65
			):
				adobe_transform = int(bytes[pos + 13])
		elif (marker >= 0xC0 and marker <= 0xCF) and marker != 0xC4 and marker != 0xC8 and marker != 0xCC:
			if has_sof:
				return {"ok": false, "unsupported": false, "reason": "duplicate_jpg_sof"}
			if marker not in [0xC0, 0xC1, 0xC2]:
				return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_sof"}
			if seg_len < 8 or pos + 8 > n:
				return {"ok": false, "unsupported": false, "reason": "truncated_jpg_sof"}
			var precision: int = int(bytes[pos + 2])
			if precision != 8:
				return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_precision"}
			var h: int = _u16_be(bytes, pos + 3)
			var w: int = _u16_be(bytes, pos + 5)
			var ncomp: int = int(bytes[pos + 7])
			if ncomp == 4:
				if seg_len != 8 + 3 * ncomp:
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sof"}
				return {"ok": false, "unsupported": true, "reason": "unsupported_jpg_colorspace"}
			if (ncomp != 1 and ncomp != 3) or seg_len != 8 + 3 * ncomp:
				return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sof"}
			var comp_blocks: Dictionary = {}
			var comp_order: Dictionary = {}
			var comp_hs: Array[int] = []
			var comp_vs: Array[int] = []
			var max_hs: int = 1
			var max_vs: int = 1
			var tqs: Dictionary = {}
			for c_i: int in range(ncomp):
				var cid: int = int(bytes[pos + 8 + 3 * c_i])
				var hv: int = int(bytes[pos + 8 + 3 * c_i + 1])
				var tq: int = int(bytes[pos + 8 + 3 * c_i + 2])
				var hs: int = (hv >> 4) & 0x0F
				var vs: int = hv & 0x0F
				if hs < 1 or hs > 4 or vs < 1 or vs > 4 or tq > 3:
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sof"}
				comp_hs.append(hs)
				comp_vs.append(vs)
				if hs > max_hs:
					max_hs = hs
				if vs > max_vs:
					max_vs = vs
				if not comp_blocks.has(cid):
					comp_blocks[cid] = hs * vs
				if not comp_order.has(cid):
					comp_order[cid] = c_i
				tqs[tq] = true
			for c_i: int in range(ncomp):
				if (max_hs % comp_hs[c_i]) != 0 or (max_vs % comp_vs[c_i]) != 0:
					return {"ok": false, "unsupported": false, "reason": "invalid_jpg_sof"}
			if not _valid_dimensions(w, h):
				return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
			sof_marker = marker
			sof_w = w
			sof_h = h
			sof_ncomp = ncomp
			sof_comp_blocks = comp_blocks
			sof_comp_order = comp_order
			sof_tqs = tqs
			has_sof = true
		pos += seg_len
	return {"ok": false, "unsupported": false, "reason": "missing_jpg_sof"}


func _ensure_vp8_tables() -> void:
	if _vp8l_code_to_plane.is_empty():
		_vp8l_code_to_plane = _VP8L_CODE_TO_PLANE_HEX.hex_decode()
	if _vp8_default_coeffs.is_empty():
		var dc_bytes: PackedByteArray = _VP8_DEFAULT_COEFF_HEX.hex_decode()
		_vp8_default_coeffs.resize(dc_bytes.size())
		for i: int in range(dc_bytes.size()):
			_vp8_default_coeffs[i] = int(dc_bytes[i])
	if _vp8_kf_bmode.is_empty():
		var bm_bytes: PackedByteArray = _VP8_KF_BMODE_HEX.hex_decode()
		_vp8_kf_bmode.resize(bm_bytes.size())
		for i: int in range(bm_bytes.size()):
			_vp8_kf_bmode[i] = int(bm_bytes[i])
	if _vp8_coeff_update.is_empty():
		var cu_bytes: PackedByteArray = _VP8_COEFF_UPDATE_HEX.hex_decode()
		_vp8_coeff_update.resize(cu_bytes.size())
		for i: int in range(cu_bytes.size()):
			_vp8_coeff_update[i] = int(cu_bytes[i])
	if _vp8_norm_shift.is_empty():
		_vp8_norm_shift.resize(128)
		_vp8_norm_shift[0] = 7
		for rv: int in range(1, 128):
			var sh: int = 0
			var t: int = rv
			while t < 128:
				t <<= 1
				sh += 1
			_vp8_norm_shift[rv] = sh
	if _vp8_pcat_flat.is_empty():
		_vp8_pcat_flat.resize(_VP8_PCAT_FLAT.size())
		for i: int in range(_VP8_PCAT_FLAT.size()):
			_vp8_pcat_flat[i] = _VP8_PCAT_FLAT[i]


func _vp8l_br_read(bytes: PackedByteArray, br: PackedInt32Array, nbits: int) -> int:
	# br = [pos, end_pos, bit_buf, bit_cnt, eof]
	var bit_cnt: int = br[3]
	var bit_buf: int = br[2]
	var pos: int = br[0]
	var end_pos: int = br[1]
	while bit_cnt < nbits and pos < end_pos:
		bit_buf |= int(bytes[pos]) << bit_cnt
		pos += 1
		bit_cnt += 8
	br[0] = pos
	if bit_cnt < nbits:
		br[2] = bit_buf
		br[3] = bit_cnt
		br[4] = 1
		return 0
	var val: int = bit_buf & ((1 << nbits) - 1)
	br[2] = bit_buf >> nbits
	br[3] = bit_cnt - nbits
	return val


func _vp8l_build_huff(lengths: PackedInt32Array) -> Dictionary:
	var num_syms: int = lengths.size()
	var bl_count := PackedInt32Array()
	bl_count.resize(16)
	var total_nz: int = 0
	var single_sym: int = 0
	for sym: int in range(num_syms):
		var cl: int = lengths[sym]
		if cl < 0 or cl > 15:
			return {"ok": false}
		if cl > 0:
			bl_count[cl] += 1
			total_nz += 1
			single_sym = sym
	if total_nz == 0:
		return {"ok": false}
	if total_nz == 1:
		return {"ok": true, "kind": 1, "sym0": single_sym}
	var left: int = 1
	for bits: int in range(1, 16):
		left <<= 1
		left -= bl_count[bits]
		if left < 0:
			return {"ok": false}
	if left != 0:
		return {"ok": false}
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
	sorted_syms.resize(total_nz)
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
			var packed: int = (sym2 << 4) | l
			var step: int = 1 << l
			var idx_f: int = rev
			while idx_f < 512:
				fast[idx_f] = packed
				idx_f += step
	return {"ok": true, "kind": 0, "fast": fast, "bl_count": bl_count, "sorted": sorted_syms}


func _vp8l_read_symbol(bytes: PackedByteArray, br: PackedInt32Array, tree: Dictionary) -> int:
	var kind: int = int(tree["kind"])
	if kind == 1:
		return int(tree["sym0"])
	if kind == 2:
		var b1: int = _vp8l_br_read(bytes, br, 1)
		return int(tree["sym0"]) if b1 == 0 else int(tree["sym1"])
	var bit_cnt: int = br[3]
	var bit_buf: int = br[2]
	var pos: int = br[0]
	var end_pos: int = br[1]
	while bit_cnt < 15 and pos < end_pos:
		bit_buf |= int(bytes[pos]) << bit_cnt
		pos += 1
		bit_cnt += 8
	var fast: PackedInt32Array = tree["fast"]
	var fe: int = fast[bit_buf & 511]
	if fe >= 0:
		var clen: int = fe & 15
		if clen > bit_cnt:
			br[0] = pos
			br[2] = bit_buf
			br[3] = bit_cnt
			br[4] = 1
			return -1
		br[0] = pos
		br[2] = bit_buf >> clen
		br[3] = bit_cnt - clen
		return fe >> 4
	var bl_count: PackedInt32Array = tree["bl_count"]
	var sorted_syms: PackedInt32Array = tree["sorted"]
	var acc: int = 0
	var first: int = 0
	var soff: int = 0
	for step_len: int in range(1, 16):
		if bit_cnt == 0:
			if pos >= end_pos:
				br[0] = pos
				br[2] = bit_buf
				br[3] = bit_cnt
				br[4] = 1
				return -1
			bit_buf |= int(bytes[pos]) << bit_cnt
			pos += 1
			bit_cnt += 8
		acc |= (bit_buf & 1)
		bit_buf >>= 1
		bit_cnt -= 1
		var cntl: int = bl_count[step_len]
		if acc - cntl < first:
			br[0] = pos
			br[2] = bit_buf
			br[3] = bit_cnt
			return sorted_syms[soff + (acc - first)]
		soff += cntl
		first = (first + cntl) << 1
		acc <<= 1
	br[0] = pos
	br[2] = bit_buf
	br[3] = bit_cnt
	return -1


func _vp8l_read_huffman_tree(bytes: PackedByteArray, br: PackedInt32Array, alphabet_size: int) -> Dictionary:
	var simple: int = _vp8l_br_read(bytes, br, 1)
	if br[4] != 0:
		return {"ok": false}
	if simple == 1:
		var num_syms: int = _vp8l_br_read(bytes, br, 1) + 1
		var is_first_8: int = _vp8l_br_read(bytes, br, 1)
		var sym0: int = _vp8l_br_read(bytes, br, 8 if is_first_8 == 1 else 1)
		if br[4] != 0 or sym0 >= alphabet_size:
			return {"ok": false}
		if num_syms == 1:
			return {"ok": true, "kind": 1, "sym0": sym0}
		var sym1: int = _vp8l_br_read(bytes, br, 8)
		if br[4] != 0 or sym1 >= alphabet_size or sym1 == sym0:
			return {"ok": false}
		return {"ok": true, "kind": 2, "sym0": sym0, "sym1": sym1}

	var num_cl_codes: int = _vp8l_br_read(bytes, br, 4) + 4
	if br[4] != 0 or num_cl_codes > 19:
		return {"ok": false}
	var cl_lens := PackedInt32Array()
	cl_lens.resize(19)
	for i: int in range(num_cl_codes):
		cl_lens[_VP8L_CL_ORDER[i]] = _vp8l_br_read(bytes, br, 3)
		if br[4] != 0:
			return {"ok": false}
	var cl_tree: Dictionary = _vp8l_build_huff(cl_lens)
	if not bool(cl_tree.get("ok", false)):
		return {"ok": false}

	var max_symbol: int = alphabet_size
	if _vp8l_br_read(bytes, br, 1) == 1:
		var length_nbits: int = 2 + 2 * _vp8l_br_read(bytes, br, 3)
		max_symbol = 2 + _vp8l_br_read(bytes, br, length_nbits)
	if br[4] != 0 or max_symbol > alphabet_size:
		return {"ok": false}

	var lengths := PackedInt32Array()
	lengths.resize(alphabet_size)
	var sym: int = 0
	var prev_code_len: int = 8
	var rem_syms: int = max_symbol
	while sym < alphabet_size:
		if rem_syms == 0:
			break
		rem_syms -= 1
		var code: int = _vp8l_read_symbol(bytes, br, cl_tree)
		if br[4] != 0 or code < 0:
			return {"ok": false}
		if code < 16:
			lengths[sym] = code
			sym += 1
			if code != 0:
				prev_code_len = code
		else:
			var rep: int = 0
			var fill_val: int = 0
			if code == 16:
				rep = 3 + _vp8l_br_read(bytes, br, 2)
				fill_val = prev_code_len
			elif code == 17:
				rep = 3 + _vp8l_br_read(bytes, br, 3)
				fill_val = 0
			else:
				rep = 11 + _vp8l_br_read(bytes, br, 7)
				fill_val = 0
			if br[4] != 0 or sym + rep > alphabet_size:
				return {"ok": false}
			if fill_val != 0:
				for _r: int in range(rep):
					lengths[sym] = fill_val
					sym += 1
			else:
				sym += rep
	return _vp8l_build_huff(lengths)


func _vp8l_prefix_decode(bytes: PackedByteArray, br: PackedInt32Array, code: int) -> int:
	if code < 4:
		return code + 1
	var extra_bits: int = (code - 2) >> 1
	var offset: int = (2 + (code & 1)) << extra_bits
	var extra: int = _vp8l_br_read(bytes, br, extra_bits)
	return offset + extra + 1


func _vp8l_decode_image_data(
	bytes: PackedByteArray,
	br: PackedInt32Array,
	w: int,
	h: int,
	is_top_level: bool,
	store_pixels: bool
) -> Dictionary:
	var cur_w: int = w
	var cur_h: int = h
	if is_top_level:
		var seen_tf: int = 0
		while _vp8l_br_read(bytes, br, 1) == 1:
			if br[4] != 0:
				return {"ok": false}
			var tf_type: int = _vp8l_br_read(bytes, br, 2)
			if br[4] != 0 or (seen_tf & (1 << tf_type)) != 0:
				return {"ok": false}
			seen_tf |= (1 << tf_type)
			if tf_type == 0 or tf_type == 1:
				var size_bits: int = _vp8l_br_read(bytes, br, 3) + 2
				if br[4] != 0:
					return {"ok": false}
				var sub_w: int = (cur_w + (1 << size_bits) - 1) >> size_bits
				var sub_h: int = (cur_h + (1 << size_bits) - 1) >> size_bits
				var sub_res: Dictionary = _vp8l_decode_image_data(bytes, br, sub_w, sub_h, false, false)
				if not bool(sub_res.get("ok", false)):
					return {"ok": false}
			elif tf_type == 3:
				var color_table_size: int = _vp8l_br_read(bytes, br, 8) + 1
				if br[4] != 0:
					return {"ok": false}
				var pal_res: Dictionary = _vp8l_decode_image_data(bytes, br, color_table_size, 1, false, false)
				if not bool(pal_res.get("ok", false)):
					return {"ok": false}
				var width_bits: int = 0
				if color_table_size <= 2:
					width_bits = 3
				elif color_table_size <= 4:
					width_bits = 2
				elif color_table_size <= 16:
					width_bits = 1
				cur_w = (cur_w + (1 << width_bits) - 1) >> width_bits
		if br[4] != 0:
			return {"ok": false}

	var cc_bits: int = 0
	var color_cache_size: int = 0
	var use_cc: int = _vp8l_br_read(bytes, br, 1)
	if br[4] != 0:
		return {"ok": false}
	if use_cc == 1:
		cc_bits = _vp8l_br_read(bytes, br, 4)
		if br[4] != 0 or cc_bits < 1 or cc_bits > 11:
			return {"ok": false}
		color_cache_size = 1 << cc_bits

	var num_groups: int = 1
	var prefix_bits: int = 0
	var meta_w: int = 0
	var meta_pixels := PackedInt32Array()
	var meta_is_constant: bool = false
	var meta_const_gid: int = 0
	if is_top_level:
		var use_meta: int = _vp8l_br_read(bytes, br, 1)
		if br[4] != 0:
			return {"ok": false}
		if use_meta == 1:
			prefix_bits = _vp8l_br_read(bytes, br, 3) + 2
			if br[4] != 0:
				return {"ok": false}
			meta_w = (cur_w + (1 << prefix_bits) - 1) >> prefix_bits
			var meta_h: int = (cur_h + (1 << prefix_bits) - 1) >> prefix_bits
			var meta_res: Dictionary = _vp8l_decode_image_data(bytes, br, meta_w, meta_h, false, true)
			if not bool(meta_res.get("ok", false)):
				return {"ok": false}
			meta_pixels = meta_res["pixels"]
			if bool(meta_res.get("is_constant", false)):
				meta_is_constant = true
				meta_const_gid = (int(meta_res["const_argb"]) >> 8) & 0xFFFF
				num_groups = meta_const_gid + 1
			else:
				var max_grp: int = 0
				for mp: int in meta_pixels:
					var g_id: int = (mp >> 8) & 0xFFFF
					if g_id > max_grp:
						max_grp = g_id
				num_groups = max_grp + 1
			if num_groups > 65536:
				return {"ok": false}

	var groups: Array = []
	groups.resize(num_groups)
	var alpha_sizes: Array[int] = [256 + 24 + color_cache_size, 256, 256, 256, 40]
	for g_i: int in range(num_groups):
		var trees: Array = []
		trees.resize(5)
		for t_i: int in range(5):
			var tr: Dictionary = _vp8l_read_huffman_tree(bytes, br, alpha_sizes[t_i])
			if not bool(tr.get("ok", false)):
				return {"ok": false}
			trees[t_i] = tr
		groups[g_i] = trees

	var grp_const_kind := PackedInt32Array()
	grp_const_kind.resize(num_groups)
	var grp_const_val := PackedInt32Array()
	grp_const_val.resize(num_groups)
	var all_groups_const: bool = true
	for g_c: int in range(num_groups):
		var gt: Array = groups[g_c]
		var gt0: Dictionary = gt[0]
		if int(gt0["kind"]) == 1:
			var g_sym: int = int(gt0["sym0"])
			if g_sym >= 0 and g_sym < 256:
				if int(gt[1]["kind"]) == 1 and int(gt[2]["kind"]) == 1 and int(gt[3]["kind"]) == 1:
					var c_r: int = int(gt[1]["sym0"])
					var c_b: int = int(gt[2]["sym0"])
					var c_a: int = int(gt[3]["sym0"])
					grp_const_kind[g_c] = 1
					grp_const_val[g_c] = ((c_a & 0xFF) << 24) | ((c_r & 0xFF) << 16) | ((g_sym & 0xFF) << 8) | (c_b & 0xFF)
					continue
			elif g_sym >= 280:
				var cc_i: int = g_sym - 280
				if cc_i < color_cache_size:
					grp_const_kind[g_c] = 2
					grp_const_val[g_c] = cc_i
					continue
		all_groups_const = false

	var total_pixels: int = cur_w * cur_h
	var pixels := PackedInt32Array()
	if store_pixels:
		pixels.resize(total_pixels)
	var ccache := PackedInt32Array()
	var cc_shift: int = 32 - cc_bits
	if store_pixels and color_cache_size > 0:
		ccache.resize(color_cache_size)

	if num_groups == 1 and grp_const_kind[0] != 0:
		var ck0: int = grp_const_kind[0]
		var cv0: int = grp_const_val[0] if ck0 == 1 else 0
		if store_pixels:
			pixels.fill(cv0)
			if ck0 == 1 and color_cache_size > 0:
				var h_idx0: int = ((0x1E35A7BD * (cv0 & 0xFFFFFFFF)) & 0xFFFFFFFF) >> cc_shift
				ccache[h_idx0] = cv0
		return {"ok": true, "pixels": pixels, "is_constant": true, "const_argb": cv0}

	if num_groups > 1 and meta_is_constant:
		if meta_const_gid < 0 or meta_const_gid >= num_groups:
			return {"ok": false}
		var mck: int = grp_const_kind[meta_const_gid]
		if mck != 0:
			var mcv: int = grp_const_val[meta_const_gid] if mck == 1 else 0
			if store_pixels:
				pixels.fill(mcv)
				if mck == 1 and color_cache_size > 0:
					var mh_idx: int = ((0x1E35A7BD * (mcv & 0xFFFFFFFF)) & 0xFFFFFFFF) >> cc_shift
					ccache[mh_idx] = mcv
			return {"ok": true, "pixels": pixels, "is_constant": true, "const_argb": mcv}

	if num_groups > 1 and all_groups_const and not store_pixels:
		for mp_chk: int in meta_pixels:
			var gid_chk: int = (mp_chk >> 8) & 0xFFFF
			if gid_chk < 0 or gid_chk >= num_groups:
				return {"ok": false}
		return {"ok": true, "pixels": pixels}

	var p_pos: int = 0
	var prev_tile_idx: int = -1
	var cur_grp: Array = groups[0]
	var cur_const_kind: int = grp_const_kind[0]
	var cur_const_val: int = grp_const_val[0]
	while p_pos < total_pixels:
		if num_groups > 1:
			var px_x: int = p_pos % cur_w
			var px_y: int = p_pos / cur_w
			var tile_idx: int = (px_y >> prefix_bits) * meta_w + (px_x >> prefix_bits)
			if tile_idx != prev_tile_idx:
				prev_tile_idx = tile_idx
				var gid: int = meta_const_gid if meta_is_constant else ((meta_pixels[tile_idx] >> 8) & 0xFFFF)
				if gid < 0 or gid >= num_groups:
					return {"ok": false}
				cur_grp = groups[gid]
				cur_const_kind = grp_const_kind[gid]
				cur_const_val = grp_const_val[gid]
			if cur_const_kind != 0:
				var row_base: int = px_y * cur_w
				var tile_x_end: int = mini(cur_w, ((px_x >> prefix_bits) + 1) << prefix_bits)
				var run_end: int = mini(total_pixels, row_base + tile_x_end)
				if store_pixels:
					var fill_argb: int = cur_const_val if cur_const_kind == 1 else ccache[cur_const_val]
					for k_fill: int in range(p_pos, run_end):
						pixels[k_fill] = fill_argb
					if cur_const_kind == 1 and color_cache_size > 0:
						var rh_idx: int = ((0x1E35A7BD * (fill_argb & 0xFFFFFFFF)) & 0xFFFFFFFF) >> cc_shift
						ccache[rh_idx] = fill_argb
				p_pos = run_end
				continue
		var sym: int = _vp8l_read_symbol(bytes, br, cur_grp[0])
		if br[4] != 0 or sym < 0:
			return {"ok": false}
		if sym < 256:
			var r_v: int = _vp8l_read_symbol(bytes, br, cur_grp[1])
			if br[4] != 0 or r_v < 0:
				return {"ok": false}
			var b_v: int = _vp8l_read_symbol(bytes, br, cur_grp[2])
			if br[4] != 0 or b_v < 0:
				return {"ok": false}
			var a_v: int = _vp8l_read_symbol(bytes, br, cur_grp[3])
			if br[4] != 0 or a_v < 0:
				return {"ok": false}
			if store_pixels:
				var argb: int = ((a_v & 0xFF) << 24) | ((r_v & 0xFF) << 16) | ((sym & 0xFF) << 8) | (b_v & 0xFF)
				pixels[p_pos] = argb
				if color_cache_size > 0:
					var h_idx: int = ((0x1E35A7BD * (argb & 0xFFFFFFFF)) & 0xFFFFFFFF) >> cc_shift
					ccache[h_idx] = argb
			p_pos += 1
		elif sym < 280:
			var mlen: int = _vp8l_prefix_decode(bytes, br, sym - 256)
			if br[4] != 0:
				return {"ok": false}
			var dcode: int = _vp8l_read_symbol(bytes, br, cur_grp[4])
			if br[4] != 0 or dcode < 0 or dcode >= 40:
				return {"ok": false}
			var draw: int = _vp8l_prefix_decode(bytes, br, dcode)
			if br[4] != 0:
				return {"ok": false}
			var dist: int = 0
			if draw > 120:
				dist = draw - 120
			else:
				var dmap: int = int(_vp8l_code_to_plane[draw - 1])
				var yoff: int = dmap >> 4
				var xoff: int = 8 - (dmap & 0x0F)
				dist = yoff * cur_w + xoff
				if dist < 1:
					dist = 1
			if dist < 1 or dist > p_pos or p_pos + mlen > total_pixels:
				return {"ok": false}
			if store_pixels:
				for _k: int in range(mlen):
					var c_argb: int = pixels[p_pos - dist]
					pixels[p_pos] = c_argb
					if color_cache_size > 0:
						var ch_idx: int = ((0x1E35A7BD * (c_argb & 0xFFFFFFFF)) & 0xFFFFFFFF) >> cc_shift
						ccache[ch_idx] = c_argb
					p_pos += 1
			else:
				p_pos += mlen
		else:
			var c_idx: int = sym - 280
			if c_idx >= color_cache_size:
				return {"ok": false}
			if store_pixels:
				var k_argb: int = ccache[c_idx]
				pixels[p_pos] = k_argb
			p_pos += 1
	return {"ok": true, "pixels": pixels}


func _validate_vp8l_stream(bytes: PackedByteArray, start: int, end: int, w: int, h: int) -> Dictionary:
	_ensure_vp8_tables()
	if start >= end:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8l"}
	var br := PackedInt32Array([start, end, 0, 0, 0])
	var res: Dictionary = _vp8l_decode_image_data(bytes, br, w, h, true, false)
	if not bool(res.get("ok", false)) or br[4] != 0:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8l"}
	return {"ok": true}


func _vp8_read_bool(bytes: PackedByteArray, bd: PackedInt32Array, prob: int) -> int:
	# bd = [pos, end_pos, rng, val, bit_cnt, eof_bytes]
	var rng: int = bd[2]
	var val: int = bd[3]
	var split: int = 1 + (((rng - 1) * prob) >> 8)
	var bigsplit: int = split << 8
	var bit: int = 0
	if val >= bigsplit:
		rng -= split
		val -= bigsplit
		bit = 1
	else:
		rng = split
	if rng < 128:
		var pos: int = bd[0]
		var end_pos: int = bd[1]
		var bc: int = bd[4]
		while rng < 128:
			val <<= 1
			rng <<= 1
			bc += 1
			if bc == 8:
				bc = 0
				if pos < end_pos:
					val |= int(bytes[pos])
					pos += 1
				else:
					bd[5] += 1
		bd[0] = pos
		bd[4] = bc
	bd[2] = rng
	bd[3] = val
	return bit


func _vp8_read_uint(bytes: PackedByteArray, bd: PackedInt32Array, nbits: int) -> int:
	var v: int = 0
	for _i: int in range(nbits):
		v = (v << 1) | _vp8_read_bool(bytes, bd, 128)
	return v


func _validate_vp8_bitstream(bytes: PackedByteArray, chunk_start: int, chunk_end: int, w: int, h: int, riff_end: int = -1) -> Dictionary:
	_ensure_vp8_tables()
	var chunk_size: int = chunk_end - chunk_start
	if chunk_size < 12:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
	var frame_tag: int = int(bytes[chunk_start]) | (int(bytes[chunk_start + 1]) << 8) | (int(bytes[chunk_start + 2]) << 16)
	if (frame_tag & 1) != 0 or (frame_tag & 0x10) == 0:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_keyframe"}
	var version: int = (frame_tag >> 1) & 7
	var first_part_size: int = (frame_tag >> 5) & 0x7FFFF
	if version > 3 or first_part_size < 2 or 10 + first_part_size > chunk_size:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_partition0"}

	var p0_start: int = chunk_start + 10
	var p0_end: int = p0_start + first_part_size
	var bd0 := PackedInt32Array([p0_start + 2, p0_end, 255, (int(bytes[p0_start]) << 8) | int(bytes[p0_start + 1]), 0, 0])

	var color_space: int = _vp8_read_bool(bytes, bd0, 128)
	if color_space != 0:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_colorspace"}
	var _clamping_type: int = _vp8_read_bool(bytes, bd0, 128)

	var seg_enabled: int = _vp8_read_bool(bytes, bd0, 128)
	var update_seg_map: int = 0
	var seg_tree_probs := PackedInt32Array([255, 255, 255])
	if seg_enabled == 1:
		update_seg_map = _vp8_read_bool(bytes, bd0, 128)
		var update_seg_data: int = _vp8_read_bool(bytes, bd0, 128)
		if update_seg_data == 1:
			var _seg_abs: int = _vp8_read_bool(bytes, bd0, 128)
			for _q: int in range(4):
				if _vp8_read_bool(bytes, bd0, 128) == 1:
					_vp8_read_uint(bytes, bd0, 8)
			for _l: int in range(4):
				if _vp8_read_bool(bytes, bd0, 128) == 1:
					_vp8_read_uint(bytes, bd0, 7)
		if update_seg_map == 1:
			for s_i: int in range(3):
				if _vp8_read_bool(bytes, bd0, 128) == 1:
					seg_tree_probs[s_i] = _vp8_read_uint(bytes, bd0, 8)

	var _filter_type: int = _vp8_read_bool(bytes, bd0, 128)
	var _lf_level: int = _vp8_read_uint(bytes, bd0, 6)
	var _sharpness: int = _vp8_read_uint(bytes, bd0, 3)

	var lf_delta_enabled: int = _vp8_read_bool(bytes, bd0, 128)
	if lf_delta_enabled == 1:
		if _vp8_read_bool(bytes, bd0, 128) == 1:
			for _r: int in range(4):
				if _vp8_read_bool(bytes, bd0, 128) == 1:
					_vp8_read_uint(bytes, bd0, 7)
			for _m: int in range(4):
				if _vp8_read_bool(bytes, bd0, 128) == 1:
					_vp8_read_uint(bytes, bd0, 7)

	var log2_parts: int = _vp8_read_uint(bytes, bd0, 2)
	var num_dct_parts: int = 1 << log2_parts
	var dct_hdr_bytes: int = (num_dct_parts - 1) * 3
	if p0_end + dct_hdr_bytes > chunk_end:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}

	var dct_starts := PackedInt32Array()
	var dct_ends := PackedInt32Array()
	dct_starts.resize(num_dct_parts)
	dct_ends.resize(num_dct_parts)
	var cur_d: int = p0_end + dct_hdr_bytes
	for p_i: int in range(num_dct_parts - 1):
		var h_off: int = p0_end + p_i * 3
		var psz: int = int(bytes[h_off]) | (int(bytes[h_off + 1]) << 8) | (int(bytes[h_off + 2]) << 16)
		if psz < 2 or cur_d + psz > chunk_end:
			return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
		dct_starts[p_i] = cur_d
		dct_ends[p_i] = cur_d + psz
		cur_d += psz
	var last_part_end: int = mini(riff_end, chunk_end + (chunk_size & 1)) if riff_end >= 0 else chunk_end
	last_part_end = mini(bytes.size(), last_part_end)
	if last_part_end - cur_d < 2:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
	dct_starts[num_dct_parts - 1] = cur_d
	dct_ends[num_dct_parts - 1] = last_part_end

	var _y_ac_qi: int = _vp8_read_uint(bytes, bd0, 7)
	for _dq: int in range(5):
		if _vp8_read_bool(bytes, bd0, 128) == 1:
			_vp8_read_uint(bytes, bd0, 5)
	var _refresh_probs: int = _vp8_read_bool(bytes, bd0, 128)

	var norm_shift: PackedInt32Array = _vp8_norm_shift
	var coeff_probs: PackedInt32Array = _vp8_default_coeffs.duplicate()
	var cu: PackedInt32Array = _vp8_coeff_update
	var p0_pos: int = bd0[0]
	var p0_end2: int = bd0[1]
	var p0_rng: int = bd0[2]
	var p0_val: int = bd0[3] << 40
	var p0_bits: int = -bd0[4] - 8 * bd0[5]
	while p0_bits <= 32 and p0_pos < p0_end2:
		p0_val |= bytes[p0_pos] << (32 - p0_bits)
		p0_pos += 1
		p0_bits += 8

	for idx_c: int in range(1056):
		var cu_sp: int = 1 + (((p0_rng - 1) * cu[idx_c]) >> 8)
		var cu_bsp: int = cu_sp << 48
		if p0_val >= cu_bsp:
			p0_rng -= cu_sp
			p0_val -= cu_bsp
			if p0_rng < 128:
				var sh_cu: int = norm_shift[p0_rng]
				p0_rng <<= sh_cu; p0_val <<= sh_cu; p0_bits -= sh_cu
				if p0_bits < 0 and p0_pos < p0_end2:
					while p0_bits <= 32 and p0_pos < p0_end2:
						p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			var new_p: int = 0
			for _ub: int in range(8):
				var u_sp: int = 1 + ((p0_rng - 1) >> 1)
				var u_bsp: int = u_sp << 48
				new_p <<= 1
				if p0_val >= u_bsp:
					p0_rng -= u_sp; p0_val -= u_bsp; new_p |= 1
				else:
					p0_rng = u_sp
				if p0_rng < 128:
					var sh_ub: int = norm_shift[p0_rng]
					p0_rng <<= sh_ub; p0_val <<= sh_ub; p0_bits -= sh_ub
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			coeff_probs[idx_c] = new_p
		else:
			p0_rng = cu_sp
			if p0_rng < 128:
				var sh_cu2: int = norm_shift[p0_rng]
				p0_rng <<= sh_cu2; p0_val <<= sh_cu2; p0_bits -= sh_cu2
				if p0_bits < 0 and p0_pos < p0_end2:
					while p0_bits <= 32 and p0_pos < p0_end2:
						p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
		if p0_bits <= -16:
			return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}

	var mns_sp: int = 1 + ((p0_rng - 1) >> 1)
	var mns_bsp: int = mns_sp << 48
	var mb_no_skip: int = 0
	if p0_val >= mns_bsp:
		p0_rng -= mns_sp; p0_val -= mns_bsp; mb_no_skip = 1
	else:
		p0_rng = mns_sp
	if p0_rng < 128:
		var sh_mns: int = norm_shift[p0_rng]
		p0_rng <<= sh_mns; p0_val <<= sh_mns; p0_bits -= sh_mns
		if p0_bits < 0 and p0_pos < p0_end2:
			while p0_bits <= 32 and p0_pos < p0_end2:
				p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
	var prob_skip_false: int = 0
	if mb_no_skip == 1:
		for _sb: int in range(8):
			var ps_sp: int = 1 + ((p0_rng - 1) >> 1)
			var ps_bsp: int = ps_sp << 48
			prob_skip_false <<= 1
			if p0_val >= ps_bsp:
				p0_rng -= ps_sp; p0_val -= ps_bsp; prob_skip_false |= 1
			else:
				p0_rng = ps_sp
			if p0_rng < 128:
				var sh_ps: int = norm_shift[p0_rng]
				p0_rng <<= sh_ps; p0_val <<= sh_ps; p0_bits -= sh_ps
				if p0_bits < 0 and p0_pos < p0_end2:
					while p0_bits <= 32 and p0_pos < p0_end2:
						p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
	if p0_bits <= -16:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}

	var mb_w: int = (w + 15) >> 4
	var mb_h: int = (h + 15) >> 4
	var total_mb: int = mb_w * mb_h
	var mb_skips := PackedByteArray()
	mb_skips.resize(total_mb)
	var mb_is_bpred := PackedByteArray()
	mb_is_bpred.resize(total_mb)

	var above_b := PackedInt32Array()
	above_b.resize(mb_w * 4)
	var left_b := PackedInt32Array()
	left_b.resize(4)
	var kf_bmode: PackedInt32Array = _vp8_kf_bmode
	var y_to_b := PackedInt32Array([0, 2, 3, 1])

	var mb_idx: int = 0
	var stp0: int = seg_tree_probs[0]
	for _my: int in range(mb_h):
		left_b.fill(0)
		for mx: int in range(mb_w):
			if seg_enabled == 1 and update_seg_map == 1:
				var sb_sp: int = 1 + (((p0_rng - 1) * stp0) >> 8)
				var sb_bsp: int = sb_sp << 48
				var s_b: int = 0
				if p0_val >= sb_bsp: p0_rng -= sb_sp; p0_val -= sb_bsp; s_b = 1
				else: p0_rng = sb_sp
				if p0_rng < 128:
					var sh_sb1: int = norm_shift[p0_rng]
					p0_rng <<= sh_sb1; p0_val <<= sh_sb1; p0_bits -= sh_sb1
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
				var sb2_sp: int = 1 + (((p0_rng - 1) * seg_tree_probs[1 + s_b]) >> 8)
				var sb2_bsp: int = sb2_sp << 48
				if p0_val >= sb2_bsp: p0_rng -= sb2_sp; p0_val -= sb2_bsp
				else: p0_rng = sb2_sp
				if p0_rng < 128:
					var sh_sb2: int = norm_shift[p0_rng]
					p0_rng <<= sh_sb2; p0_val <<= sh_sb2; p0_bits -= sh_sb2
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			var skip: int = 0
			if mb_no_skip == 1:
				var sk_sp: int = 1 + (((p0_rng - 1) * prob_skip_false) >> 8)
				var sk_bsp: int = sk_sp << 48
				if p0_val >= sk_bsp: p0_rng -= sk_sp; p0_val -= sk_bsp; skip = 1
				else: p0_rng = sk_sp
				if p0_rng < 128:
					var sh_sk: int = norm_shift[p0_rng]
					p0_rng <<= sh_sk; p0_val <<= sh_sk; p0_bits -= sh_sk
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			mb_skips[mb_idx] = skip

			var y_mode: int = 4
			var ym0_sp: int = 1 + (((p0_rng - 1) * 145) >> 8)
			var ym0_bsp: int = ym0_sp << 48
			var ym0_b: int = 0
			if p0_val >= ym0_bsp: p0_rng -= ym0_sp; p0_val -= ym0_bsp; ym0_b = 1
			else: p0_rng = ym0_sp
			if p0_rng < 128:
				var sh_ym0: int = norm_shift[p0_rng]
				p0_rng <<= sh_ym0; p0_val <<= sh_ym0; p0_bits -= sh_ym0
				if p0_bits < 0 and p0_pos < p0_end2:
					while p0_bits <= 32 and p0_pos < p0_end2:
						p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			if ym0_b == 1:
				var ym1_sp: int = 1 + (((p0_rng - 1) * 156) >> 8)
				var ym1_bsp: int = ym1_sp << 48
				var ym1_b: int = 0
				if p0_val >= ym1_bsp: p0_rng -= ym1_sp; p0_val -= ym1_bsp; ym1_b = 1
				else: p0_rng = ym1_sp
				if p0_rng < 128:
					var sh_ym1: int = norm_shift[p0_rng]
					p0_rng <<= sh_ym1; p0_val <<= sh_ym1; p0_bits -= sh_ym1
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
				if ym1_b == 0:
					var ym2_sp: int = 1 + (((p0_rng - 1) * 163) >> 8)
					var ym2_bsp: int = ym2_sp << 48
					if p0_val >= ym2_bsp: p0_rng -= ym2_sp; p0_val -= ym2_bsp; y_mode = 1
					else: p0_rng = ym2_sp; y_mode = 0
					if p0_rng < 128:
						var sh_ym2: int = norm_shift[p0_rng]
						p0_rng <<= sh_ym2; p0_val <<= sh_ym2; p0_bits -= sh_ym2
						if p0_bits < 0 and p0_pos < p0_end2:
							while p0_bits <= 32 and p0_pos < p0_end2:
								p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
				else:
					var ym3_sp: int = 1 + (((p0_rng - 1) * 128) >> 8)
					var ym3_bsp: int = ym3_sp << 48
					if p0_val >= ym3_bsp: p0_rng -= ym3_sp; p0_val -= ym3_bsp; y_mode = 3
					else: p0_rng = ym3_sp; y_mode = 2
					if p0_rng < 128:
						var sh_ym3: int = norm_shift[p0_rng]
						p0_rng <<= sh_ym3; p0_val <<= sh_ym3; p0_bits -= sh_ym3
						if p0_bits < 0 and p0_pos < p0_end2:
							while p0_bits <= 32 and p0_pos < p0_end2:
								p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			if y_mode == 4:
				mb_is_bpred[mb_idx] = 1
				var mx4: int = mx * 4
				for by: int in range(4):
					for bx: int in range(4):
						var p_off: int = (above_b[mx4 + bx] * 10 + left_b[by]) * 9
						var bmode: int = 0
						var bm0_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off]) >> 8)
						var bm0_bsp: int = bm0_sp << 48
						var bm0_b: int = 0
						if p0_val >= bm0_bsp: p0_rng -= bm0_sp; p0_val -= bm0_bsp; bm0_b = 1
						else: p0_rng = bm0_sp
						if p0_rng < 128:
							var sh_bm0: int = norm_shift[p0_rng]
							p0_rng <<= sh_bm0; p0_val <<= sh_bm0; p0_bits -= sh_bm0
							if p0_bits < 0 and p0_pos < p0_end2:
								while p0_bits <= 32 and p0_pos < p0_end2:
									p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
						if bm0_b == 1:
							var bm1_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 1]) >> 8)
							var bm1_bsp: int = bm1_sp << 48
							if p0_val < bm1_bsp:
								p0_rng = bm1_sp; bmode = 1
								if p0_rng < 128:
									var sh_bm1: int = norm_shift[p0_rng]
									p0_rng <<= sh_bm1; p0_val <<= sh_bm1; p0_bits -= sh_bm1
									if p0_bits < 0 and p0_pos < p0_end2:
										while p0_bits <= 32 and p0_pos < p0_end2:
											p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
							else:
								p0_rng -= bm1_sp; p0_val -= bm1_bsp
								if p0_rng < 128:
									var sh_bm1b: int = norm_shift[p0_rng]
									p0_rng <<= sh_bm1b; p0_val <<= sh_bm1b; p0_bits -= sh_bm1b
									if p0_bits < 0 and p0_pos < p0_end2:
										while p0_bits <= 32 and p0_pos < p0_end2:
											p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
								var bm2_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 2]) >> 8)
								var bm2_bsp: int = bm2_sp << 48
								if p0_val < bm2_bsp:
									p0_rng = bm2_sp; bmode = 2
									if p0_rng < 128:
										var sh_bm2: int = norm_shift[p0_rng]
										p0_rng <<= sh_bm2; p0_val <<= sh_bm2; p0_bits -= sh_bm2
										if p0_bits < 0 and p0_pos < p0_end2:
											while p0_bits <= 32 and p0_pos < p0_end2:
												p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
								else:
									p0_rng -= bm2_sp; p0_val -= bm2_bsp
									if p0_rng < 128:
										var sh_bm2b: int = norm_shift[p0_rng]
										p0_rng <<= sh_bm2b; p0_val <<= sh_bm2b; p0_bits -= sh_bm2b
										if p0_bits < 0 and p0_pos < p0_end2:
											while p0_bits <= 32 and p0_pos < p0_end2:
												p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
									var bm3_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 3]) >> 8)
									var bm3_bsp: int = bm3_sp << 48
									if p0_val < bm3_bsp:
										p0_rng = bm3_sp
										if p0_rng < 128:
											var sh_bm3: int = norm_shift[p0_rng]
											p0_rng <<= sh_bm3; p0_val <<= sh_bm3; p0_bits -= sh_bm3
											if p0_bits < 0 and p0_pos < p0_end2:
												while p0_bits <= 32 and p0_pos < p0_end2:
													p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
										var bm4_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 4]) >> 8)
										var bm4_bsp: int = bm4_sp << 48
										if p0_val < bm4_bsp:
											p0_rng = bm4_sp; bmode = 3
											if p0_rng < 128:
												var sh_bm4: int = norm_shift[p0_rng]
												p0_rng <<= sh_bm4; p0_val <<= sh_bm4; p0_bits -= sh_bm4
												if p0_bits < 0 and p0_pos < p0_end2:
													while p0_bits <= 32 and p0_pos < p0_end2:
														p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
										else:
											p0_rng -= bm4_sp; p0_val -= bm4_bsp
											if p0_rng < 128:
												var sh_bm4b: int = norm_shift[p0_rng]
												p0_rng <<= sh_bm4b; p0_val <<= sh_bm4b; p0_bits -= sh_bm4b
												if p0_bits < 0 and p0_pos < p0_end2:
													while p0_bits <= 32 and p0_pos < p0_end2:
														p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
											var bm5_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 5]) >> 8)
											var bm5_bsp: int = bm5_sp << 48
											if p0_val < bm5_bsp:
												p0_rng = bm5_sp; bmode = 5
											else:
												p0_rng -= bm5_sp; p0_val -= bm5_bsp; bmode = 6
											if p0_rng < 128:
												var sh_bm5: int = norm_shift[p0_rng]
												p0_rng <<= sh_bm5; p0_val <<= sh_bm5; p0_bits -= sh_bm5
												if p0_bits < 0 and p0_pos < p0_end2:
													while p0_bits <= 32 and p0_pos < p0_end2:
														p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
									else:
										p0_rng -= bm3_sp; p0_val -= bm3_bsp
										if p0_rng < 128:
											var sh_bm3b: int = norm_shift[p0_rng]
											p0_rng <<= sh_bm3b; p0_val <<= sh_bm3b; p0_bits -= sh_bm3b
											if p0_bits < 0 and p0_pos < p0_end2:
												while p0_bits <= 32 and p0_pos < p0_end2:
													p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
										var bm6_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 6]) >> 8)
										var bm6_bsp: int = bm6_sp << 48
										if p0_val < bm6_bsp:
											p0_rng = bm6_sp; bmode = 4
											if p0_rng < 128:
												var sh_bm6: int = norm_shift[p0_rng]
												p0_rng <<= sh_bm6; p0_val <<= sh_bm6; p0_bits -= sh_bm6
												if p0_bits < 0 and p0_pos < p0_end2:
													while p0_bits <= 32 and p0_pos < p0_end2:
														p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
										else:
											p0_rng -= bm6_sp; p0_val -= bm6_bsp
											if p0_rng < 128:
												var sh_bm6b: int = norm_shift[p0_rng]
												p0_rng <<= sh_bm6b; p0_val <<= sh_bm6b; p0_bits -= sh_bm6b
												if p0_bits < 0 and p0_pos < p0_end2:
													while p0_bits <= 32 and p0_pos < p0_end2:
														p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
											var bm7_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 7]) >> 8)
											var bm7_bsp: int = bm7_sp << 48
											if p0_val < bm7_bsp:
												p0_rng = bm7_sp; bmode = 7
												if p0_rng < 128:
													var sh_bm7: int = norm_shift[p0_rng]
													p0_rng <<= sh_bm7; p0_val <<= sh_bm7; p0_bits -= sh_bm7
													if p0_bits < 0 and p0_pos < p0_end2:
														while p0_bits <= 32 and p0_pos < p0_end2:
															p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
											else:
												p0_rng -= bm7_sp; p0_val -= bm7_bsp
												if p0_rng < 128:
													var sh_bm7b: int = norm_shift[p0_rng]
													p0_rng <<= sh_bm7b; p0_val <<= sh_bm7b; p0_bits -= sh_bm7b
													if p0_bits < 0 and p0_pos < p0_end2:
														while p0_bits <= 32 and p0_pos < p0_end2:
															p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
												var bm8_sp: int = 1 + (((p0_rng - 1) * kf_bmode[p_off + 8]) >> 8)
												var bm8_bsp: int = bm8_sp << 48
												if p0_val < bm8_bsp:
													p0_rng = bm8_sp; bmode = 8
												else:
													p0_rng -= bm8_sp; p0_val -= bm8_bsp; bmode = 9
												if p0_rng < 128:
													var sh_bm8: int = norm_shift[p0_rng]
													p0_rng <<= sh_bm8; p0_val <<= sh_bm8; p0_bits -= sh_bm8
													if p0_bits < 0 and p0_pos < p0_end2:
														while p0_bits <= 32 and p0_pos < p0_end2:
															p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
						above_b[mx4 + bx] = bmode
						left_b[by] = bmode
			else:
				var bfill: int = y_to_b[y_mode]
				var mx4b: int = mx * 4
				above_b[mx4b] = bfill
				above_b[mx4b + 1] = bfill
				above_b[mx4b + 2] = bfill
				above_b[mx4b + 3] = bfill
				left_b[0] = bfill
				left_b[1] = bfill
				left_b[2] = bfill
				left_b[3] = bfill

			var uv0_sp: int = 1 + (((p0_rng - 1) * 142) >> 8)
			var uv0_bsp: int = uv0_sp << 48
			var uv0_b: int = 0
			if p0_val >= uv0_bsp: p0_rng -= uv0_sp; p0_val -= uv0_bsp; uv0_b = 1
			else: p0_rng = uv0_sp
			if p0_rng < 128:
				var sh_uv0: int = norm_shift[p0_rng]
				p0_rng <<= sh_uv0; p0_val <<= sh_uv0; p0_bits -= sh_uv0
				if p0_bits < 0 and p0_pos < p0_end2:
					while p0_bits <= 32 and p0_pos < p0_end2:
						p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			if uv0_b == 1:
				var uv1_sp: int = 1 + (((p0_rng - 1) * 114) >> 8)
				var uv1_bsp: int = uv1_sp << 48
				var uv1_b: int = 0
				if p0_val >= uv1_bsp: p0_rng -= uv1_sp; p0_val -= uv1_bsp; uv1_b = 1
				else: p0_rng = uv1_sp
				if p0_rng < 128:
					var sh_uv1: int = norm_shift[p0_rng]
					p0_rng <<= sh_uv1; p0_val <<= sh_uv1; p0_bits -= sh_uv1
					if p0_bits < 0 and p0_pos < p0_end2:
						while p0_bits <= 32 and p0_pos < p0_end2:
							p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
				if uv1_b == 1:
					var uv2_sp: int = 1 + (((p0_rng - 1) * 183) >> 8)
					var uv2_bsp: int = uv2_sp << 48
					if p0_val >= uv2_bsp: p0_rng -= uv2_sp; p0_val -= uv2_bsp
					else: p0_rng = uv2_sp
					if p0_rng < 128:
						var sh_uv2: int = norm_shift[p0_rng]
						p0_rng <<= sh_uv2; p0_val <<= sh_uv2; p0_bits -= sh_uv2
						if p0_bits < 0 and p0_pos < p0_end2:
							while p0_bits <= 32 and p0_pos < p0_end2:
								p0_val |= bytes[p0_pos] << (32 - p0_bits); p0_pos += 1; p0_bits += 8
			if p0_bits < -8:
				return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
			mb_idx += 1

	# Decode DCT partitions (56-bit buffered bool reader + fast EOB)
	var pcat_flat: PackedInt32Array = _vp8_pcat_flat
	var part_states := PackedInt64Array()
	part_states.resize(num_dct_parts * 5)
	for p_i2: int in range(num_dct_parts):
		var ds: int = dct_starts[p_i2]
		var de: int = dct_ends[p_i2]
		var dv: int = (bytes[ds] << 48) | (bytes[ds + 1] << 40)
		var dp: int = ds + 2
		var db: int = 0
		while db <= 32 and dp < de:
			dv |= bytes[dp] << (32 - db)
			dp += 1
			db += 8
		var base_s: int = p_i2 * 5
		part_states[base_s] = dp
		part_states[base_s + 1] = de
		part_states[base_s + 2] = 255
		part_states[base_s + 3] = dv
		part_states[base_s + 4] = db

	var above_nz := PackedInt32Array()
	above_nz.resize(mb_w * 9)
	var left_nz := PackedInt32Array()
	left_nz.resize(9)
	var part_mask: int = num_dct_parts - 1
	var ab_slots := PackedInt32Array([0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 4, 5, 4, 5, 6, 7, 6, 7])
	var lf_slots := PackedInt32Array([0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7])
	var band_off := PackedInt32Array([0, 33, 66, 99, 198, 132, 165, 198, 198, 198, 198, 198, 198, 198, 198, 231])
	var mb_i2: int = 0

	for my2: int in range(mb_h):
		var p_idx: int = (my2 & part_mask) * 5
		var d_pos: int = int(part_states[p_idx])
		var d_end: int = int(part_states[p_idx + 1])
		var d_rng: int = int(part_states[p_idx + 2])
		var d_val: int = part_states[p_idx + 3]
		var d_bits: int = int(part_states[p_idx + 4])
		left_nz.fill(0)

		for mx2: int in range(mb_w):
			var ab_base: int = mx2 * 9
			var is_bp: int = int(mb_is_bpred[mb_i2])
			if int(mb_skips[mb_i2]) == 1:
				for zi: int in range(8):
					above_nz[ab_base + zi] = 0
					left_nz[zi] = 0
				if is_bp == 0:
					above_nz[ab_base + 8] = 0
					left_nz[8] = 0
				mb_i2 += 1
				continue

			var y_type_base: int = 792 if is_bp == 1 else 0
			var y_start: int = 0 if is_bp == 1 else 1
			if is_bp == 0:
				# Y2 block (type 1, c=0..15)
				var nz2: int = 0
				var ctx2: int = (above_nz[ab_base + 8] + left_nz[8]) * 11
				var skip_eob2: bool = false
				var c2: int = 0
				while c2 < 16:
					var poff2: int = 264 + band_off[c2] + ctx2
					if not skip_eob2:
						if d_bits < -8:
							return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
						var sp0: int = 1 + (((d_rng - 1) * coeff_probs[poff2]) >> 8)
						var bsp0: int = sp0 << 48
						if d_val >= bsp0:
							d_rng -= sp0; d_val -= bsp0
						else:
							d_rng = sp0
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_e2: int = norm_shift[d_rng]
									d_rng <<= sh_e2; d_val <<= sh_e2; d_bits -= sh_e2
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							break
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_02: int = norm_shift[d_rng]
								d_rng <<= sh_02; d_val <<= sh_02; d_bits -= sh_02
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					skip_eob2 = false
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sp1: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 1]) >> 8)
					var bsp1: int = sp1 << 48
					if d_val >= bsp1:
						d_rng -= sp1; d_val -= bsp1
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_12: int = norm_shift[d_rng]
								d_rng <<= sh_12; d_val <<= sh_12; d_bits -= sh_12
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					else:
						d_rng = sp1
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_z2: int = norm_shift[d_rng]
								d_rng <<= sh_z2; d_val <<= sh_z2; d_bits -= sh_z2
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						c2 += 1
						ctx2 = 0
						skip_eob2 = true
						continue
					nz2 = 1
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sp2: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 2]) >> 8)
					var bsp2: int = sp2 << 48
					var mag_big2: int = 0
					if d_val >= bsp2:
						d_rng -= sp2; d_val -= bsp2; mag_big2 = 1
					else:
						d_rng = sp2
					if d_rng < 128:
						if d_rng >= 64:
							d_rng <<= 1; d_val <<= 1; d_bits -= 1
						else:
							var sh_22: int = norm_shift[d_rng]
							d_rng <<= sh_22; d_val <<= sh_22; d_bits -= sh_22
						if d_bits < 0 and d_pos < d_end:
							if d_pos + 4 <= d_end:
								d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
								d_pos += 4; d_bits += 32
							else:
								while d_bits <= 32 and d_pos < d_end:
									d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					if mag_big2 == 0:
						ctx2 = 11
					else:
						ctx2 = 22
						var cat_idx2: int = -1
						if d_bits < -8:
							return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
						var sp3: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 3]) >> 8)
						var bsp3: int = sp3 << 48
						var b3: int = 0
						if d_val >= bsp3:
							d_rng -= sp3; d_val -= bsp3; b3 = 1
						else:
							d_rng = sp3
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_32: int = norm_shift[d_rng]
								d_rng <<= sh_32; d_val <<= sh_32; d_bits -= sh_32
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						if b3 == 0:
							if d_bits < -8:
								return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
							var sp4: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 4]) >> 8)
							var bsp4: int = sp4 << 48
							var b4: int = 0
							if d_val >= bsp4:
								d_rng -= sp4; d_val -= bsp4; b4 = 1
							else:
								d_rng = sp4
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_42: int = norm_shift[d_rng]
									d_rng <<= sh_42; d_val <<= sh_42; d_bits -= sh_42
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							if b4 == 1:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp5: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 5]) >> 8)
								var bsp5: int = sp5 << 48
								if d_val >= bsp5: d_rng -= sp5; d_val -= bsp5
								else: d_rng = sp5
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_52: int = norm_shift[d_rng]
										d_rng <<= sh_52; d_val <<= sh_52; d_bits -= sh_52
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						else:
							if d_bits < -8:
								return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
							var sp6: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 6]) >> 8)
							var bsp6: int = sp6 << 48
							var b6: int = 0
							if d_val >= bsp6: d_rng -= sp6; d_val -= bsp6; b6 = 1
							else: d_rng = sp6
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_62: int = norm_shift[d_rng]
									d_rng <<= sh_62; d_val <<= sh_62; d_bits -= sh_62
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							if b6 == 0:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp7: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 7]) >> 8)
								var bsp7: int = sp7 << 48
								var b7: int = 0
								if d_val >= bsp7: d_rng -= sp7; d_val -= bsp7; b7 = 1
								else: d_rng = sp7
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_72: int = norm_shift[d_rng]
										d_rng <<= sh_72; d_val <<= sh_72; d_bits -= sh_72
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
								cat_idx2 = 1 if b7 == 1 else 0
							else:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp8: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 8]) >> 8)
								var bsp8: int = sp8 << 48
								var b8: int = 0
								if d_val >= bsp8: d_rng -= sp8; d_val -= bsp8; b8 = 1
								else: d_rng = sp8
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_82: int = norm_shift[d_rng]
										d_rng <<= sh_82; d_val <<= sh_82; d_bits -= sh_82
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
								if b8 == 0:
									if d_bits < -8:
										return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
									var sp9: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 9]) >> 8)
									var bsp9: int = sp9 << 48
									var b9: int = 0
									if d_val >= bsp9: d_rng -= sp9; d_val -= bsp9; b9 = 1
									else: d_rng = sp9
									if d_rng < 128:
										if d_rng >= 64:
											d_rng <<= 1; d_val <<= 1; d_bits -= 1
										else:
											var sh_92: int = norm_shift[d_rng]
											d_rng <<= sh_92; d_val <<= sh_92; d_bits -= sh_92
										if d_bits < 0 and d_pos < d_end:
											if d_pos + 4 <= d_end:
												d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
												d_pos += 4; d_bits += 32
											else:
												while d_bits <= 32 and d_pos < d_end:
													d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
									cat_idx2 = 3 if b9 == 1 else 2
								else:
									if d_bits < -8:
										return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
									var sp10: int = 1 + (((d_rng - 1) * coeff_probs[poff2 + 10]) >> 8)
									var bsp10: int = sp10 << 48
									var b10: int = 0
									if d_val >= bsp10: d_rng -= sp10; d_val -= bsp10; b10 = 1
									else: d_rng = sp10
									if d_rng < 128:
										if d_rng >= 64:
											d_rng <<= 1; d_val <<= 1; d_bits -= 1
										else:
											var sh_102: int = norm_shift[d_rng]
											d_rng <<= sh_102; d_val <<= sh_102; d_bits -= sh_102
										if d_bits < 0 and d_pos < d_end:
											if d_pos + 4 <= d_end:
												d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
												d_pos += 4; d_bits += 32
											else:
												while d_bits <= 32 and d_pos < d_end:
													d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
									cat_idx2 = 5 if b10 == 1 else 4
						if cat_idx2 >= 0:
							for ci2: int in range(_VP8_PCAT_OFFS[cat_idx2], _VP8_PCAT_OFFS[cat_idx2 + 1]):
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var spc: int = 1 + (((d_rng - 1) * pcat_flat[ci2]) >> 8)
								var bspc: int = spc << 48
								if d_val >= bspc: d_rng -= spc; d_val -= bspc
								else: d_rng = spc
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_c2: int = norm_shift[d_rng]
										d_rng <<= sh_c2; d_val <<= sh_c2; d_bits -= sh_c2
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					# sign bit
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sps2: int = 1 + ((d_rng - 1) >> 1)
					var bsps2: int = sps2 << 48
					if d_val >= bsps2: d_rng -= sps2; d_val -= bsps2
					else: d_rng = sps2
					if d_rng < 128:
						if d_rng >= 64:
							d_rng <<= 1; d_val <<= 1; d_bits -= 1
						else:
							var sh_s2: int = norm_shift[d_rng]
							d_rng <<= sh_s2; d_val <<= sh_s2; d_bits -= sh_s2
						if d_bits < 0 and d_pos < d_end:
							if d_pos + 4 <= d_end:
								d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
								d_pos += 4; d_bits += 32
							else:
								while d_bits <= 32 and d_pos < d_end:
									d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					c2 += 1
				above_nz[ab_base + 8] = nz2
				left_nz[8] = nz2

			# 16 Y + 4 U + 4 V blocks
			for blk: int in range(24):
				var type_base: int = y_type_base if blk < 16 else 528
				var bstart: int = y_start if blk < 16 else 0
				var ab_slot: int = ab_slots[blk]
				var lf_slot: int = lf_slots[blk]

				var ctx: int = (above_nz[ab_base + ab_slot] + left_nz[lf_slot]) * 11
				var poff0: int = type_base + (0 if bstart == 0 else 33) + ctx
				if d_bits < -8:
					return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
				var sp00: int = 1 + (((d_rng - 1) * coeff_probs[poff0]) >> 8)
				var bsp00: int = sp00 << 48
				if d_val < bsp00:
					d_rng = sp00
					if d_rng < 128:
						if d_rng >= 64:
							d_rng <<= 1; d_val <<= 1; d_bits -= 1
						else:
							var sh00: int = norm_shift[d_rng]
							d_rng <<= sh00; d_val <<= sh00; d_bits -= sh00
						if d_bits < 0 and d_pos < d_end:
							if d_pos + 4 <= d_end:
								d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
								d_pos += 4; d_bits += 32
							else:
								while d_bits <= 32 and d_pos < d_end:
									d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					if ctx != 0:
						above_nz[ab_base + ab_slot] = 0
						left_nz[lf_slot] = 0
					continue
				d_rng -= sp00
				d_val -= bsp00
				if d_rng < 128:
					if d_rng >= 64:
						d_rng <<= 1; d_val <<= 1; d_bits -= 1
					else:
						var sh01: int = norm_shift[d_rng]
						d_rng <<= sh01; d_val <<= sh01; d_bits -= sh01
					if d_bits < 0 and d_pos < d_end:
						if d_pos + 4 <= d_end:
							d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
							d_pos += 4; d_bits += 32
						else:
							while d_bits <= 32 and d_pos < d_end:
								d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8

				var nz: int = 0
				var skip_eob: bool = true
				var c: int = bstart
				while c < 16:
					var poff: int = type_base + band_off[c] + ctx
					if not skip_eob:
						if d_bits < -8:
							return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
						var sp0: int = 1 + (((d_rng - 1) * coeff_probs[poff]) >> 8)
						var bsp0: int = sp0 << 48
						if d_val >= bsp0:
							d_rng -= sp0; d_val -= bsp0
						else:
							d_rng = sp0
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_e: int = norm_shift[d_rng]
									d_rng <<= sh_e; d_val <<= sh_e; d_bits -= sh_e
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							break
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_0: int = norm_shift[d_rng]
								d_rng <<= sh_0; d_val <<= sh_0; d_bits -= sh_0
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					skip_eob = false
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sp1: int = 1 + (((d_rng - 1) * coeff_probs[poff + 1]) >> 8)
					var bsp1: int = sp1 << 48
					if d_val >= bsp1:
						d_rng -= sp1; d_val -= bsp1
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_1: int = norm_shift[d_rng]
								d_rng <<= sh_1; d_val <<= sh_1; d_bits -= sh_1
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					else:
						d_rng = sp1
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_z: int = norm_shift[d_rng]
								d_rng <<= sh_z; d_val <<= sh_z; d_bits -= sh_z
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						c += 1
						ctx = 0
						skip_eob = true
						continue
					nz = 1
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sp2: int = 1 + (((d_rng - 1) * coeff_probs[poff + 2]) >> 8)
					var bsp2: int = sp2 << 48
					var mag_big: int = 0
					if d_val >= bsp2:
						d_rng -= sp2; d_val -= bsp2; mag_big = 1
					else:
						d_rng = sp2
					if d_rng < 128:
						if d_rng >= 64:
							d_rng <<= 1; d_val <<= 1; d_bits -= 1
						else:
							var sh_2: int = norm_shift[d_rng]
							d_rng <<= sh_2; d_val <<= sh_2; d_bits -= sh_2
						if d_bits < 0 and d_pos < d_end:
							if d_pos + 4 <= d_end:
								d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
								d_pos += 4; d_bits += 32
							else:
								while d_bits <= 32 and d_pos < d_end:
									d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					if mag_big == 0:
						ctx = 11
					else:
						ctx = 22
						var cat_idx: int = -1
						if d_bits < -8:
							return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
						var sp3: int = 1 + (((d_rng - 1) * coeff_probs[poff + 3]) >> 8)
						var bsp3: int = sp3 << 48
						var b3: int = 0
						if d_val >= bsp3: d_rng -= sp3; d_val -= bsp3; b3 = 1
						else: d_rng = sp3
						if d_rng < 128:
							if d_rng >= 64:
								d_rng <<= 1; d_val <<= 1; d_bits -= 1
							else:
								var sh_3: int = norm_shift[d_rng]
								d_rng <<= sh_3; d_val <<= sh_3; d_bits -= sh_3
							if d_bits < 0 and d_pos < d_end:
								if d_pos + 4 <= d_end:
									d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
									d_pos += 4; d_bits += 32
								else:
									while d_bits <= 32 and d_pos < d_end:
										d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						if b3 == 0:
							if d_bits < -8:
								return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
							var sp4: int = 1 + (((d_rng - 1) * coeff_probs[poff + 4]) >> 8)
							var bsp4: int = sp4 << 48
							var b4: int = 0
							if d_val >= bsp4: d_rng -= sp4; d_val -= bsp4; b4 = 1
							else: d_rng = sp4
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_4: int = norm_shift[d_rng]
									d_rng <<= sh_4; d_val <<= sh_4; d_bits -= sh_4
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							if b4 == 1:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp5: int = 1 + (((d_rng - 1) * coeff_probs[poff + 5]) >> 8)
								var bsp5: int = sp5 << 48
								if d_val >= bsp5: d_rng -= sp5; d_val -= bsp5
								else: d_rng = sp5
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_5: int = norm_shift[d_rng]
										d_rng <<= sh_5; d_val <<= sh_5; d_bits -= sh_5
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
						else:
							if d_bits < -8:
								return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
							var sp6: int = 1 + (((d_rng - 1) * coeff_probs[poff + 6]) >> 8)
							var bsp6: int = sp6 << 48
							var b6: int = 0
							if d_val >= bsp6: d_rng -= sp6; d_val -= bsp6; b6 = 1
							else: d_rng = sp6
							if d_rng < 128:
								if d_rng >= 64:
									d_rng <<= 1; d_val <<= 1; d_bits -= 1
								else:
									var sh_6: int = norm_shift[d_rng]
									d_rng <<= sh_6; d_val <<= sh_6; d_bits -= sh_6
								if d_bits < 0 and d_pos < d_end:
									if d_pos + 4 <= d_end:
										d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
										d_pos += 4; d_bits += 32
									else:
										while d_bits <= 32 and d_pos < d_end:
											d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
							if b6 == 0:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp7: int = 1 + (((d_rng - 1) * coeff_probs[poff + 7]) >> 8)
								var bsp7: int = sp7 << 48
								var b7: int = 0
								if d_val >= bsp7: d_rng -= sp7; d_val -= bsp7; b7 = 1
								else: d_rng = sp7
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_7: int = norm_shift[d_rng]
										d_rng <<= sh_7; d_val <<= sh_7; d_bits -= sh_7
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
								cat_idx = 1 if b7 == 1 else 0
							else:
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var sp8: int = 1 + (((d_rng - 1) * coeff_probs[poff + 8]) >> 8)
								var bsp8: int = sp8 << 48
								var b8: int = 0
								if d_val >= bsp8: d_rng -= sp8; d_val -= bsp8; b8 = 1
								else: d_rng = sp8
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_8: int = norm_shift[d_rng]
										d_rng <<= sh_8; d_val <<= sh_8; d_bits -= sh_8
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
								if b8 == 0:
									if d_bits < -8:
										return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
									var sp9: int = 1 + (((d_rng - 1) * coeff_probs[poff + 9]) >> 8)
									var bsp9: int = sp9 << 48
									var b9: int = 0
									if d_val >= bsp9: d_rng -= sp9; d_val -= bsp9; b9 = 1
									else: d_rng = sp9
									if d_rng < 128:
										if d_rng >= 64:
											d_rng <<= 1; d_val <<= 1; d_bits -= 1
										else:
											var sh_9: int = norm_shift[d_rng]
											d_rng <<= sh_9; d_val <<= sh_9; d_bits -= sh_9
										if d_bits < 0 and d_pos < d_end:
											if d_pos + 4 <= d_end:
												d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
												d_pos += 4; d_bits += 32
											else:
												while d_bits <= 32 and d_pos < d_end:
													d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
									cat_idx = 3 if b9 == 1 else 2
								else:
									if d_bits < -8:
										return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
									var sp10: int = 1 + (((d_rng - 1) * coeff_probs[poff + 10]) >> 8)
									var bsp10: int = sp10 << 48
									var b10: int = 0
									if d_val >= bsp10: d_rng -= sp10; d_val -= bsp10; b10 = 1
									else: d_rng = sp10
									if d_rng < 128:
										if d_rng >= 64:
											d_rng <<= 1; d_val <<= 1; d_bits -= 1
										else:
											var sh_10: int = norm_shift[d_rng]
											d_rng <<= sh_10; d_val <<= sh_10; d_bits -= sh_10
										if d_bits < 0 and d_pos < d_end:
											if d_pos + 4 <= d_end:
												d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
												d_pos += 4; d_bits += 32
											else:
												while d_bits <= 32 and d_pos < d_end:
													d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
									cat_idx = 5 if b10 == 1 else 4
						if cat_idx >= 0:
							for ci: int in range(_VP8_PCAT_OFFS[cat_idx], _VP8_PCAT_OFFS[cat_idx + 1]):
								if d_bits < -8:
									return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
								var spc2: int = 1 + (((d_rng - 1) * pcat_flat[ci]) >> 8)
								var bspc2: int = spc2 << 48
								if d_val >= bspc2: d_rng -= spc2; d_val -= bspc2
								else: d_rng = spc2
								if d_rng < 128:
									if d_rng >= 64:
										d_rng <<= 1; d_val <<= 1; d_bits -= 1
									else:
										var sh_c: int = norm_shift[d_rng]
										d_rng <<= sh_c; d_val <<= sh_c; d_bits -= sh_c
									if d_bits < 0 and d_pos < d_end:
										if d_pos + 4 <= d_end:
											d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
											d_pos += 4; d_bits += 32
										else:
											while d_bits <= 32 and d_pos < d_end:
												d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					if d_bits < -8:
						return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
					var sps: int = 1 + ((d_rng - 1) >> 1)
					var bsps: int = sps << 48
					if d_val >= bsps: d_rng -= sps; d_val -= bsps
					else: d_rng = sps
					if d_rng < 128:
						if d_rng >= 64:
							d_rng <<= 1; d_val <<= 1; d_bits -= 1
						else:
							var sh_s: int = norm_shift[d_rng]
							d_rng <<= sh_s; d_val <<= sh_s; d_bits -= sh_s
						if d_bits < 0 and d_pos < d_end:
							if d_pos + 4 <= d_end:
								d_val |= ((bytes[d_pos] << 24) | (bytes[d_pos + 1] << 16) | (bytes[d_pos + 2] << 8) | bytes[d_pos + 3]) << (8 - d_bits)
								d_pos += 4; d_bits += 32
							else:
								while d_bits <= 32 and d_pos < d_end:
									d_val |= bytes[d_pos] << (32 - d_bits); d_pos += 1; d_bits += 8
					c += 1
				above_nz[ab_base + ab_slot] = nz
				left_nz[lf_slot] = nz

			mb_i2 += 1

		part_states[p_idx] = d_pos
		part_states[p_idx + 2] = d_rng
		part_states[p_idx + 3] = d_val
		part_states[p_idx + 4] = d_bits

	return {"ok": true}


func _inspect_webp_bytes(bytes: PackedByteArray) -> Dictionary:
	var n: int = bytes.size()
	if n < 20:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp"}
	var riff_size: int = _u32_le(bytes, 4)
	if riff_size < 12 or 8 + riff_size > n:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp_riff"}
	var riff_end: int = 8 + riff_size
	var pos: int = 12
	var has_dims: bool = false
	var has_vp8x: bool = false
	var vp8x_flags: int = 0
	var vp8x_w: int = 0
	var vp8x_h: int = 0
	var has_image_chunk: bool = false
	var image_chunk_type: String = ""
	var has_alph: bool = false
	var alph_pos: int = -1
	var alph_size: int = 0
	var alph_comp: int = 0
	var img_pos: int = -1
	var img_size: int = 0
	var w: int = 0
	var h: int = 0

	while pos < riff_end:
		if pos + 8 > riff_end:
			return {"ok": false, "unsupported": false, "reason": "truncated_webp_chunk"}
		var c0: int = int(bytes[pos])
		var c1: int = int(bytes[pos + 1])
		var c2: int = int(bytes[pos + 2])
		var c3: int = int(bytes[pos + 3])
		var chunk_size: int = _u32_le(bytes, pos + 4)
		var padded_size: int = chunk_size + (chunk_size & 1)
		if chunk_size < 0 or pos + 8 + padded_size > n or pos + 8 + chunk_size > riff_end:
			return {"ok": false, "unsupported": false, "reason": "truncated_webp_chunk"}

		if c0 == 0x56 and c1 == 0x50 and c2 == 0x38 and c3 == 0x20:
			# "VP8 "
			if has_image_chunk:
				return {"ok": false, "unsupported": false, "reason": "duplicate_webp_image_chunk"}
			if chunk_size < 12:
				return {"ok": false, "unsupported": false, "reason": "truncated_webp_vp8"}
			var vp8_tag0: int = int(bytes[pos + 8])
			if (vp8_tag0 & 1) != 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_keyframe"}
			if bytes[pos + 11] != 0x9D or bytes[pos + 12] != 0x01 or bytes[pos + 13] != 0x2A:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_tag"}
			var cw: int = _u16_le(bytes, pos + 14) & 0x3FFF
			var ch: int = _u16_le(bytes, pos + 16) & 0x3FFF
			if not _valid_dimensions(cw, ch):
				return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
			if has_vp8x and (cw != vp8x_w or ch != vp8x_h):
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_dimensions_mismatch"}
			if (vp8_tag0 & 0x10) == 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8_keyframe"}
			w = cw
			h = ch
			has_dims = true
			has_image_chunk = true
			image_chunk_type = "VP8 "
			img_pos = pos
			img_size = chunk_size
		elif c0 == 0x56 and c1 == 0x50 and c2 == 0x38 and c3 == 0x4C:
			# "VP8L"
			if has_image_chunk:
				return {"ok": false, "unsupported": false, "reason": "duplicate_webp_image_chunk"}
			if has_alph:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}
			if chunk_size < 6 or bytes[pos + 8] != 0x2F:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8l"}
			var bits: int = _u32_le(bytes, pos + 9)
			if ((bits >> 29) & 7) != 0:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8l"}
			var lw: int = (bits & 0x3FFF) + 1
			var lh: int = ((bits >> 14) & 0x3FFF) + 1
			if not _valid_dimensions(lw, lh):
				return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
			if has_vp8x and (lw != vp8x_w or lh != vp8x_h):
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_dimensions_mismatch"}
			w = lw
			h = lh
			has_dims = true
			has_image_chunk = true
			image_chunk_type = "VP8L"
			img_pos = pos
			img_size = chunk_size
		elif c0 == 0x56 and c1 == 0x50 and c2 == 0x38 and c3 == 0x58:
			# "VP8X"
			if pos != 12 or has_vp8x or chunk_size != 10:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_vp8x"}
			vp8x_flags = int(bytes[pos + 8])
			if (vp8x_flags & 0x02) != 0:
				return {"ok": false, "unsupported": true, "reason": "unsupported_image_format:animated_webp"}
			var vw: int = 1 + int(bytes[pos + 12]) + (int(bytes[pos + 13]) << 8) + (int(bytes[pos + 14]) << 16)
			var vh: int = 1 + int(bytes[pos + 15]) + (int(bytes[pos + 16]) << 8) + (int(bytes[pos + 17]) << 16)
			if not _valid_dimensions(vw, vh):
				return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
			vp8x_w = vw
			vp8x_h = vh
			has_vp8x = true
			w = vw
			h = vh
			has_dims = true
		elif (
			(c0 == 0x41 and c1 == 0x4E and c2 == 0x49 and c3 == 0x4D) # ANIM
			or (c0 == 0x41 and c1 == 0x4E and c2 == 0x4D and c3 == 0x46) # ANMF
		):
			return {"ok": false, "unsupported": true, "reason": "unsupported_image_format:animated_webp"}
		elif c0 == 0x41 and c1 == 0x4C and c2 == 0x50 and c3 == 0x48:
			# "ALPH"
			if not has_vp8x or has_image_chunk or has_alph or chunk_size < 1:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}
			var ab0: int = int(bytes[pos + 8])
			if ((ab0 >> 6) & 3) != 0 or ((ab0 >> 4) & 3) > 1 or (ab0 & 3) > 1:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}
			has_alph = true
			alph_pos = pos
			alph_size = chunk_size
			alph_comp = ab0 & 3
		elif (
			(c0 == 0x49 and c1 == 0x43 and c2 == 0x43 and c3 == 0x50) # ICCP
			or (c0 == 0x45 and c1 == 0x58 and c2 == 0x49 and c3 == 0x46) # EXIF
			or (c0 == 0x58 and c1 == 0x4D and c2 == 0x50 and c3 == 0x20) # XMP 
		):
			pass
		else:
			return {"ok": false, "unsupported": false, "reason": "unsupported_webp_chunk"}

		pos += 8 + padded_size

	if not has_dims or not has_image_chunk:
		return {"ok": false, "unsupported": false, "reason": "truncated_webp"}
	if not _valid_dimensions(w, h):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
	if has_vp8x and (vp8x_flags & 0x10) != 0 and image_chunk_type == "VP8 " and not has_alph:
		return {"ok": false, "unsupported": false, "reason": "missing_webp_alph"}
	if has_alph and (vp8x_flags & 0x10) == 0:
		return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}

	if has_alph:
		if alph_comp == 0:
			if alph_size - 1 < w * h:
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}
		else:
			var alph_res: Dictionary = _validate_vp8l_stream(bytes, alph_pos + 9, alph_pos + 8 + alph_size, w, h)
			if not bool(alph_res.get("ok", false)):
				return {"ok": false, "unsupported": false, "reason": "invalid_webp_alph"}

	if image_chunk_type == "VP8L":
		var vp8l_res: Dictionary = _validate_vp8l_stream(bytes, img_pos + 13, img_pos + 8 + img_size, w, h)
		if not bool(vp8l_res.get("ok", false)):
			return vp8l_res
	else:
		var vp8_res: Dictionary = _validate_vp8_bitstream(bytes, img_pos + 8, img_pos + 8 + img_size, w, h, riff_end)
		if not bool(vp8_res.get("ok", false)):
			return vp8_res

	return {"ok": true, "format": "webp", "w": w, "h": h}


func _inspect_bmp_bytes(bytes: PackedByteArray) -> Dictionary:
	var n: int = bytes.size()
	if n < 26:
		return {"ok": false, "unsupported": false, "reason": "truncated_bmp"}
	var bf_off: int = _u32_le(bytes, 10)
	var dib_size: int = _u32_le(bytes, 14)
	if dib_size < 40:
		return {"ok": false, "unsupported": true, "reason": "unsupported_bmp_os2"}
	if dib_size not in [40, 52, 56, 108, 124]:
		return {"ok": false, "unsupported": false, "reason": "unsupported_bmp_dib"}
	if n < 14 + dib_size:
		return {"ok": false, "unsupported": false, "reason": "truncated_bmp_info"}
	if bf_off < 14 + dib_size or bf_off > n:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_offset"}

	var dib_off: int = 14
	var w_u: int = _u32_le(bytes, 18)
	var h_u: int = _u32_le(bytes, 22)
	if w_u >= 2147483648:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_width"}
	var w: int = w_u
	var top_down: bool = false
	var h: int = 0
	if h_u >= 2147483648:
		top_down = true
		h = 4294967296 - h_u
	else:
		h = h_u
	var planes: int = _u16_le(bytes, 26)
	var bpp: int = _u16_le(bytes, 28)
	var compression: int = _u32_le(bytes, 30)
	var colors_used: int = _u32_le(bytes, dib_off + 32)

	if planes != 1:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_planes"}
	if bpp not in [1, 4, 8, 16, 24, 32]:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_bpp"}
	if compression not in [0, 1, 2, 3]:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_compression"}
	if not _valid_dimensions(w, h):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}
	if compression == 1 or compression == 2:
		return {"ok": false, "unsupported": true, "reason": "unsupported_bmp_rle"}
	if compression == 3 and bpp != 16 and bpp != 32:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_bitfields"}
	if dib_size == 40 and compression == 3 and bf_off < 66:
		return {"ok": false, "unsupported": false, "reason": "missing_bmp_bitfields"}
	if bpp in [1, 4, 8]:
		var max_colors: int = 1 << bpp
		if colors_used > max_colors:
			return {"ok": false, "unsupported": false, "reason": "invalid_bmp_palette"}
		var palette_entries: int = colors_used if colors_used > 0 else max_colors
		if bf_off < 14 + dib_size + palette_entries * 4:
			return {"ok": false, "unsupported": false, "reason": "missing_bmp_palette"}

	var row_stride: int = ((w * bpp + 31) / 32) * 4
	if bf_off + row_stride * h > n:
		return {"ok": false, "unsupported": false, "reason": "truncated_bmp_pixels"}
	var bf_size: int = _u32_le(bytes, 2)
	if bf_size < bf_off + row_stride * h:
		return {"ok": false, "unsupported": false, "reason": "invalid_bmp_file_size"}

	return {
		"ok": true,
		"format": "bmp",
		"w": w,
		"h": h,
		"bpp": bpp,
		"dib_size": dib_size,
		"top_down": top_down,
		"bf_off": bf_off,
		"row_stride": row_stride,
	}


func _flip_top_down_bmp(bytes: PackedByteArray, bf_off: int, h: int, row_stride: int) -> PackedByteArray:
	var out: PackedByteArray = bytes.slice(0, bf_off)
	out.encode_s32(22, h)
	for y: int in range(h - 1, -1, -1):
		var row_start: int = bf_off + y * row_stride
		out.append_array(bytes.slice(row_start, row_start + row_stride))
	out.encode_u32(2, out.size())
	return out


func _inspect_image_header(bytes: PackedByteArray) -> Dictionary:
	var n: int = bytes.size()
	if n == 0:
		return {"ok": false, "unsupported": false, "reason": "empty_image_bytes"}
	if n > _MAX_IMAGE_BYTES:
		return {"ok": false, "unsupported": false, "reason": "image_too_large"}

	# 1. PNG: 89 50 4E 47 0D 0A 1A 0A
	if (
		n >= 8
		and bytes[0] == 0x89
		and bytes[1] == 0x50
		and bytes[2] == 0x4E
		and bytes[3] == 0x47
		and bytes[4] == 0x0D
		and bytes[5] == 0x0A
		and bytes[6] == 0x1A
		and bytes[7] == 0x0A
	):
		return _inspect_png_bytes(bytes)

	# 2. GIF: "GIF8" (47 49 46 38) -> reject cleanly without Image.load_*
	if n >= 6 and bytes[0] == 0x47 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x38:
		return {"ok": false, "unsupported": true, "reason": "unsupported_image_format:gif"}

	# 3. JPEG: FF D8
	if n >= 2 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		return _inspect_jpg_bytes(bytes)

	# 4. WEBP: RIFF....WEBP
	if (
		n >= 12
		and bytes[0] == 0x52
		and bytes[1] == 0x49
		and bytes[2] == 0x46
		and bytes[3] == 0x46
		and bytes[8] == 0x57
		and bytes[9] == 0x45
		and bytes[10] == 0x42
		and bytes[11] == 0x50
	):
		return _inspect_webp_bytes(bytes)

	# 5. BMP: "BM" (42 4D)
	if n >= 2 and bytes[0] == 0x42 and bytes[1] == 0x4D:
		return _inspect_bmp_bytes(bytes)

	# 6. SVG (UTF-8 + XML well-formedness check, <= 2 MiB)
	return _inspect_svg_bytes(bytes)


func _prepare_image_bytes(bytes: PackedByteArray, ext_hint: String) -> Dictionary:
	var header: Dictionary = _inspect_image_header(bytes)
	if not bool(header.get("ok", false)):
		return header

	var fmt: String = str(header["format"])
	var img := Image.new()
	var err: Error = ERR_INVALID_DATA
	match fmt:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		"bmp":
			var bmp_bytes: PackedByteArray = bytes
			var bmp_bf_off: int = int(header.get("bf_off", 54))
			var bmp_bpp: int = int(header.get("bpp", 24))
			var bmp_dib_size: int = int(header.get("dib_size", 40))
			if bmp_bpp in [1, 4, 8]:
				var full_pal_end: int = 14 + bmp_dib_size + (1 << bmp_bpp) * 4
				if bmp_bf_off < full_pal_end:
					var pad_len: int = full_pal_end - bmp_bf_off
					var padded := PackedByteArray()
					padded.append_array(bmp_bytes.slice(0, bmp_bf_off))
					var zeros := PackedByteArray()
					zeros.resize(pad_len)
					padded.append_array(zeros)
					padded.append_array(bmp_bytes.slice(bmp_bf_off))
					padded.encode_u32(10, full_pal_end)
					padded.encode_u32(2, padded.size())
					bmp_bytes = padded
					bmp_bf_off = full_pal_end
			if bool(header.get("top_down", false)):
				bmp_bytes = _flip_top_down_bmp(
					bmp_bytes,
					bmp_bf_off,
					int(header.get("h", 0)),
					int(header.get("row_stride", 0))
				)
			err = img.load_bmp_from_buffer(bmp_bytes)
		"svg":
			var svg_load_bytes: PackedByteArray = header.get("normalized_bytes", bytes) as PackedByteArray
			err = img.load_svg_from_buffer(svg_load_bytes)
		_:
			return {"ok": false, "unsupported": true, "reason": "unsupported_image_format:" + fmt}

	if err != OK or img.is_empty():
		return {"ok": false, "unsupported": false, "reason": "image_decode_failed:" + fmt}
	if not _valid_dimensions(img.get_width(), img.get_height()):
		return {"ok": false, "unsupported": false, "reason": "image_dimensions_out_of_bounds"}

	if fmt == "bmp" or fmt == "svg":
		var png_bytes: PackedByteArray = img.save_png_to_buffer()
		if png_bytes.is_empty():
			return {"ok": false, "unsupported": false, "reason": "png_transcode_failed"}
		return {"ok": true, "bytes": png_bytes, "ext": "png"}

	var out_ext: String = fmt
	if fmt == "jpg" and ext_hint.strip_edges().to_lower() == "jpeg":
		out_ext = "jpeg"
	return {"ok": true, "bytes": bytes, "ext": out_ext}


func _parse_json_dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw as Dictionary
	if raw is String:
		var j := JSON.new()
		if j.parse(raw as String) == OK and j.data is Dictionary:
			return j.data as Dictionary
	return {}


func _ensure_all_tables() -> void:
	_ensure_crc32_table()
	_png_ensure_fixed_huffman()
	_ensure_vp8_tables()


func prevalidate_local_refs(
	logical_refs: Array,
	assets_map: Dictionary,
	source: RefCounted,
	session: RefCounted
) -> void:
	if logical_refs.is_empty() or source == null or not source.has_method("read_bytes"):
		return
	if OS.get_processor_count() <= 1:
		return
	if session != null and session.has_method("is_cancelled") and bool(session.is_cancelled()):
		return

	_ensure_all_tables()

	var seen_refs: Dictionary = {}
	var seen_hashes: Dictionary = {}
	var items: Array[Dictionary] = []
	for ref_v: Variant in logical_refs:
		if session != null and session.has_method("is_cancelled") and bool(session.is_cancelled()):
			return
		var logical_ref: String = str(ref_v)
		if logical_ref.strip_edges().is_empty() or seen_refs.has(logical_ref):
			continue
		seen_refs[logical_ref] = true

		var asset_v: Variant = assets_map.get(logical_ref, null)
		if not (asset_v is Dictionary):
			continue
		var asset_entry: Dictionary = asset_v as Dictionary
		if str(asset_entry.get("kind", "")) != "local":
			continue
		if bool(asset_entry.get("unsafe", false)) or bool(asset_entry.get("external_or_missing", false)):
			continue
		var ext: String = str(asset_entry.get("ext", "")).to_lower()
		if ext == "gif" or bool(asset_entry.get("unsupported_ext", false)):
			continue
		var rel_path: String = str(asset_entry.get("resolved_path_or_url", ""))
		if rel_path.is_empty():
			continue

		var raw_bytes: PackedByteArray = source.read_bytes(rel_path)
		if raw_bytes.is_empty():
			continue
		var raw_key: String = _sha256_bytes(raw_bytes)
		if _hash_cache.has(raw_key) or _prep_cache.has(raw_key) or seen_hashes.has(raw_key):
			continue
		seen_hashes[raw_key] = true
		items.append({
			"raw_key": raw_key,
			"bytes": raw_bytes,
			"ext": ext,
			"size": raw_bytes.size(),
		})

	if items.is_empty():
		return

	var batch_start: int = 0
	var total_items: int = items.size()
	while batch_start < total_items:
		if session != null and session.has_method("is_cancelled") and bool(session.is_cancelled()):
			return
		var batch: Array[Dictionary] = []
		var batch_bytes: int = 0
		while batch_start < total_items and batch.size() < 512:
			var it: Dictionary = items[batch_start]
			var sz: int = int(it["size"])
			if not batch.is_empty() and batch_bytes + sz > 134217728:
				break
			batch.append(it)
			batch_bytes += sz
			batch_start += 1

		if batch.size() == 1:
			var single: Dictionary = batch[0]
			_prep_cache[str(single["raw_key"])] = _prepare_image_bytes(single["bytes"] as PackedByteArray, str(single["ext"]))
			continue

		batch.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) > int(b["size"]))
		var b_count: int = batch.size()
		var batch_results: Array = []
		batch_results.resize(b_count)
		var worker_fn: Callable = func(idx: int) -> void:
			var item: Dictionary = batch[idx]
			batch_results[idx] = _prepare_image_bytes(item["bytes"] as PackedByteArray, str(item["ext"]))
		var task_id: int = WorkerThreadPool.add_group_task(worker_fn, b_count, -1, true)
		WorkerThreadPool.wait_for_group_task_completion(task_id)
		for idx2: int in range(b_count):
			_prep_cache[str(batch[idx2]["raw_key"])] = batch_results[idx2]


func publish_local_bytes(
	bytes: PackedByteArray,
	ext_hint: String,
	host: RefCounted,
	session: RefCounted
) -> Dictionary:
	if bytes.is_empty():
		return {"ok": false, "unsupported": false, "reason": "empty_image_bytes"}
	var raw_key: String = _sha256_bytes(bytes)
	if _hash_cache.has(raw_key):
		return (_hash_cache[raw_key] as Dictionary).duplicate()

	var prep: Dictionary = (_prep_cache[raw_key] as Dictionary) if _prep_cache.has(raw_key) else _prepare_image_bytes(bytes, ext_hint)
	if not bool(prep.get("ok", false)):
		return prep
	_prep_cache.erase(raw_key)

	var out_bytes: PackedByteArray = prep["bytes"]
	var out_ext: String = str(prep["ext"])
	var sha256_hex: String = _sha256_bytes(out_bytes)
	var asset_ref: String = "asset://%s.%s" % [sha256_hex, out_ext]

	var dest_var: Variant = host.get("destination") if host != null else null
	var dest_str: String = str(dest_var).strip_edges() if (dest_var is String) else ""
	var has_store: bool = (
		not dest_str.is_empty()
		and _shared_asset_store != null
		and (ResourceLoader.exists(_SHARED_ASSET_STORE_PATH) or _allow_mock_store)
	)
	if has_store:
		var global_dest: String = ProjectSettings.globalize_path(dest_str)
		var target_file: String = global_dest.path_join("assets").path_join("%s.%s" % [sha256_hex, out_ext])
		var existed_before: bool = FileAccess.file_exists(target_file)
		var pub_raw: Variant = _shared_asset_store.Publish(global_dest, asset_ref, out_bytes)
		var pub_res: Dictionary = _parse_json_dict(pub_raw)
		if not bool(pub_res.get("ok", false)):
			return {
				"ok": false,
				"unsupported": false,
				"reason": "shared_asset_publish_failed:" + str(pub_res.get("reason", "unknown")),
			}
		if not existed_before and FileAccess.file_exists(target_file):
			_published_files.append(target_file)

	var final_ref: String = asset_ref
	if session != null and session.has_method("validate_sprite_path"):
		final_ref = str(session.validate_sprite_path(asset_ref))
		if final_ref.is_empty():
			return {"ok": false, "unsupported": false, "reason": "invalid_sprite_path:" + asset_ref}

	var ok_res: Dictionary = {"ok": true, "sprite_path": final_ref, "status": "local_published"}
	_hash_cache[raw_key] = ok_res
	return ok_res.duplicate()


func resolve_sprite_ref(
	logical_ref: String,
	asset_entry: Dictionary,
	source: RefCounted,
	host: RefCounted,
	session: RefCounted,
	options: Dictionary
) -> Dictionary:
	if logical_ref.strip_edges().is_empty():
		return {"ok": true, "sprite_path": "", "status": "skipped"}
	if _ref_cache.has(logical_ref):
		return (_ref_cache[logical_ref] as Dictionary).duplicate()

	var skip_missing: bool = _coerce_bool(options.get("skip_missing_assets", true), true)
	var download_remote: bool = _coerce_bool(options.get("download_remote_assets", true), true)
	var clean_proxy: String = _coerce_string(options.get("proxy", ""), "").strip_edges()

	var kind: String = str(asset_entry.get("kind", ""))
	if kind == "empty":
		var empty_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
		_ref_cache[logical_ref] = empty_res
		return empty_res.duplicate()

	if kind == "unsafe" or bool(asset_entry.get("unsafe", false)):
		if not skip_missing:
			return {"ok": false, "reason": "unsafe_asset_ref:" + logical_ref}
		var unsafe_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
		_ref_cache[logical_ref] = unsafe_res
		return unsafe_res.duplicate()

	if kind == "remote":
		var url: String = str(asset_entry.get("resolved_path_or_url", logical_ref))
		if not download_remote:
			if session != null and session.has_method("add_warning"):
				session.add_warning("已跳过远端图片下载：" + url)
			var skip_rem: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
			_ref_cache[logical_ref] = skip_rem
			return skip_rem.duplicate()
		var archived: String = ""
		if session != null and session.has_method("archive_remote_image"):
			archived = str(session.archive_remote_image(url, clean_proxy))
		if not archived.is_empty():
			var ok_rem: Dictionary = {"ok": true, "sprite_path": archived, "status": "remote_archived"}
			_ref_cache[logical_ref] = ok_rem
			return ok_rem.duplicate()
		if not skip_missing:
			return {"ok": false, "reason": "remote_archive_failed:" + url}
		var fail_rem: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
		_ref_cache[logical_ref] = fail_rem
		return fail_rem.duplicate()

	if kind == "system" or bool(asset_entry.get("external_or_missing", false)):
		if not skip_missing:
			return {"ok": false, "reason": "missing_asset:" + logical_ref}
		if session != null and session.has_method("add_warning"):
			session.add_warning("缺失本地或系统图片资源，已占位降级：" + logical_ref)
		var miss_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
		_ref_cache[logical_ref] = miss_res
		return miss_res.duplicate()

	if kind == "local":
		var ext: String = str(asset_entry.get("ext", "")).to_lower()
		if ext == "gif" or bool(asset_entry.get("unsupported_ext", false)):
			if not skip_missing:
				return {"ok": false, "reason": "unsupported_image_format:gif"}
			if session != null and session.has_method("add_warning"):
				session.add_warning("跳过不支持的图片格式（GIF）：" + logical_ref)
			var gif_res: Dictionary = {"ok": true, "sprite_path": "", "status": "unsupported"}
			_ref_cache[logical_ref] = gif_res
			return gif_res.duplicate()

		if source == null or not source.has_method("read_bytes"):
			if not skip_missing:
				return {"ok": false, "reason": "source_unavailable:" + logical_ref}
			var nosrc_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
			_ref_cache[logical_ref] = nosrc_res
			return nosrc_res.duplicate()

		var rel_path: String = str(asset_entry.get("resolved_path_or_url", ""))
		var raw_bytes: PackedByteArray = source.read_bytes(rel_path)
		if raw_bytes.is_empty():
			if source.has_method("get_last_read_error"):
				var read_err: String = str(source.get_last_read_error())
				if read_err.begins_with("zip_"):
					return {"ok": false, "reason": read_err}
			if not skip_missing:
				return {"ok": false, "reason": "empty_or_unreadable_asset:" + logical_ref}
			if session != null and session.has_method("add_warning"):
				session.add_warning("图片文件为空或不可读，已占位降级：" + logical_ref)
			var empty_file_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
			_ref_cache[logical_ref] = empty_file_res
			return empty_file_res.duplicate()

		var pub_res: Dictionary = publish_local_bytes(raw_bytes, ext, host, session)
		if bool(pub_res.get("ok", false)):
			_ref_cache[logical_ref] = pub_res
			return pub_res.duplicate()

		var is_unsup: bool = bool(pub_res.get("unsupported", false))
		var reason: String = str(pub_res.get("reason", "invalid_image_asset"))
		if not skip_missing:
			return {"ok": false, "reason": reason}
		if session != null and session.has_method("add_warning"):
			session.add_warning("图片解析失败，已占位降级（%s）：%s" % [reason, logical_ref])
		var fallback_res: Dictionary = {
			"ok": true,
			"sprite_path": "",
			"status": "unsupported" if is_unsup else "skipped",
		}
		_ref_cache[logical_ref] = fallback_res
		return fallback_res.duplicate()

	if not skip_missing:
		return {"ok": false, "reason": "unknown_asset_kind:" + logical_ref}
	var unk_res: Dictionary = {"ok": true, "sprite_path": "", "status": "skipped"}
	_ref_cache[logical_ref] = unk_res
	return unk_res.duplicate()
