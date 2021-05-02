include("lib/utils.jl")
include("lib/json.jl")

struct Token
  lineno::Int
  kind::String
  value::String
end

tokens = Token[]
pos = 1

# --------------------------------

function peek(offset = 0)
  tokens[pos + offset]
end

function consume(str)
  if peek().value == str
    global pos += 1
  else
    error("unexpected token ($( peek() ))")
  end
end

function inc_pos()
  global pos += 1
end

function is_end()
  length(tokens) < pos
end

# --------------------------------

function parse_arg()
  t = peek()
  inc_pos()

  if t.kind == "ident"
    t.value
  elseif t.kind == "int"
    parse(Int, t.value)
  else
    error("unexpected kind $(t)")
  end
end

function parse_args()
  args = []

  if peek().value == ")"
    return args
  end

  push!(args, parse_arg())

  while peek().value == ","
    consume(",")
    push!(args, parse_arg())
  end

  args
end

function parse_expr_right()
  t = peek()

  if t.value == "+"
    consume("+")
    expr_r = parse_expr()
    ["+", expr_r]
  elseif t.value == "*"
    consume("*")
    expr_r = parse_expr()
    ["*", expr_r]
  elseif t.value == "=="
    consume("==")
    expr_r = parse_expr()
    ["eq", expr_r]
  elseif t.value == "!="
    consume("!=")
    expr_r = parse_expr()
    ["neq", expr_r]
  else
    error("unexpected token")
  end
end

function next_binop()
  val = peek().value

  val == "+" ||
  val == "*" ||
  val == "==" ||
  val == "!="
end

function parse_expr()
  t_left = peek()

  if t_left.value == "("
    consume("(")
    expr_l = parse_expr()
    consume(")")
  else
    inc_pos()
    if t_left.kind == "int"
      expr_l = parse(Int, t_left.value)
    elseif t_left.kind == "ident"
      expr_l = t_left.value
    else
      error("unexpected token")
    end
  end

  if next_binop()
    op, expr_r = parse_expr_right()
    [op, expr_l, expr_r]
  else
    expr_l
  end
end

function parse_set()
  consume("set")

  var_name = peek().value
  inc_pos()
  
  consume("=")

  expr = parse_expr()

  consume(";")

  ["set", var_name, expr]
end

function _parse_funcall()
  fn_name = peek().value
  inc_pos()

  consume("(")
  args = parse_args()
  consume(")")

  vcat([fn_name], args)
end

function parse_call()
  consume("call")

  funcall = _parse_funcall()

  consume(";")

  vcat(["call"], funcall)
end

function parse_call_set()
  consume("call_set")

  var_name = peek().value
  inc_pos()

  consume("=")
  funcall = _parse_funcall()
  consume(";")

  ["call_set", var_name, funcall]
end

function parse_return()
  consume("return")

  expr = parse_expr()

  consume(";")

  ["return", expr]
end

function parse_while()
  consume("while")

  consume("(")
  expr = parse_expr()
  consume(")")

  consume("{")
  stmts = parse_stmts()
  consume("}")

  ["while", expr, stmts]
end

function _parse_when_clause()
  consume("when")

  consume("(")
  expr = parse_expr()
  consume(")")

  consume("{")
  stmts = parse_stmts()
  consume("}")

  vcat([expr], stmts)
end

function parse_case()
  consume("case")

  when_clauses = Any[]

  while peek().value == "when"
    push!(when_clauses, _parse_when_clause())
  end

  vcat(["case"], when_clauses)
end

function parse_vm_comment()
  consume("_cmt")
  consume("(")

  vm_comment = peek().value
  inc_pos()

  consume(")")
  consume(";")

  ["_cmt", vm_comment]
end

function parse_stmt()
  t = peek()

  if t.value == "set"
    parse_set()
  elseif t.value == "call"
    parse_call()
  elseif t.value == "call_set"
    parse_call_set()
  elseif t.value == "return"
    parse_return()
  elseif t.value == "while"
    parse_while()
  elseif t.value == "case"
    parse_case()
  elseif t.value == "_cmt"
    parse_vm_comment()
  else
    error("unexpected token ($(t))")
  end
end

function parse_stmts()
  stmts = []

  while peek().value != "}"
    push!(stmts, parse_stmt())
  end

  stmts
end

function parse_var_declare()
  var_name = peek().value
  inc_pos()

  consume(";")

  ["var", var_name]
end

function parse_var_init()
  var_name = peek().value
  inc_pos()

  consume("=")

  expr = parse_expr()

  consume(";")

  ["var", var_name, expr]
end

function parse_var()
  consume("var")

  t1 = peek(1)
  if t1.value == ";"
    parse_var_declare()
  elseif t1.value == "="
    parse_var_init()
  else
    error("unexpected token")
  end
end

function parse_func()
  consume("func")

  fn_name = peek().value
  inc_pos()

  consume("(")
  args = parse_args()
  consume(")")

  consume("{")

  stmts = Any[]

  while peek().value != "}"
    if peek().value == "var"
      push!(stmts, parse_var())
    else
      push!(stmts, parse_stmt())
    end
  end

  consume("}")

  ["func", fn_name, args, stmts]
end

function parse_top_stmt()
  parse_func()
end

function parse_top_stmts()
  top_stmts = Any["top_stmts"]

  while ! is_end()
    push!(top_stmts, parse_top_stmt())
  end

  top_stmts
end

# --------------------------------

for line in readlines()
  list = json_parse(line)
  t = Token(
    list[1],
    list[2],
    list[3]
  )
  push!(tokens, t)
end

ast = parse_top_stmts()
json_print(ast, true)
