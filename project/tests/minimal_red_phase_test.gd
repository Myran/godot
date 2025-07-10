extends SceneTree
# Minimal test runner for RED phase validation

const TestReplayStateValidationRedPhaseAction = preload(
	"res://debug/actions/test_replay_state_validation_red_phase_action.gd"
)


func _init():
	print("🔴 Starting RED Phase Test Validation...")

	# Test the RED phase action directly
	var red_phase_action: TestReplayStateValidationRedPhaseAction = (
		TestReplayStateValidationRedPhaseAction.new()
	)

	print("📋 Executing RED phase tests...")
	var result: DebugAction.Result = await red_phase_action._execute_red_phase_tests()

	print("📊 Test Results:")
	print("  Success: ", result.is_success())
	print("  Payload: ", result.get_payload())
	print("  Error: ", result.get_error_message())

	if result.is_success():
		var payload: Dictionary = result.get_payload()
		print("✅ RED Phase Success - All ", payload.failed_tests, " tests failed as expected")
		print("   Failed tests: ", payload.failed_tests, "/", payload.total_tests)
	else:
		print("❌ RED Phase Failed: ", result.get_error_message())

	quit(0 if result.is_success() else 1)
