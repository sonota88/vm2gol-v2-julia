include("lib/utils.jl")
include("lib/json.jl")

function is_ident_char(c)
  ('a' <= c && c <= 'z') ||
  ('0' <= c && c <= '9') ||
  c == '_'
end

function match_ident(str)
  bi = 1 # byte index

  while bi <= lastindex(str)
    if is_ident_char(str[bi])
      bi = nextind(str, bi)
    else
      break
    end
  end

  bi - 1
end

function match_sym(str)
  if str[1:2] in ["==", "!="]
    return 2
  end

  if occursin(str[1], "(){};=,+*")
    1
  else
    0
  end
end

function match_comment(str)
  if str[1:2] != "//"
    return 0
  end

  find_index(str, '\n')
end

function is_kw(str)
  str in [
    "func",
    "set",
    "var",
    "call",
    "call_set",
    "return",
    "while",
    "case",
    "when"
  ]
end

function print_token(lineno, kind, str)
  json_print([lineno, kind, str], false)
  print("\n")
end

function lex()
  src = read_stdin_all()

  bi = 1
  lineno = 1

  while bi <= lastindex(src)
    rest = src[bi:end]

    if rest[1] == '\n'
      bi += 1
      lineno += 1
    elseif rest[1] == ' '
      bi += 1
    elseif 0 < match_sym(rest)
      # byte size
      bsize = match_sym(rest)
      str = rest[1:bsize]
      print_token(lineno, "sym", str)
      bi += bsize
    elseif 0 < match_comment(rest)
      bsize = match_comment(rest)
      str = rest[1:bsize]
      bi += bsize
    elseif 0 < match_int(rest)
      bsize = match_int(rest)
      str = rest[1:bsize]
      print_token(lineno, "int", str)
      bi += bsize
    elseif 0 <= match_str(rest)
      bsize = match_str(rest)
      str = rest[2:prevind(rest, bsize + 2)]
      print_token(lineno, "str", str)
      bi += bsize + 2
    elseif 0 < match_ident(rest)
      bsize = match_ident(rest)
      str = rest[1:bsize]
      if is_kw(str)
        print_token(lineno, "kw", str)
      else
        print_token(lineno, "ident", str)
      end
      bi += bsize
    else
      error("unexpected pattern line($(lineno)) rest($(rest))")
    end
  end
end

# --------------------------------

lex()
