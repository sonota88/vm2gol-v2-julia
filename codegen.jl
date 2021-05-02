include("lib/utils.jl")
include("lib/json.jl")

g_label_id = 0

function asm_prologue()
  println("  push bp")
  println("  cp sp bp")
end

function asm_epilogue()
  println("  cp bp sp")
  println("  pop bp")
end

# --------------------------------

function fn_arg_disp(lvar_names, lvar_name)
  i = find_index(lvar_names, lvar_name) - 1
  i + 2
end

function lvar_disp(lvar_names, lvar_name)
  i = find_index(lvar_names, lvar_name) - 1
  -(i + 1)
end

# --------------------------------

function _gen_expr_add()
  println("  pop reg_b")
  println("  pop reg_a")
  println("  add_ab")
end

function _gen_expr_mult()
  println("  pop reg_b")
  println("  pop reg_a")
  println("  mult_ab")
end

function _gen_expr_eq()
  global g_label_id += 1
  label_id = g_label_id

  label_end = "end_eq_$(label_id)"
  label_then = "then_$(label_id)"

  println("  pop reg_b")
  println("  pop reg_a")

  println("  compare")
  println("  jump_eq $(label_then)")

  println("  cp 0 reg_a")
  println("  jump $(label_end)")

  println("label $(label_then)")
  println("  cp 1 reg_a")

  println("label $(label_end)")
end

function _gen_expr_neq()
  global g_label_id += 1
  label_id = g_label_id

  label_end = "end_neq_$(label_id)"
  label_then = "then_$(label_id)"

  println("  pop reg_b")
  println("  pop reg_a")

  println("  compare")
  println("  jump_eq $(label_then)")

  println("  cp 1 reg_a")
  println("  jump $(label_end)")

  println("label $(label_then)")
  println("  cp 0 reg_a")

  println("label $(label_end)")
end

function _gen_expr_binary(fn_arg_names, lvar_names, expr)
  operator = expr[1]
  arg_l = expr[2]
  arg_r = expr[3]

  gen_expr(fn_arg_names, lvar_names, arg_l)
  println("  push reg_a")
  gen_expr(fn_arg_names, lvar_names, arg_r)
  println("  push reg_a")

  if operator == "+"
    _gen_expr_add()
  elseif operator == "*"
    _gen_expr_mult()
  elseif operator == "eq"
    _gen_expr_eq()
  elseif operator == "neq"
    _gen_expr_neq()
  else
    error("unknown operator")
  end
end

function gen_expr(fn_arg_names, lvar_names, expr)
  if expr isa Int
    println("  cp $(expr) reg_a")
  elseif expr isa String
    if expr in fn_arg_names
      disp = fn_arg_disp(fn_arg_names, expr)
      println("  cp [bp:$(disp)] reg_a")
    elseif expr in lvar_names
      disp = lvar_disp(lvar_names, expr)
      println("  cp [bp:$(disp)] reg_a")
    else
      error("must not happen")
    end
  elseif expr isa Array
    _gen_expr_binary(fn_arg_names, lvar_names, expr)
  else
    error("must not happen")
  end
end

function _gen_funcall(fn_arg_names, lvar_names, funcall)
  fn_name = funcall[1]
  fn_args = funcall[2:end]

  for fn_arg in reverse(fn_args)
    gen_expr(fn_arg_names, lvar_names, fn_arg)
    println("  push reg_a")
  end

  gen_vm_comment("call  $(fn_name)")
  println("  call $(fn_name)")
  println("  add_sp $(length(fn_args))")
end

function gen_call(fn_arg_names, lvar_names, stmt)
  fn_name = stmt[2]
  fn_args = stmt[3:end]

  for fn_arg in reverse(fn_args)
    gen_expr(fn_arg_names, lvar_names, fn_arg)
    println("  push reg_a")
  end

  gen_vm_comment("call  $(fn_name)")
  println("  call $(fn_name)")
  println("  add_sp $(length(fn_args))")
end

function gen_call_set(fn_arg_names, lvar_names, stmt)
  lvar_name = stmt[2]
  funcall = stmt[3]

  _gen_funcall(fn_arg_names, lvar_names, funcall)

  disp = lvar_disp(lvar_names, lvar_name)
  println("  cp reg_a [bp:$(disp)]")
end

function _gen_set(fn_arg_names, lvar_names, dest, expr)
  gen_expr(fn_arg_names, lvar_names, expr)

  if dest in lvar_names
    disp = lvar_disp(lvar_names, dest)
    println("  cp reg_a [bp:$(disp)]")
  else
    error("local variable not found ($(dest))")
  end
end

function gen_set(fn_arg_names, lvar_names, stmt)
  _gen_set(fn_arg_names, lvar_names, stmt[2], stmt[3])
end

function gen_return(lvar_names, stmt)
  retval = stmt[2]
  gen_expr([], lvar_names, retval)
end

function gen_while(fn_arg_names, lvar_names, stmt)
  cond_expr = stmt[2]
  body = stmt[3]

  global g_label_id += 1
  label_id = g_label_id

  label_begin = "while_$(label_id)"
  label_end = "end_while_$(label_id)"
  label_true = "true_$(label_id)"

  println("label $(label_begin)")

  gen_expr(fn_arg_names, lvar_names, cond_expr)

  println("  cp 1 reg_b")
  println("  compare")

  println("  jump_eq $(label_true)")
  println("  jump $(label_end)")

  println("label $(label_true)")

  gen_stmts(fn_arg_names, lvar_names, body)

  println("  jump $(label_begin)")

  println("label $(label_end)")
  println("")
end

function gen_case(fn_arg_names, lvar_names, stmt)
  when_clauses = stmt[2:end]

  global g_label_id += 1
  label_id = g_label_id

  when_idx = -1

  label_end = "end_case_$(label_id)"
  label_when_head = "when_$(label_id)"
  label_end_when_head = "end_when_$(label_id)"

  for when_clause in when_clauses
    when_idx += 1
    cond = when_clause[1]
    rest = when_clause[2:end]

    gen_expr(fn_arg_names, lvar_names, cond)
    println("  cp 1 reg_b")

    println("  compare")
    println("  jump_eq $(label_when_head)_$(when_idx)")
    println("  jump $(label_end_when_head)_$(when_idx)")

    println("label $(label_when_head)_$(when_idx)")

    gen_stmts(fn_arg_names, lvar_names, rest)

    println("  jump $(label_end)")

    println("label $(label_end_when_head)_$(when_idx)")
  end

  println("label $(label_end)")
  println("")
end

function gen_vm_comment(comment)
  cmt = replace.(comment , " " => "~")
  println("  _cmt $(cmt)")
end

function gen_stmt(fn_arg_names, lvar_names, stmt)
  head = stmt[1]

  if head == "set"
    gen_set(fn_arg_names, lvar_names, stmt)
  elseif head == "call"
    gen_call(fn_arg_names, lvar_names, stmt)
  elseif head == "call_set"
    gen_call_set(fn_arg_names, lvar_names, stmt)
  elseif head == "return"
    gen_return(lvar_names, stmt)
  elseif head == "while"
    gen_while(fn_arg_names, lvar_names, stmt)
  elseif head == "case"
    gen_case(fn_arg_names, lvar_names, stmt)
  elseif head == "_cmt"
    gen_vm_comment(stmt[2])
  else
    error("must not happen")
  end
end

function gen_stmts(fn_arg_names, lvar_names, stmts)
  for stmt in stmts
    gen_stmt(fn_arg_names, lvar_names, stmt)
  end
end

function gen_var(fn_arg_names, lvar_names, stmt)
  println("  sub_sp 1")

  if length(stmt) == 3
    _gen_set(fn_arg_names, lvar_names, stmt[2], stmt[3])
  end
end

function gen_func_def(func_def)
  fn_name = func_def[2]
  fn_arg_names = func_def[3]
  body = func_def[4]

  println("label $(fn_name)")
  asm_prologue()

  lvar_names = String[]

  for stmt in body
    if stmt[1] == "var"
      lvar_name = stmt[2]
      push!(lvar_names, lvar_name)
      gen_var(fn_arg_names, lvar_names, stmt)
    else
      gen_stmt(fn_arg_names, lvar_names, stmt)
    end
  end

  asm_epilogue()
  println("  ret")
end

function gen_top_stmts(top_stmts)
  for top_stmt in top_stmts[2:end]
    gen_func_def(top_stmt)
  end
end

function gen_builtin_set_vram()
  println("")
  println("label set_vram")
  asm_prologue()
  println("  set_vram [bp:2] [bp:3]") # vram_addr dest
  asm_epilogue()
  println("  ret")
end

function gen_builtin_get_vram()
  println("")
  println("label get_vram")
  asm_prologue()
  println("  get_vram [bp:2] reg_a") # vram_addr dest
  asm_epilogue()
  println("  ret")
end

function codegen(top_stmts)
  println("  call main")
  println("  exit")

  gen_top_stmts(top_stmts)

  println("#>builtins")
  gen_builtin_set_vram()
  gen_builtin_get_vram()
  println("#<builtins")
end

# --------------------------------

ast = json_parse(read_stdin_all())
codegen(ast)
