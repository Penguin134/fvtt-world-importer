extends RefCounted

const _WAL_BLOCK_SIZE: int = 32768
const _WAL_HEADER_SIZE: int = 7
const _FOOTER_MAGIC_LO: int = 0x8b80fb57
const _FOOTER_MAGIC_HI: int = 0xdb477524


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


static func _decode_varint(bytes: PackedByteArray, start_pos: int) -> Dictionary:
	var n: int = bytes.size()
	var pos: int = start_pos
	var val: int = 0
	var shift: int = 0
	while pos < n:
		if shift > 63:
			return {"ok": false, "reason": "varint_overflow"}
		var b: int = bytes[pos]
		pos += 1
		if shift == 63 and (b & 0xFE) != 0:
			return {"ok": false, "reason": "varint_overflow"}
		val |= ((b & 0x7F) << shift)
		if (b & 0x80) == 0:
			return {"ok": true, "val": val, "pos": pos}
		shift += 7
	return {"ok": false, "reason": "varint_truncated"}


static func _parse_file_number(fname: String) -> int:
	var stem: String = fname.get_basename()
	if stem.is_empty():
		return -1
	for i: int in range(stem.length()):
		var c: int = stem.unicode_at(i)
		if c < 48 or c > 57:
			return -1
	var idx: int = 0
	while idx < stem.length() and stem.unicode_at(idx) == 48:
		idx += 1
	if idx == stem.length():
		return 0
	var digits: String = stem.substr(idx)
	if digits.length() > 19:
		return -1
	if digits.length() == 19 and digits > "9223372036854775807":
		return -1
	return int(digits)


func has_collection(source: RefCounted, collection_name: String) -> bool:
	if source == null or collection_name.is_empty():
		return false
	var prefix: String = "data/%s" % collection_name
	if source.has_file(prefix + "/CURRENT"):
		return true
	var files: PackedStringArray = source.list_files(prefix)
	for f: String in files:
		if f.get_base_dir() != prefix:
			continue
		var fname: String = f.get_file()
		if fname.begins_with("MANIFEST-") or f.ends_with(".ldb") or f.ends_with(".log"):
			return true
	return false


func parse_wal_bytes(bytes: PackedByteArray) -> Dictionary:
	var records: Array[PackedByteArray] = []
	var warnings: Array[String] = []
	var parse_errors: int = 0
	var n: int = bytes.size()
	if n == 0:
		return {"ok": true, "records": records, "parse_errors": 0, "warnings": warnings}

	var frag_buf := PackedByteArray()
	var in_fragment: bool = false
	var block_start: int = 0

	while block_start < n:
		var block_end: int = mini(block_start + _WAL_BLOCK_SIZE, n)
		var pos: int = block_start
		while pos <= block_end - _WAL_HEADER_SIZE:
			var _crc: int = bytes.decode_u32(pos)
			var length: int = bytes.decode_u16(pos + 4)
			var rtype: int = bytes[pos + 6]
			pos += _WAL_HEADER_SIZE

			if rtype == 0 and length == 0:
				break
			if length < 0 or pos > block_end or length > block_end - pos:
				parse_errors += 1
				warnings.append("LevelDB WAL 记录在偏移 %d 处截断，已提前终止" % pos)
				in_fragment = false
				frag_buf = PackedByteArray()
				return {"ok": true, "records": records, "parse_errors": parse_errors, "warnings": warnings}

			var frag: PackedByteArray = bytes.slice(pos, pos + length) if length > 0 else PackedByteArray()
			pos += length

			if rtype == 1:
				if in_fragment:
					parse_errors += 1
					warnings.append("LevelDB WAL 分片未闭合即遇到 Full 记录，已重置分片缓存")
					in_fragment = false
					frag_buf = PackedByteArray()
				records.append(frag)
			elif rtype == 2:
				if in_fragment:
					parse_errors += 1
					warnings.append("LevelDB WAL 分片未闭合即遇到新的 First 记录，已重置分片缓存")
				frag_buf = PackedByteArray()
				frag_buf.append_array(frag)
				in_fragment = true
			elif rtype == 3:
				if not in_fragment:
					parse_errors += 1
					warnings.append("LevelDB WAL 遇到孤立 Middle 分片，已跳过")
				else:
					frag_buf.append_array(frag)
			elif rtype == 4:
				if not in_fragment:
					parse_errors += 1
					warnings.append("LevelDB WAL 遇到孤立 Last 分片，已跳过")
				else:
					frag_buf.append_array(frag)
					records.append(frag_buf)
					frag_buf = PackedByteArray()
					in_fragment = false
			else:
				parse_errors += 1
				warnings.append("LevelDB WAL 遇到未知记录类型 %d，已终止解析" % rtype)
				in_fragment = false
				frag_buf = PackedByteArray()
				return {"ok": true, "records": records, "parse_errors": parse_errors, "warnings": warnings}

		block_start += _WAL_BLOCK_SIZE

	if in_fragment:
		parse_errors += 1
		warnings.append("LevelDB WAL 末尾存在未闭合分片记录，已丢弃")

	return {"ok": true, "records": records, "parse_errors": parse_errors, "warnings": warnings}


func _parse_write_batch(wb: PackedByteArray) -> Dictionary:
	if wb.size() < 12:
		return {"ok": false, "reason": "write_batch_too_short"}
	var batch_seq: int = wb.decode_u64(0)
	var count: int = wb.decode_u32(8)
	var pos: int = 12
	if count < 0 or count > wb.size() - pos:
		return {"ok": false, "reason": "write_batch_truncated"}
	var entries: Array[Dictionary] = []

	for i: int in range(count):
		if pos >= wb.size():
			return {"ok": false, "reason": "write_batch_truncated"}
		var op: int = wb[pos]
		pos += 1
		var klen_res: Dictionary = _decode_varint(wb, pos)
		if not bool(klen_res.get("ok", false)):
			return {"ok": false, "reason": "write_batch_bad_klen"}
		var klen: int = int(klen_res["val"])
		pos = int(klen_res["pos"])
		if klen < 0 or pos > wb.size() or klen > wb.size() - pos:
			return {"ok": false, "reason": "write_batch_key_oob"}
		var ukey: PackedByteArray = wb.slice(pos, pos + klen) if klen > 0 else PackedByteArray()
		pos += klen

		var val := PackedByteArray()
		if op == 1:
			var vlen_res: Dictionary = _decode_varint(wb, pos)
			if not bool(vlen_res.get("ok", false)):
				return {"ok": false, "reason": "write_batch_bad_vlen"}
			var vlen: int = int(vlen_res["val"])
			pos = int(vlen_res["pos"])
			if vlen < 0 or pos > wb.size() or vlen > wb.size() - pos:
				return {"ok": false, "reason": "write_batch_val_oob"}
			val = wb.slice(pos, pos + vlen) if vlen > 0 else PackedByteArray()
			pos += vlen
		elif op != 0:
			return {"ok": false, "reason": "write_batch_unknown_op_%d" % op}

		var seq: int = (batch_seq + i) & 0x00FFFFFFFFFFFFFF
		entries.append({"user_key": ukey, "seq": seq, "vt": op, "val": val})

	return {"ok": true, "entries": entries}


func _parse_leveldb_block(raw_block: PackedByteArray) -> Dictionary:
	var n: int = raw_block.size()
	if n < 4:
		return {"ok": false, "reason": "block_too_short"}
	var num_restarts: int = raw_block.decode_u32(n - 4)
	if num_restarts < 0 or (4 + num_restarts * 4) > n:
		return {"ok": false, "reason": "block_invalid_restarts"}
	var data_end: int = n - 4 - (num_restarts * 4)
	var pos: int = 0
	var prev_key := PackedByteArray()
	var entries: Array = []

	while pos < data_end:
		var s_res: Dictionary = _decode_varint(raw_block, pos)
		if not bool(s_res.get("ok", false)):
			return {"ok": false, "reason": "block_bad_shared"}
		var shared: int = int(s_res["val"])
		pos = int(s_res["pos"])

		var ns_res: Dictionary = _decode_varint(raw_block, pos)
		if not bool(ns_res.get("ok", false)):
			return {"ok": false, "reason": "block_bad_non_shared"}
		var non_shared: int = int(ns_res["val"])
		pos = int(ns_res["pos"])

		var vl_res: Dictionary = _decode_varint(raw_block, pos)
		if not bool(vl_res.get("ok", false)):
			return {"ok": false, "reason": "block_bad_val_len"}
		var val_len: int = int(vl_res["val"])
		pos = int(vl_res["pos"])

		if shared < 0 or non_shared < 0 or val_len < 0:
			return {"ok": false, "reason": "block_negative_lengths"}
		if shared > prev_key.size():
			return {"ok": false, "reason": "block_shared_exceeds_prev_key"}
		if pos > data_end or non_shared > data_end - pos or val_len > data_end - pos - non_shared:
			return {"ok": false, "reason": "block_entry_oob"}

		var key := PackedByteArray()
		if shared > 0:
			key.append_array(prev_key.slice(0, shared))
		if non_shared > 0:
			key.append_array(raw_block.slice(pos, pos + non_shared))
		pos += non_shared

		var val: PackedByteArray = raw_block.slice(pos, pos + val_len) if val_len > 0 else PackedByteArray()
		pos += val_len

		prev_key = key
		entries.append([key, val])

	return {"ok": true, "entries": entries}


func _read_framed_block(bytes: PackedByteArray, offset: int, size: int, snappy_impl: RefCounted) -> Dictionary:
	if offset < 0 or size < 0 or bytes.size() < 5 or offset > bytes.size() - 5 or size > bytes.size() - 5 - offset:
		return {"ok": false, "reason": "sstable_block_oob"}
	var ctype: int = bytes[offset + size]
	var payload: PackedByteArray = bytes.slice(offset, offset + size) if size > 0 else PackedByteArray()
	if ctype == 0:
		return {"ok": true, "data": payload}
	elif ctype == 1:
		if snappy_impl == null:
			return {"ok": false, "reason": "snappy_impl_missing"}
		return snappy_impl.decompress(payload)
	return {"ok": false, "reason": "sstable_unknown_compression_%d" % ctype}


func parse_ldb_bytes(bytes: PackedByteArray, snappy_impl: RefCounted) -> Dictionary:
	var n: int = bytes.size()
	if n < 48:
		return {"ok": false, "reason": "sstable_too_short"}
	var f_off: int = n - 48
	var magic_lo: int = bytes.decode_u32(f_off + 40)
	var magic_hi: int = bytes.decode_u32(f_off + 44)
	if magic_lo != _FOOTER_MAGIC_LO or magic_hi != _FOOTER_MAGIC_HI:
		return {"ok": false, "reason": "sstable_invalid_magic"}

	var footer_handles: PackedByteArray = bytes.slice(f_off, f_off + 40)
	var hpos: int = 0
	var _meta_off_res: Dictionary = _decode_varint(footer_handles, hpos)
	if not bool(_meta_off_res.get("ok", false)):
		return {"ok": false, "reason": "sstable_bad_metaindex_offset"}
	hpos = int(_meta_off_res["pos"])
	var _meta_sz_res: Dictionary = _decode_varint(footer_handles, hpos)
	if not bool(_meta_sz_res.get("ok", false)):
		return {"ok": false, "reason": "sstable_bad_metaindex_size"}
	hpos = int(_meta_sz_res["pos"])

	var idx_off_res: Dictionary = _decode_varint(footer_handles, hpos)
	if not bool(idx_off_res.get("ok", false)):
		return {"ok": false, "reason": "sstable_bad_index_offset"}
	var idx_off: int = int(idx_off_res["val"])
	hpos = int(idx_off_res["pos"])

	var idx_sz_res: Dictionary = _decode_varint(footer_handles, hpos)
	if not bool(idx_sz_res.get("ok", false)):
		return {"ok": false, "reason": "sstable_bad_index_size"}
	var idx_sz: int = int(idx_sz_res["val"])

	var idx_raw_res: Dictionary = _read_framed_block(bytes, idx_off, idx_sz, snappy_impl)
	if not bool(idx_raw_res.get("ok", false)):
		return idx_raw_res
	var idx_blk_res: Dictionary = _parse_leveldb_block(idx_raw_res["data"])
	if not bool(idx_blk_res.get("ok", false)):
		return idx_blk_res

	var entries: Array[Dictionary] = []
	for idx_pair: Variant in idx_blk_res["entries"]:
		var handle_bytes: PackedByteArray = (idx_pair as Array)[1]
		var bo_res: Dictionary = _decode_varint(handle_bytes, 0)
		if not bool(bo_res.get("ok", false)):
			return {"ok": false, "reason": "sstable_bad_data_block_offset"}
		var blk_off: int = int(bo_res["val"])
		var bs_res: Dictionary = _decode_varint(handle_bytes, int(bo_res["pos"]))
		if not bool(bs_res.get("ok", false)):
			return {"ok": false, "reason": "sstable_bad_data_block_size"}
		var blk_sz: int = int(bs_res["val"])

		var data_raw_res: Dictionary = _read_framed_block(bytes, blk_off, blk_sz, snappy_impl)
		if not bool(data_raw_res.get("ok", false)):
			return data_raw_res
		var data_blk_res: Dictionary = _parse_leveldb_block(data_raw_res["data"])
		if not bool(data_blk_res.get("ok", false)):
			return data_blk_res

		for kv_pair: Variant in data_blk_res["entries"]:
			var ikey: PackedByteArray = (kv_pair as Array)[0]
			var val: PackedByteArray = (kv_pair as Array)[1]
			if ikey.size() < 8:
				return {"ok": false, "reason": "sstable_internal_key_too_short"}
			var split_at: int = ikey.size() - 8
			var ukey: PackedByteArray = ikey.slice(0, split_at) if split_at > 0 else PackedByteArray()
			var tag: int = ikey.decode_u64(split_at)
			var vt: int = tag & 0xFF
			var seq: int = (tag >> 8) & 0x00FFFFFFFFFFFFFF
			entries.append({"user_key": ukey, "seq": seq, "vt": vt, "val": val})

	return {"ok": true, "entries": entries}


func _parse_manifest(manifest_bytes: PackedByteArray) -> Dictionary:
	var wal_res: Dictionary = parse_wal_bytes(manifest_bytes)
	var records: Array = wal_res.get("records", [])
	if records.is_empty():
		return {"ok": false, "reason": "manifest_empty"}

	var active_files: Dictionary = {}
	var log_number: int = 0
	var prev_log_number: int = -1

	for rec_var: Variant in records:
		var rec: PackedByteArray = rec_var
		var pos: int = 0
		var n: int = rec.size()
		while pos < n:
			var tag_res: Dictionary = _decode_varint(rec, pos)
			if not bool(tag_res.get("ok", false)):
				return {"ok": false, "reason": "manifest_bad_tag"}
			var tag: int = int(tag_res["val"])
			pos = int(tag_res["pos"])

			match tag:
				1:
					var clen_res: Dictionary = _decode_varint(rec, pos)
					if not bool(clen_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_comparator"}
					var clen: int = int(clen_res["val"])
					pos = int(clen_res["pos"])
					if clen < 0 or pos > n or clen > n - pos:
						return {"ok": false, "reason": "manifest_comparator_oob"}
					pos += clen
				2:
					var ln_res: Dictionary = _decode_varint(rec, pos)
					if not bool(ln_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_log_number"}
					log_number = int(ln_res["val"])
					pos = int(ln_res["pos"])
				3:
					var nf_res: Dictionary = _decode_varint(rec, pos)
					if not bool(nf_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_next_file"}
					pos = int(nf_res["pos"])
				4:
					var ls_res: Dictionary = _decode_varint(rec, pos)
					if not bool(ls_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_last_seq"}
					pos = int(ls_res["pos"])
				5:
					var cpl_res: Dictionary = _decode_varint(rec, pos)
					if not bool(cpl_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_compact_level"}
					pos = int(cpl_res["pos"])
					var cpk_res: Dictionary = _decode_varint(rec, pos)
					if not bool(cpk_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_compact_klen"}
					var cpk_len: int = int(cpk_res["val"])
					pos = int(cpk_res["pos"])
					if cpk_len < 0 or pos > n or cpk_len > n - pos:
						return {"ok": false, "reason": "manifest_compact_oob"}
					pos += cpk_len
				6:
					var dl_res: Dictionary = _decode_varint(rec, pos)
					if not bool(dl_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_del_level"}
					var d_level: int = int(dl_res["val"])
					pos = int(dl_res["pos"])
					var df_res: Dictionary = _decode_varint(rec, pos)
					if not bool(df_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_del_file"}
					var d_fnum: int = int(df_res["val"])
					pos = int(df_res["pos"])
					active_files.erase("%d:%d" % [d_level, d_fnum])
				7:
					var nl_res: Dictionary = _decode_varint(rec, pos)
					if not bool(nl_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_new_level"}
					var n_level: int = int(nl_res["val"])
					pos = int(nl_res["pos"])
					var nf2_res: Dictionary = _decode_varint(rec, pos)
					if not bool(nf2_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_new_file"}
					var n_fnum: int = int(nf2_res["val"])
					pos = int(nf2_res["pos"])
					var nfs_res: Dictionary = _decode_varint(rec, pos)
					if not bool(nfs_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_new_fsize"}
					pos = int(nfs_res["pos"])
					var min_res: Dictionary = _decode_varint(rec, pos)
					if not bool(min_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_min_key"}
					var min_len: int = int(min_res["val"])
					pos = int(min_res["pos"])
					if min_len < 0 or pos > n or min_len > n - pos:
						return {"ok": false, "reason": "manifest_min_key_oob"}
					pos += min_len
					var max_res: Dictionary = _decode_varint(rec, pos)
					if not bool(max_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_max_key"}
					var max_len: int = int(max_res["val"])
					pos = int(max_res["pos"])
					if max_len < 0 or pos > n or max_len > n - pos:
						return {"ok": false, "reason": "manifest_max_key_oob"}
					pos += max_len
					active_files["%d:%d" % [n_level, n_fnum]] = n_fnum
				9:
					var pln_res: Dictionary = _decode_varint(rec, pos)
					if not bool(pln_res.get("ok", false)):
						return {"ok": false, "reason": "manifest_bad_prev_log"}
					prev_log_number = int(pln_res["val"])
					pos = int(pln_res["pos"])
				_:
					return {"ok": false, "reason": "manifest_unknown_tag_%d" % tag}

	var fnums: Array[int] = []
	for v: Variant in active_files.values():
		fnums.append(int(v))
	fnums.sort()
	return {
		"ok": true,
		"active_fnums": fnums,
		"log_number": log_number,
		"prev_log_number": prev_log_number,
		"warnings": wal_res.get("warnings", []),
		"parse_errors": int(wal_res.get("parse_errors", 0)),
	}


func read_collection(
	source: RefCounted,
	collection_name: String,
	snappy_impl: RefCounted,
	session: RefCounted = null
) -> Dictionary:
	var prefix: String = "data/%s" % collection_name
	if not has_collection(source, collection_name):
		return {
			"ok": false,
			"reason": "leveldb_collection_not_found:" + prefix,
			"docs": [] as Array[Dictionary],
			"sublevels": {},
			"parse_errors": 0,
			"warnings": [] as Array[String],
		}

	var warnings: Array[String] = []
	var parse_errors: int = 0
	var files: PackedStringArray = source.list_files(prefix)
	var ldb_by_num: Dictionary = {}
	var log_by_num: Dictionary = {}
	var all_ldb_sorted: Array[String] = []
	var all_log_sorted: Array[String] = []

	for fpath: String in files:
		if fpath.get_base_dir() != prefix:
			continue
		var fname: String = fpath.get_file()
		var fnum: int = _parse_file_number(fname)
		if fname.ends_with(".ldb"):
			all_ldb_sorted.append(fpath)
			if fnum >= 0:
				ldb_by_num[fnum] = fpath
		elif fname.ends_with(".log"):
			all_log_sorted.append(fpath)
			if fnum >= 0:
				log_by_num[fnum] = fpath
	all_ldb_sorted.sort()
	all_log_sorted.sort()

	var ldb_paths: Array[String] = []
	var log_paths: Array[String] = []
	var used_manifest: bool = false

	var current_rel: String = prefix + "/CURRENT"
	if source.has_file(current_rel):
		var manifest_name: String = source.read_text(current_rel).strip_edges()
		if source.has_method("get_last_read_error"):
			var curr_err: String = str(source.get_last_read_error())
			if not curr_err.is_empty():
				return {
					"ok": false,
					"reason": curr_err,
					"docs": [] as Array[Dictionary],
					"sublevels": {},
					"parse_errors": parse_errors + 1,
					"warnings": warnings,
				}
		if not manifest_name.is_empty():
			var manifest_rel: String = prefix + "/" + manifest_name
			if source.has_file(manifest_rel):
				var mbytes: PackedByteArray = source.read_bytes(manifest_rel)
				if source.has_method("get_last_read_error"):
					var man_err: String = str(source.get_last_read_error())
					if not man_err.is_empty():
						return {
							"ok": false,
							"reason": man_err,
							"docs": [] as Array[Dictionary],
							"sublevels": {},
							"parse_errors": parse_errors + 1,
							"warnings": warnings,
						}
				var mres: Dictionary = _parse_manifest(mbytes)
				if bool(mres.get("ok", false)):
					used_manifest = true
					for mw: String in mres.get("warnings", []):
						warnings.append(mw)
					parse_errors += int(mres.get("parse_errors", 0))
					var active_fnums: Array = mres.get("active_fnums", [])
					var missing_active: int = 0
					for af: Variant in active_fnums:
						var af_num: int = int(af)
						if ldb_by_num.has(af_num):
							ldb_paths.append(str(ldb_by_num[af_num]))
						else:
							missing_active += 1
					if missing_active > 0 and ldb_paths.is_empty() and not all_ldb_sorted.is_empty():
						used_manifest = false
						ldb_paths.clear()
						warnings.append("LevelDB %s MANIFEST 引用的 SSTable 缺失，回退全量扫描" % collection_name)
					else:
						if missing_active > 0:
							warnings.append("LevelDB %s MANIFEST 引用的部分 SSTable 缺失（缺失 %d 个，已加载 %d 个）" % [collection_name, missing_active, ldb_paths.size()])
						var log_num: int = int(mres.get("log_number", 0))
						var prev_log: int = int(mres.get("prev_log_number", -1))
						var log_fnums: Array[int] = []
						for k_num: Variant in log_by_num.keys():
							var ln: int = int(k_num)
							if log_num <= 0 or ln >= log_num or (prev_log >= 0 and ln == prev_log):
								log_fnums.append(ln)
						log_fnums.sort()
						for lf: int in log_fnums:
							log_paths.append(str(log_by_num[lf]))
				else:
					warnings.append("LevelDB %s MANIFEST 解析失败（%s），回退全量扫描" % [collection_name, str(mres.get("reason", ""))])
			else:
				warnings.append("LevelDB %s CURRENT 引用的 MANIFEST 文件缺失（%s），回退全量扫描" % [collection_name, manifest_name])

	if not used_manifest:
		ldb_paths = all_ldb_sorted
		log_paths = all_log_sorted

	var state: Dictionary = {}

	for ldb_rel: String in ldb_paths:
		var sbytes: PackedByteArray = source.read_bytes(ldb_rel)
		if source.has_method("get_last_read_error"):
			var ldb_read_err: String = str(source.get_last_read_error())
			if not ldb_read_err.is_empty():
				for w_read: String in warnings:
					if session != null and session.has_method("add_warning"):
						session.add_warning(w_read)
				return {
					"ok": false,
					"reason": ldb_read_err,
					"docs": [] as Array[Dictionary],
					"sublevels": {},
					"parse_errors": parse_errors + 1,
					"warnings": warnings,
				}
		var sres: Dictionary = parse_ldb_bytes(sbytes, snappy_impl)
		if not bool(sres.get("ok", false)):
			var err_reason: String = str(sres.get("reason", "sstable_error"))
			for w0: String in warnings:
				if session != null and session.has_method("add_warning"):
					session.add_warning(w0)
			return {
				"ok": false,
				"reason": "%s:%s" % [ldb_rel, err_reason],
				"docs": [] as Array[Dictionary],
				"sublevels": {},
				"parse_errors": parse_errors + 1,
				"warnings": warnings,
			}
		for entry: Dictionary in sres["entries"]:
			var ukey: PackedByteArray = entry["user_key"]
			var khex: String = ukey.hex_encode()
			var seq: int = int(entry["seq"])
			var vt: int = int(entry["vt"])
			var should_take: bool = not state.has(khex)
			if not should_take:
				var prev: Dictionary = state[khex]
				var prev_seq: int = int(prev["seq"])
				var prev_vt: int = int(prev["vt"])
				should_take = seq > prev_seq or (seq == prev_seq and vt > prev_vt)
			if should_take:
				state[khex] = entry

	for log_rel: String in log_paths:
		var lbytes: PackedByteArray = source.read_bytes(log_rel)
		if source.has_method("get_last_read_error"):
			var log_read_err: String = str(source.get_last_read_error())
			if not log_read_err.is_empty():
				for w_log: String in warnings:
					if session != null and session.has_method("add_warning"):
						session.add_warning(w_log)
				return {
					"ok": false,
					"reason": log_read_err,
					"docs": [] as Array[Dictionary],
					"sublevels": {},
					"parse_errors": parse_errors + 1,
					"warnings": warnings,
				}
		if lbytes.is_empty():
			continue
		var wres: Dictionary = parse_wal_bytes(lbytes)
		for ww: String in wres.get("warnings", []):
			warnings.append(ww)
		parse_errors += int(wres.get("parse_errors", 0))
		for wb_var: Variant in wres.get("records", []):
			var wb_res: Dictionary = _parse_write_batch(wb_var as PackedByteArray)
			if not bool(wb_res.get("ok", false)):
				parse_errors += 1
				warnings.append("LevelDB %s WAL WriteBatch 解析失败（%s），已跳过" % [log_rel, str(wb_res.get("reason", ""))])
				continue
			for w_entry: Dictionary in wb_res["entries"]:
				var ukey2: PackedByteArray = w_entry["user_key"]
				var khex2: String = ukey2.hex_encode()
				var seq2: int = int(w_entry["seq"])
				var vt2: int = int(w_entry["vt"])
				var should_take2: bool = not state.has(khex2)
				if not should_take2:
					var prev2: Dictionary = state[khex2]
					var prev_seq2: int = int(prev2["seq"])
					var prev_vt2: int = int(prev2["vt"])
					should_take2 = seq2 > prev_seq2 or (seq2 == prev_seq2 and vt2 >= prev_vt2)
				if should_take2:
					state[khex2] = w_entry

	var docs: Array[Dictionary] = []
	var sublevels: Dictionary = {}

	for khex_item: Variant in state.keys():
		var rec_entry: Dictionary = state[khex_item]
		if int(rec_entry["vt"]) == 0:
			continue
		var ukey_bytes: PackedByteArray = rec_entry["user_key"]
		var val_bytes: PackedByteArray = rec_entry["val"]
		if not _is_valid_utf8(ukey_bytes) or not _is_valid_utf8(val_bytes):
			parse_errors += 1
			warnings.append("LevelDB %s 记录包含非法 UTF-8 键或值，已跳过" % collection_name)
			continue
		var ukey_str: String = ukey_bytes.get_string_from_utf8()
		var val_str: String = val_bytes.get_string_from_utf8()
		var j := JSON.new()
		var jerr: Error = j.parse(val_str)
		if jerr != OK or not (j.data is Dictionary):
			parse_errors += 1
			warnings.append("LevelDB %s 键 %s 值不是合法 JSON 对象，已跳过" % [collection_name, ukey_str])
			continue
		var doc: Dictionary = j.data
		if ukey_str.begins_with("!"):
			var idx2: int = ukey_str.find("!", 1)
			if idx2 > 1:
				var sublevel: String = ukey_str.substr(1, idx2 - 1)
				var rec_key: String = ukey_str.substr(idx2 + 1)
				if not sublevels.has(sublevel):
					sublevels[sublevel] = {}
				(sublevels[sublevel] as Dictionary)[rec_key] = doc
				if sublevel == collection_name:
					docs.append(doc)
				continue
		docs.append(doc)

	if session != null and session.has_method("add_warning"):
		for w_msg: String in warnings:
			session.add_warning(w_msg)

	return {
		"ok": true,
		"docs": docs,
		"sublevels": sublevels,
		"parse_errors": parse_errors,
		"warnings": warnings,
	}
