# Jelly

![Jelly logo](./logo.svg)
Jelly - dynamic, object oriented language based on lua.

## Differences from lua

* New operators `+= -= *= ^= /=`
* New `unless` and `try` statements (not implemented)
* Different syntax for declaring loops, statements and functions
* Classes with multiple inheritance
* C-like preprocessor

## Syntax

Jelly syntax is similar to lua syntax, but with some differences.

### if/unless statements

```
if (condition)
    --code
end

unless (!condition)
    --code
end
```

or simpler

```
if variable
    --code
end

unless variable
    --code
end
```

### Loops

```
while (condition)
    --code
end

for i in 1, 5
    --code
end

loop --simplest infinite loop
    --code
end
```

### Classes

```
class Human
    method init(name)
        self.name = name
        return self
    end

    method say(text)
        local str = "{self.name} - {text}"
        print(str)
    end
end

class Cat
    method meow
        print('meow')
    end
end

class Neko | Human, Cat

end
```

Instance creation:

```
--There is no special 'constructor method' in jelly, you can use any method as a constructor and have multiple constructors in the same class
local tom = Human():init('Tom')
tom:say('hello world')

local cat = Cat()
cat:meow()

local neko = Neko():init('Yui') --init method from Human class
neko:meow()
neko:say('hello world')
```

### Functions

```
f -> () --define function 'f'

end

()-> --define unnamed function

end
```
