local _JVERSION = "0.3.0"
local jelly_keywords = {'end','if','unless','elseif','else','local','while','loop','for','function','method','class','until','repeat','in','try','catch','do','true','false'}
local function parseArgs(args)
	local skipNext = false
	for i,v in ipairs(arg) do
		if skipNext then
			skipNext = false
			goto skipArg
		end
		if args[v] ~= nil then
			if type(args[v]) == "boolean" then
				args[v] = true
			elseif type(args[v]) == "string" then
				args[v] = arg[i+1] or ''
				skipNext = true
			elseif type(args[v]) == "table" and arg[i+1] then
				table.insert(args[v], arg[i+1])
				skipNext = true
			end
		else
			table.insert(args, v)
		end
		::skipArg::
	end
	return args
end
local verboseOutput = false
local function log(...)
	local str = {}
	for i,v in ipairs({...}) do
		table.insert(str, tostring(v))
	end
	table.insert(str, 1, ':' .. tostring(os.clock()) .. ':>')
	print(table.concat(str, ' '))
end
local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end
local function readFile(path)
	log("reading file", path)
	local f = io.open(path, "r")
	if not f then error("cannot open file: " .. tostring(path)) end
	local data = f:read("*a")
	f:close()
	return data
end
local function preprocess(code, defs)
	local lines = split(code, '\n')
	local ret = {}
	local function push(line)
		table.insert(ret, line)
	end
	local skip = false
	for i,v in ipairs(lines) do
		--log(i, skip)
		if string.sub(v, 1, 2) == '-/' then
			local act = string.match(v, "%-/(%w+)")
			local args = string.match(v, '%-/'..act..'%s*([%w%s%p]*)') or ''
			--log(act)
			if act == 'include' then
				push(preprocess(readFile(args), defs))
			elseif act == 'require' then
				push(string.format('local %s = require \'%s\'', args, args))
			elseif act == 'if' then
				skip = true
				for a, vl in ipairs(defs) do
					if args == vl then skip = false; break end
				end
			elseif act == 'ifnot' then
				for a, vl in ipairs(defs) do
					if args == vl then log(vl, args, vl == args); skip = true; break end
				end
			elseif act == 'end' then
			skip = false
			else
				error('unknown preprocessor keyword ' .. tostring(act))
			end
		else
			if skip then goto prepskip end
			push(v)
		end
		::prepskip::
	end
	return table.concat(ret, '\n')
end
local function lex(code)
	local tokens = {}
	local offset = 0
	local function getchar()
		offset = offset + 1
		return string.sub(code, offset, offset)
	end
	local function peekchar()
		return string.sub(code, offset+1, offset+1)
	end
	local current = {}
	local function push(char)
		table.insert(current, char)
	end
	local function pushtok(tokname)
		table.insert(tokens, {data = table.concat(current), type = tokname})
		current = {}
	end
	local function checkw()
		if #current < 1 then return end
		local key = false
		local wrd = table.concat(current)
		if tonumber(wrd) then pushtok('number'); return end
		for i,v in ipairs(jelly_keywords) do
			if wrd == v then key = true; break end
		end
		if key then pushtok('key')
		else pushtok('word')
		end
	end
	local len = string.len(code)
	while offset < len or(#current > 0) do
		local c = getchar()
		if c == string.match(c, '([%a%d_])') then
			push(c)
		elseif c == string.match(c, '(%s)') then
			checkw()
			if c == '\n' then pushtok('newline') end
		elseif c == '(' then
			checkw()
			push('(')
			pushtok('open_bracket')
		elseif c == ')' then
			checkw()
			push(')')
			pushtok('close_bracket')
		elseif c == '<' or c == '>' then
			checkw()
			push(c)
			pushtok('moreless')
		elseif c == '\'' then
			checkw()
			local str = {}
			local specc = false
			push('\'')
			repeat
				c = getchar()
				push(c)
				if c == '\\' then
					specc = not specc
				else
					specc = false
				end
			until c == '\'' and not specc
			pushtok('simple_string')
		elseif c == '\"' then
			checkw()
			local str = {}
			local specc = false
			push('\"')
			repeat
				::sp::
				c = getchar()
				push(c)
				if c == '\\' then
					specc = not specc
				elseif specc then
					specc = false
					goto sp
				end
				--log('str:', c, specc)
			until c == '\"' and not specc
			pushtok('format_string')
		elseif c == '[' then
			checkw()
			push(c)
			push('open_square')
		elseif c == ']' then
			checkw()
			push(c)
			push('close_square')
		elseif c == '-' or c == '+' or c == '/' or c == '*' or c == '^' or c == '%' then
			checkw()
			push(c)
			pushtok('mathsig')
		elseif c == '=' then
			checkw()
			push(c)
			pushtok('eq')
		elseif c == '.' then
			checkw()
			push(c)
			pushtok('point')
		else
			checkw()
			push(c)
			pushtok('etc')
		end
	end
	return tokens
end
local function lexOperators(tokens)
	local offset = 0
	local rettok = {}
	local function get()
		offset = offset + 1
		return tokens[offset]
	end
	local function peek()
		return tokens[offset+1]
	end
	local function last()
		return rettok[#rettok]
	end
	local function replace(tok)
		table.remove(rettok)
		table.insert(rettok, tok)
	end
	local function push(tok)
		table.insert(rettok, tok)
	end
	local function move(n)
		offset = offset + (n or 1)
	end
	local linen = 1
	local function lexerErr(text)
		local cd = {}
		for o = offset-5, offset + 5 do
			table.insert(cd, ((tokens[o] or {}).data or ''))
		end
		print(string.format('lexer error:\n\tline: %s\n\treason: %s\n\tcode: %s', linen, text, table.concat(cd, ' ')))
		os.exit()
	end
	local len = #tokens
	while offset < len do
		local t = get()
		if t.type == 'point' then
			local prev = last()
			local nxt = peek()
			if prev.type == 'number' and nxt.type == 'number' then
				replace({type='number', data = prev.data .. t.data .. nxt.data})
				move()
			elseif prev.type == 'number' and nxt.type ~= 'number' then
				lexerErr('cannot index number')
			else 
				push(t)
			end
		elseif t.type == 'newline' then
			linen = linen + 1
			push(t)
		elseif t.type == 'moreless' then
			if peek().data == '=' then
				push{type='moreless', data=t.data .. '='}
				move()
			else
				push(t)
			end
		elseif t.data == '=' and peek().data == '=' then
			move()
			push{type='ceq', data='=='}
		elseif t.type == 'mathsig' then
			if t.data == '-' and peek().data == '>' then
				push({type='arrowoperator', data=''})
				move()
			elseif peek().data == '=' then
				push({type='modificationoperator', data=t.data})
				move()
			else
				push(t)
			end
		else
			push(t)
		end
	end
	return rettok
end
local function lexExpressions(tokens)
	local rettok = {}
	local offset = 0
	local linen = 1
	local function get()
		offset = offset + 1
		return tokens[offset]
	end
	local function peek()
		return tokens[offset+1]
	end
	local function last()
		return rettok[#rettok]
	end
	local function remove()
		return table.remove(rettok)
	end
	local function replace(tok)
		table.remove(rettok)
		table.insert(rettok, tok)
	end
	local function push(tok)
		table.insert(rettok, tok)
	end
	local function move(n)
		offset = offset + (n or 1)
	end
		local function lexerErr(text)
		local cd = {}
		for o = offset-5, offset + 5 do
			table.insert(cd, ((tokens[o] or {}).data or ''))
		end
		print(string.format('lexer error:\n\tline: %s\n\treason: %s\n\tcode: %s', linen, text, table.concat(cd, ' ')))
		os.exit()
	end
	local len = #tokens
	while offset < len do
		local t = get()
		if t.type == 'open_bracket' then
			local level = 1
			local exp = {'('}
			repeat
				local c = get()
				table.insert(exp, c.data)
				if c.type == 'open_bracket' then
					level = level + 1
				elseif c.type == 'close_bracket' then
					level = level - 1
				end
			until level <= 0
			push{type='bracket_expression', data = exp}
		elseif last() and last().type == 'bracket_expression' and t.type == 'arrowoperator' then
			local bracket = remove()
			push{type='key', data='function'}
			push(bracket)
		elseif t.type == 'newline' then
			linen = linen + 1
		elseif t.type == 'modificationoperator' then
			local toMod = last()
			push{type='etc', data='='}
			push(toMod)
			push{type='mathsig', data=t.data}
		elseif t.type == 'format_string' then
			log('formatting string:', t.data)
			local str = {}
			local args = {}
			local cur = {}
			local lvl = 0
			for c = 1, string.len(t.data) do
				local cc = string.sub(t.data, c, c)
				if cc == '{' then
					if lvl == 0 then
						lvl = lvl + 1
						table.insert(str, "%s")
						goto skip
					end
					lvl = lvl + 1
				elseif cc == '}' then
					lvl = lvl - 1
					if lvl == 0 then
						table.insert(args, table.concat(cur))
						cur = {}
						goto skip
					end
				end
				if lvl == 0 then
					table.insert(str, cc)
				elseif lvl > 0 then
					table.insert(cur, cc)
				elseif lvl < 0 then
					lexerErr('format error')
				end
				::skip::
			end
			push{type='string', data = string.format('string.format(%s,%s)', table.concat(str), table.concat(args, ','))}
		elseif t.type == 'simple_string' then
			push{type='stirng', data = t.data}
		elseif t.type == 'point' then
			replace({type = 'word', data = last().data..t.data..get().data})
		else
			push(t)
		end
	end
	return rettok
end
local function parseExpressions(tokens)
	local offset = 0
	local rettok = {}
	local function get()
		offset = offset + 1
		return tokens[offset]
	end
	local function peek()
		return tokens[offset+1]
	end
	local function last()
		return rettok[#rettok]
	end
	local function replace(tok)
		table.remove(rettok)
		table.insert(rettok, tok)
	end
	local function push(tok)
		table.insert(rettok, tok)
	end
	local linen = 1
	local function parserErr(text)
		local cd = {}
		for o = offset-5, offset + 5 do
			table.insert(cd, ((tokens[o] or {}).data or ''))
		end
		print(string.format('parser error:\n\tline: %s\n\treason: %s\n\tcode: %s', linen, text, table.concat(cd, ' ')))
		os.exit()
	end
	local function move(n)
		offset = offset + (n or 1)
	end
	local len = #tokens
	while offset < len do
		local t = get()
		--log(offset, t.type, t.data)
		if t.type == 'key' then
			if t.data == 'class' then
				local name = get()
				if name.type ~= 'word' then parserErr('unexpected token in class declaration:' .. tostring(t.type) .. '/' .. tostring(t.data)) end
				local useSuper = peek()
				local sups = {}
				if useSuper.data == '|' then 
					local sup = {data=''}
					repeat
						useSuper = get()
						sup = get()
						table.insert(sups, sup.data)
						useSuper = peek()
					until useSuper.data ~= ','
					log(name.data, 'have', #sups, 'superclasses')
				end
				push{type='class_declaration', data={name=name.data, super=sups}}
			elseif t.data == 'function' then
				if peek().type == 'word' then
					local name = get()
					local args = get()
					if args.type ~= 'bracket_expression' then parserErr('unexpected token in function declaration:' .. args.type) end
					push{type='function_declaration', data={name=name.data, args=args}}
				elseif  peek().type == 'bracket_expression' then
					local args = get()
					push{type='function_declaration', data={args=args}}
				else
					parserErr('unexpected token in function declaration:' .. peek().type)
				end
			elseif t.data == 'method' then
				local name = get()
				if name.type ~= 'word' then parserErr('unexpected token in method declaration:' .. name.type) end
				local args = peek()
				if args.type == 'bracket_expression' then
					args = get()
				else
					args = {'(', ')'}
				end
				push{type='method_declaration', data={name=name.data, args=args}}
			elseif t.data == 'end' then
				push{type='close_scope', data='end'}
			elseif t.data == 'if' or t.data == 'unless' then
				local exp = get()
				if exp.type == 'word' or exp.type == 'key' or exp.type == 'bracket_expression' then
					push{type=t.data..'_declaration', data={exp=exp.data}}
				else
					parserErr('unexpected token in '..t.data..' declaration:' .. tostring(exp.type))
				end
			elseif t.data == 'while' then
				if peek().type == 'word' or peek().type == 'key' then
					push{type='while_declaration', data={exp={get().data}}}
				elseif peek().type == 'bracket_expression' then
					push{type='while_declaration', data={exp=get().data}}
				else
					parserErr('unexpected token in while declaration:' .. peek().type)
				end
			elseif t.data == 'loop' then
				push{type='loop_declaration', data={}}
			elseif t.data == 'for' then
				local vars = {}
				local var = {data=''}
				repeat
					var = get()
					table.insert(vars, var.data)
				until peek().data ~= ','
				local insep = get()
				if insep.data ~= 'in' then
					parserErr('syntax error near for:'.. insep.data)
				end
				if peek().type == 'number' then
					local from = get()
					if from.data == '-' then from.data = from.data .. get().data end
					local sep = get()
					local to = get()
					if to.data == '-' then to.data = to.data .. get().data end
					local step = {data='1'}
					if peek().data == ',' then
						local sep2 = get()
						step = get()
						if step.data =='-' then
							if step.data == '-' then step.data = step.data .. get().data end
						end
					elseif tonumber(from.data) > tonumber(to.data) then
						step = {data='-1'}
					end
					push{type='for_declaration', data={type='numeric', vars=vars, exp ={from.data, to.data, step.data}}}
				elseif peek().type == 'word' or peek().type == 'key' then
					local fname = get()
					local fargs = get()
					push{type='iterator', data={exp={fname.data, fargs.data}}}
				else
					parserErr('unexpected token in for declaration:'.. peek().type)
				end
			elseif t.type == 'newline' then
				linen = linen + 1
			else
				push(t)
			end
		else
			push(t)
		end
	end
	return rettok
end
local function compile(tokens)
	local code = {}
	local scopes = {}
	local function push(cd)
		table.insert(code, cd)
	end
	local compilers = {
		class_declaration = {
			new = function(context)
			push(context.name)
			push('=')
			push('{')
			push('class')
			push('=')
			push('\''..context.name..'\'')
			push(',')
			push('__CSUPER')
			push('=')
			push('{')
			push('}')
			push('}')
			push(string.format('do local __superclass={%s} for __super=#__superclass,1,-1 do for name,method in pairs(__superclass[__super]) do %s.__CSUPER[name]=method end end end', table.concat(context.super, ','),context.name))
			end,
			close = function(context)
			push('setmetatable')
			push('(')
			push(context.name)
			push(',')
			push('{')
			push('__index')
			push('=')
			push(context.name .. '.__CSUPER')
			push(',')
			push('__call')
			push('=')
			push('function')
			push('(')
			push(')')
			push('local')
			push('obj')
			push('=')
			push('{')
			push('}')
			push('setmetatable')
			push('(')
			push('obj')
			push(',')
			push('{')
			push('__index')
			push('=')
			push(context.name)
			push(',')
			push('__name')
			push('=')
			push('\''..context.name..'\'')
			push('}')
			push(')')
			push('return')
			push('obj')
			push('end')
			push('}')
			push(')')
			end
		},
		method_declaration = {
			new = function(context)
				push('function')
				push(scopes[2].data.name .. ':' .. context.name)
				log('method', context.name, context.args, (context.args.data or {})[1])
				push(table.concat((context.args.data or {'(', ')'}), ' '))
			end,
			close = function(context)
			push('end')
			end
		},
		if_declaration = {
			new = function(context)
			push('if')
			if type(context.exp) == 'table' then
				push(table.concat(context.exp, ' '))
			else
				push(context.exp)
			end
			push('then')
			end,
			close = function(context)
			push('end')
			end
		},
		unless_declaration = {
			new = function(context)
			push('if')
			push('not')
			if type(context.exp) == 'table' then
				push(table.concat(context.exp, ' '))
			else
				push(context.exp)
			end
			push('then')
			end,
			close = function(context)
			push('end')
			end
		},
		while_declaration = {
			new = function(context)
			push('while')
			if type(context.exp) == 'table' then
				push(table.concat(context.exp, ' '))
			else
				push(context.exp)
			end
			push('do')
			end,
			close = function(context)
			push('end')
			end
		},
		loop_declaration = {
			new = function(context)
			push('while')
			push('true')
			push('do')
			end,
			close = function(context)
			push('end')
			end
		},
		function_declaration = {
			new = function(context)
				push('function')
				if context.name then
					push(context.name)
				end
				push(table.concat(context.args.data, ' '))
			end,
			close = function()
				push('end')
			end
		},
		for_declaration = {
			new = function(context)
				push('for')
				if context.type == 'numeric' then
					push(table.concat(context.vars))
					push('=')
					push(table.concat(context.exp, ','))
					push('do')
				elseif context.type == 'iterator' then

				end
			end,
			close = function()
				push('end')
			end
		},

	}	
	local single_compilers = {
		bracket_expression = function(context)
		push(table.concat(context, ' '))
		end,
		delegate_expression = function(context)
			push(scopes[1].data.name..'.'..context.name)
			push('=')
			push(context.delegate)
		end
	}
	local function newScope(scope)
		table.insert(scopes, 1, scope)
	end
	local function closeScope()
		return table.remove(scopes, 1)
	end
	for ti, token in ipairs(tokens) do
		if compilers[token.type] then
			newScope(token)
			compilers[token.type].new(token.data)
		elseif single_compilers[token.type] then
			single_compilers[token.type](token.data)
		elseif token.type=='close_scope' then
			local toClose = closeScope()
			compilers[toClose.type].close(toClose.data)
		else
			push(token.data)
		end
	end
	return code
end
local function writeFile(path, codeT)
	local code = table.concat(codeT, ' ')
	local f = io.open(path, 'w')
	f:write(code)
	f:close()
end
local function jmain()
	local args = parseArgs({
		['-v'] = false,
		['-vo'] = false,
		['-h'] = false,
		['-d'] = {},
		['-o'] = 'jly.out'
	})
	if args['-v'] then
		print(_JVERSION)
		os.exit()
	end
	if args['-h'] then
		print('options:')
		print('\t-h - show help')
		print('\t-v - show version')
		print('\t-vo - verbose output')
		print('\t-o - set output filename (default:jly.out)')
		print('\t-d - define preprocessor variable')
		print('')
		os.exit()
	end
	if args['-vo'] then
		log('verbose')
		verboseOutput = true
	end
	local inputFiles = ''
	for i,v in ipairs(args) do
		inputFiles = inputFiles .. readFile(v)
	end
	local preprocessed = preprocess(inputFiles, args['-d'])
	local lexed = lex(preprocessed)
	lexed = lexOperators(lexed)
	lexed = lexExpressions(lexed)
	local parsed = parseExpressions(lexed)
	local compiled = compile(parsed)
	writeFile(args['-o'], compiled)
end
jmain()
