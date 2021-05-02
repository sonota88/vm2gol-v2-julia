include("../lib/utils.jl")
include("../lib/json.jl")

# --------------------------------

function test_01()
  list = []
  # println("[")
  # println("]")
  json_print(list)
end

function test_02()
  # println("[")
  # println("  1")
  # println("]")

  list = [1]
  json_print(list)
end

function test_03()
  # println("[")
  # println("  \"fdsa\"")
  # println("]")

  list = ["fdsa"]
  json_print(list)
end

function test_04()
  # println("[")
  # println("  -123,")
  # println("  \"fdsa\"")
  # println("]")

  list = [-123, "fdsa"]
  json_print(list)
end

function test_05()
  # println("[")
  # println("  [")
  # println("  ]")
  # println("]")

  list = [[]]
  json_print(list)
end

function test_06()
  # println("[")
  # println("  1,")
  # println("  \"a\",")
  # println("  [")
  # println("    2,")
  # println("    \"b\"")
  # println("  ],")
  # println("  3,")
  # println("  \"c\"")
  # println("]")

  list = [1, "a", [2, "b"], 3, "c"]
  json_print(list)
end

# test_01()
# test_02()
# test_03()
# test_04()
# test_05()
# test_06()

json = read_stdin_all()
list = json_parse(json)
json_print(list, true)
