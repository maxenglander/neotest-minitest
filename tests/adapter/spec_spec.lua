local plugin = require("neotest-minitest")
local async = require("nio.tests")

describe("Spec Test", function()
  assert:set_parameter("TableFormatLevel", -1)
  describe("discover_positions", function()
    async.it("should discover the position fo the tests", function()
      local test_path = vim.loop.cwd() .. "/tests/minitest_examples/spec_test.rb"
      local positions = plugin.discover_positions(test_path):to_list()
      local expected_positions = {
        {
          id = test_path,
          name = "spec_test.rb",
          path = test_path,
          range = { 0, 0, 17, 0 },
          type = "file",
        },
        {
          {
            id = "./tests/minitest_examples/spec_test.rb::5",
            name = "SpecTest",
            path = test_path,
            range = { 4, 0, 16, 3 },
            type = "namespace",
          },
          {
            {
              id = "./tests/minitest_examples/spec_test.rb::6",
              name = "'#add'",
              path = test_path,
              range = { 5, 2, 9, 5 },
              type = "namespace",
            },
            {
              {
                id = "./tests/minitest_examples/spec_test.rb::7",
                name = "adds two numbers",
                path = test_path,
                range = { 6, 4, 8, 7 },
                type = "test",
              },
            },
          },
          {
            {
              id = "./tests/minitest_examples/spec_test.rb::12",
              name = "'#subtract'",
              path = test_path,
              range = { 11, 2, 15, 5 },
              type = "namespace",
            },
            {
              {
                id = "./tests/minitest_examples/spec_test.rb::13",
                name = "subtracts two numbers",
                path = test_path,
                range = { 12, 4, 14, 7 },
                type = "test",
              },
            },
          },
        },
      }

      assert.are.same(positions, expected_positions)
    end)
  end)

  describe("_parse_test_output", function()
    describe("single failing test", function()
      local output = [[
SpecTest#test_adds_two_numbers = 0.00 s = F


Failure:
SpecTest#test_adds_two_numbers [/src/nvim-neotest/neotest-minitest/tests/minitest_examples/spec_test.rb:8]:
Expected: 4
  Actual: 5


    ]]
      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, { ["SpecTest#test_adds_two_numbers"] = "testing" })

        assert.are.same(
          { ["testing"] = { status = "failed", errors = { { message = "Expected: 4\n  Actual: 5", line = 7 } } } },
          results
        )
      end)
    end)

    describe("single passing test with ruby error", function()
      local output = [[
Traceback (most recent call last):
        1: from tests/minitest_examples/rails_unit_erroring_test.rb:1:in `<main>'
tests/minitest_examples/rails_unit_erroring_test.rb:1:in `require': cannot load such file -- non_exising_file (LoadError)
      ]]

      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, { ["RailsUnitErroringTest#test_addition"] = "testing" })

        assert.are.same({
          ["testing"] = {
            status = "failed",
            errors = {
              { message = "in `require': cannot load such file -- non_exising_file (LoadError)", line = 0 },
            },
          },
        }, results)
      end)
    end)

    describe("multiple tests with ruby error", function()
      local output = [[
Traceback (most recent call last):
        1: from tests/minitest_examples/rails_unit_erroring_test.rb:1:in `<main>'
tests/minitest_examples/rails_unit_erroring_test.rb:1:in `require': cannot load such file -- non_exising_file (LoadError)
      ]]

      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, {
          ["RailsUnitErroringTest#test_addition"] = "testing",
          ["SpecTest#test_subtracts_two_numbers"] = "testing1",
        })

        assert.are.same({
          ["testing"] = {
            status = "failed",
            errors = {
              { message = "in `require': cannot load such file -- non_exising_file (LoadError)", line = 0 },
            },
          },
          ["testing1"] = {
            status = "failed",
            errors = {
              { message = "in `require': cannot load such file -- non_exising_file (LoadError)", line = 0 },
            },
          },
        }, results)
      end)
    end)

    describe("single passing test", function()
      local output = [[
SpecTest#test_subtracts_two_numbers = 0.00 s = .
]]

      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, { ["SpecTest#test_subtracts_two_numbers"] = "testing" })

        assert.are.same({ ["testing"] = { status = "passed" } }, results)
      end)
    end)

    describe("failing and passing tests", function()
      local output = [[
SpecTest#test_subtracts_two_numbers = 0.00 s = .
SpecTest#test_adds_two_numbers = 0.00 s = F


Failure:
SpecTest#test_adds_two_numbers [/neotest-minitest/tests/minitest_examples/spec_test.rb:8]:
Expected: 4
  Actual: 5


    ]]

      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, {
          ["SpecTest#test_adds_two_numbers"] = "testing",
          ["SpecTest#test_subtracts_two_numbers"] = "testing2",
        })

        assert.are.same({
          ["testing"] = { status = "failed", errors = { { message = "Expected: 4\n  Actual: 5", line = 7 } } },
          ["testing2"] = { status = "passed" },
        }, results)
      end)
    end)

    describe("multiple failing tests", function()
      local output = [[
SpecTest#test_adds_two_numbers = 0.00 s = F


Failure:
SpecTest#test_adds_two_numbers [/neotest-minitest/tests/minitest_examples/spec_test.rb:8]:
Expected: 4
  Actual: 5


rails test Users/abry/src/nvim-neotest/neotest-minitest/tests/minitest_examples/spec_test.rb:7

SpecTest#test_subtracts_two_numbers = 0.00 s = F


Failure:
SpecTest#test_subtracts_two_numbers [/neotest-minitest/tests/minitest_examples/spec_test.rb:11]:
Expected: 1
  Actual: 2


  ]]
      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, {
          ["SpecTest#test_adds_two_numbers"] = "testing",
          ["SpecTest#test_subtracts_two_numbers"] = "testing2",
        })

        assert.are.same({
          ["testing"] = { status = "failed", errors = { { message = "Expected: 4\n  Actual: 5", line = 7 } } },
          ["testing2"] = { status = "failed", errors = { { message = "Expected: 1\n  Actual: 2", line = 10 } } },
        }, results)
      end)
    end)

    describe("multiple passing tests", function()
      local output = [[
SpecTest#test_subtracts_two_numbers = 0.00 s = .
SpecTest#test_adds_two_numbers = 0.00 s = .
    ]]

      it("parses the results correctly", function()
        local results = plugin._parse_test_output(output, {
          ["SpecTest#test_adds_two_numbers"] = "testing",
          ["SpecTest#test_subtracts_two_numbers"] = "testing2",
        })

        assert.are.same({
          ["testing"] = { status = "passed" },
          ["testing2"] = { status = "passed" },
        }, results)
      end)
    end)
  end)
end)
