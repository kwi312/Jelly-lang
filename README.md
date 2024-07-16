# Jelly

Jelly is a Lua dialect that provides OOP support and some syntax improvements.

## Syntax

### Classes

```
class SomeClass
  method someMethod --brackets are optional if the function accepts no arguments
    print('hello world')
  end
end

class AnotherClass | SomeClass
  method printText(text)
    print(text)
  end
end

local instance = AnotherClass() --just call it to create instance
instance:someMethod()
```

### strings
```
local simpleString = 'here is simple string'
local interpolated = "pi is {math.pi}" -- interpolated string
```

### loops

```
loop --simple infinite loop
  print(os.clock())
end

while true --another infinite loop

end

for i in 5, 0 --decreacing i
  io.write(i) --> 543210
end
```
