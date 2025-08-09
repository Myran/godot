class_name TimeUtils
extends RefCounted


static func now_ms() -> int:
	return Time.get_ticks_msec()


static func elapsed_ms(start_ms: int) -> int:
	return now_ms() - start_ms


static func deadline_ms(timeout_sec: float) -> int:
	return now_ms() + int(timeout_sec * 1000)


static func is_past_deadline(deadline: int) -> bool:
	return now_ms() > deadline


static func sec_to_ms(seconds: float) -> int:
	return int(seconds * 1000)


static func ms_to_sec(milliseconds: int) -> float:
	return float(milliseconds) / 1000.0
