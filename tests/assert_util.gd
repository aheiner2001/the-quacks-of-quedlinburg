class_name AssertUtil
extends RefCounted

static func eq(actual, expected, label: String) -> int:
	if actual != expected:
		push_error("FAIL %s: got %s expected %s" % [label, str(actual), str(expected)])
		return 1
	print("PASS %s" % label)
	return 0

static func truthy(actual: bool, label: String) -> int:
	return eq(actual, true, label)
