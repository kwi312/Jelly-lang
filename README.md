# Jelly

Jelly - dynamic, object oriented language that compiles to lua.

## Overview

The Jelly syntax is lua syntax with some simplifications.
```
if true --no "then" required
  print(true)
end


if (2 < 3)
  print('2 < 3')
end


unless false
  print(true)
end

loop --simple infinite loop

end


for i in 5, -5
  io.write(i) -- will print "543210-1-2-3-4-5"
end


f = ()-> print("hello world") end -- equivalent to "a = function() print("hello world") end"


-- We also have some additions

class Human

  method speak -- brackets are optional if the method receives no arguments
    print('hello world')
  end

end


class Cat

  method meow
    print('meow')
  end

end

--preprocessor conditional compilation
-/if WEEABOO
class Neko | Human, Cat -- multiple inheritance supported
end
-/end

h = Human()
h:speak() -- will print "hello world"

-/if WEEABOO
n = Neko()
n:speak()
n:meow()
-/end
```

