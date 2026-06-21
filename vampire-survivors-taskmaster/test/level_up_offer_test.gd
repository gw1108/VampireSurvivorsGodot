extends GdUnitTestSuite

## Verifies LevelUpOffer construction, defaults, and field access.

func test_defaults() -> void:
	var o := LevelUpOffer.new()
	assert_array(o.options).is_empty()
	assert_bool(o.is_max_state).is_false()


func test_is_ref_counted() -> void:
	assert_bool(LevelUpOffer.new() is RefCounted).is_true()


func test_mutability() -> void:
	var o := LevelUpOffer.new()
	o.is_max_state = true
	o.options.append({"kind": "weapon", "def": null, "is_upgrade": false, "target_level": 1})
	assert_bool(o.is_max_state).is_true()
	assert_int(o.options.size()).is_equal(1)
	assert_str(o.options[0]["kind"]).is_equal("weapon")


func test_options_is_per_instance() -> void:
	var a := LevelUpOffer.new()
	var b := LevelUpOffer.new()
	a.options.append({"kind": "passive"})
	assert_array(b.options).is_empty()
