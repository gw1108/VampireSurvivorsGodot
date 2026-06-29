## Smoke test to verify GDUnit4 is installed and tests execute in this project.
## Run headlessly with: addons/gdUnit4/runtest.cmd -a test
## Delete this file and smoke_test.gd.uid when adding a new test.
extends GdUnitTestSuite

func test_array_assertion() -> void:
	assert_array([1, 2, 3]).contains([2])
