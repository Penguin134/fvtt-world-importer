extends RefCounted

const DEFAULT_MAX_OUTPUT_BYTES: int = 67108864


func decompress(compressed: PackedByteArray, max_output_bytes: int = DEFAULT_MAX_OUTPUT_BYTES) -> Dictionary:
	var n: int = compressed.size()
	if n == 0:
		return {"ok": false, "reason": "snappy_empty_input"}
	if max_output_bytes <= 0:
		return {"ok": false, "reason": "snappy_invalid_max_output_bytes"}

	var pos: int = 0
	var u_len: int = 0
	var shift: int = 0
	var varint_done: bool = false
	while pos < n:
		if shift >= 35:
			return {"ok": false, "reason": "snappy_varint_overflow"}
		var b: int = compressed[pos]
		pos += 1
		if shift == 28 and (b & 0xF0) != 0:
			return {"ok": false, "reason": "snappy_varint_overflow"}
		u_len |= ((b & 0x7F) << shift)
		if (b & 0x80) == 0:
			varint_done = true
			break
		shift += 7

	if not varint_done:
		return {"ok": false, "reason": "snappy_truncated_length"}
	if u_len < 0 or u_len > max_output_bytes:
		return {"ok": false, "reason": "snappy_uncompressed_length_exceeds_limit"}

	var out := PackedByteArray()
	if u_len == 0:
		if pos != n:
			return {"ok": false, "reason": "snappy_trailing_bytes_after_zero_len"}
		return {"ok": true, "data": out}

	while pos < n:
		var tag: int = compressed[pos]
		pos += 1
		var kind: int = tag & 0x03
		if kind == 0:
			var l6: int = (tag >> 2) & 0x3F
			var lit_len: int = 0
			if l6 < 60:
				lit_len = l6 + 1
			else:
				var extra: int = l6 - 59
				if pos + extra > n:
					return {"ok": false, "reason": "snappy_truncated_literal_len"}
				var acc: int = 0
				for j: int in range(extra):
					acc |= (compressed[pos + j] << (8 * j))
				pos += extra
				if acc < 0 or acc >= max_output_bytes:
					return {"ok": false, "reason": "snappy_literal_len_overflow"}
				lit_len = acc + 1
			if lit_len <= 0 or pos + lit_len > n:
				return {"ok": false, "reason": "snappy_truncated_literal_payload"}
			if out.size() + lit_len > u_len:
				return {"ok": false, "reason": "snappy_output_overflow"}
			out.append_array(compressed.slice(pos, pos + lit_len))
			pos += lit_len
		elif kind == 1:
			if pos >= n:
				return {"ok": false, "reason": "snappy_truncated_copy1"}
			var next_b: int = compressed[pos]
			pos += 1
			var copy_len1: int = ((tag >> 2) & 0x07) + 4
			var offset1: int = ((tag & 0xE0) << 3) | next_b
			if offset1 <= 0 or offset1 > out.size():
				return {"ok": false, "reason": "snappy_invalid_copy1_offset"}
			if out.size() + copy_len1 > u_len:
				return {"ok": false, "reason": "snappy_output_overflow"}
			for _i1: int in range(copy_len1):
				out.append(out[out.size() - offset1])
		elif kind == 2:
			if pos + 2 > n:
				return {"ok": false, "reason": "snappy_truncated_copy2"}
			var copy_len2: int = ((tag >> 2) & 0x3F) + 1
			var offset2: int = compressed.decode_u16(pos)
			pos += 2
			if offset2 <= 0 or offset2 > out.size():
				return {"ok": false, "reason": "snappy_invalid_copy2_offset"}
			if out.size() + copy_len2 > u_len:
				return {"ok": false, "reason": "snappy_output_overflow"}
			for _i2: int in range(copy_len2):
				out.append(out[out.size() - offset2])
		else:
			if pos + 4 > n:
				return {"ok": false, "reason": "snappy_truncated_copy4"}
			var copy_len4: int = ((tag >> 2) & 0x3F) + 1
			var offset4: int = compressed.decode_u32(pos)
			pos += 4
			if offset4 <= 0 or offset4 > out.size():
				return {"ok": false, "reason": "snappy_invalid_copy4_offset"}
			if out.size() + copy_len4 > u_len:
				return {"ok": false, "reason": "snappy_output_overflow"}
			for _i4: int in range(copy_len4):
				out.append(out[out.size() - offset4])

	if out.size() != u_len:
		return {"ok": false, "reason": "snappy_uncompressed_length_mismatch"}
	return {"ok": true, "data": out}
