function print_indent(n)
  i = 0
  while i < n
    print("  ")
    i += 1
  end
end

function json_print_node(val, lv, pretty)
  if pretty
    print_indent(lv)
  end

  if val isa String || val isa SubString
    print('"' * val * '"')
  elseif val isa Int
    print(val)
  elseif val isa Vector
    json_print_list(val, lv, pretty)
  else
    error("type: $(typeof(val))")
  end
end

function json_print_list(list, lv, pretty)
  print("[")
  if pretty
    print("\n")
  end

  i = 0
  for x in list
    json_print_node(x, lv + 1, pretty)

    if i < length(list) - 1
      if pretty
        print(",")
      else
        print(", ")
      end
    end
    if pretty
      print("\n")
    end

    i += 1
  end

  if pretty
    print_indent(lv)
  end
  print("]")
end

function json_print(list, pretty)
  json_print_list(list, 0, pretty)
end

function json_parse_node(rest)
  if 0 < match_int(rest)
    # byte size
    bsize = match_int(rest)
    s = rest[1:bsize]
    n = parse(Int, s)
    [n, bsize]
  elseif 0 <= match_str(rest)
    bsize = match_str(rest)
    s = rest[2:prevind(rest, bsize + 2)]
    [s, bsize + 2]
  elseif rest[1] == '['
    json_parse_list(rest)
  else
    error("unexpected pattern")
  end
end

function json_parse_list(rest)
  list = Any[]
  li = 1

  bi = 2 # byte index
  while bi <= lastindex(rest)
    _rest = rest[bi:end]

    if _rest[1] == ']'
      bi += 1
      break
    elseif _rest[1] == '\n'
      bi += 1
    elseif _rest[1] == ' '
      bi += 1
    elseif _rest[1] == ','
      bi += 1
    else
      val_bi = json_parse_node(_rest)
      push!(list, val_bi[1])
      bi += val_bi[2]
    end
  end

  [list, bi]
end

function json_parse(json)
  list_bi = json_parse_list(json)
  list_bi[1]
end
