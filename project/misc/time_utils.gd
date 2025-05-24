@tool
class_name TimeUtils
extends RefCounted
## Utility class for consistent time handling across the project.
## All time values are in milliseconds for consistency.


## Get current time in milliseconds
static func now_ms() -> int:
	return Time.get_ticks_msec()


## Calculate elapsed time in milliseconds
static func elapsed_ms(start_ms: int) -> int:
	return now_ms() - start_ms


## Calculate a deadline timestamp in milliseconds
static func deadline_ms(timeout_sec: float) -> int:
	return now_ms() + int(timeout_sec * 1000)


## Check if a deadline has passed
static func is_past_deadline(deadline_ms: int) -> bool:
	return now_ms() > deadline_ms


## Convert seconds to milliseconds
static func sec_to_ms(seconds: float) -> int:
	return int(seconds * 1000)


## Convert milliseconds to seconds
static func ms_to_sec(milliseconds: int) -> float:
	return float(milliseconds) / 1000.0
