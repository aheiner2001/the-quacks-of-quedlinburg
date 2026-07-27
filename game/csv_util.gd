class_name CsvUtil
extends RefCounted

static func parse_file(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CsvUtil: cannot open %s" % path)
		return rows
	var header_line := f.get_line().strip_edges()
	var headers := header_line.split(",")
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		var row := {}
		for i in headers.size():
			var key := str(headers[i]).strip_edges()
			var val := str(parts[i]).strip_edges() if i < parts.size() else ""
			row[key] = val
		rows.append(row)
	return rows
