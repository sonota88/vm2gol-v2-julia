function read_stdin_all()
  text = ""

  for line in readlines()
    text *= line
    text *= "\n"
  end

  text
end

function find_index(xs, x)
  for i = firstindex(xs):lastindex(xs)
    try
      if xs[i] == x
        return i
      end
      i += 1
    catch
      # ignore
    end
  end

  0
end

function is_digit(c)
  '0' <= c && c <= '9'
end

function match_int(rest)
  bi = 1

  if rest[1] == '-'
    bi = 2
  end

  while bi <= lastindex(rest)
    c = rest[bi]
    if is_digit(c)
      bi += 1
    else
      break
    end
  end

  bi - 1
end

function match_str(str)
  if str[1] != '"'
    return -1
  end
  
  find_index(str[2:end], '"') - 1
end
