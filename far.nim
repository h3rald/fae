import 
  slre,
  parseopt2,
  os,
  terminal,
  strutils

type
  StringBounds = array[0..1, int]
  FarOptions = object
    regex: string
    recursive: bool
    filter: string
    substitute: string
    directory: string

system.addQuitProc(resetAttributes)


proc matchBounds(str, regex: string, start = 0): StringBounds =
  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
  var str = str.substr(start).cstring
  let match = slre_match(("(" & regex & ")").cstring, str, str.len.cint, c, 10, 0)
  if match >= 0:
    result = [match-c[0].len+start, match-1+start]
  else:
    result = [-1, match]

proc matchBoundsRec(str, regex: string, start = 0, matches: var seq[StringBounds]) =
  let match = str.matchBounds(regex, start)
  if match[0] >= 0:
    matches.add(match)
    matchBoundsRec(str, regex, start+match[1]+1, matches)

# Simple replace with no capture support
proc replace(str, regex, substitute: string, start = 0): string =
  let match = str.matchBounds(regex, start)
  var newstr = str
  if match[0] >= 0:
    newstr.delete(match[0], match[1])
    newstr.insert(substitute, match[0])
  return newstr
  

proc match(str, regex: string): bool = 
  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
  return slre_match(regex.cstring, str.cstring, str.len.cint, c, 10, 0) >= 0

proc countLines(s: string, first, last: int): int = 
  var i = first
  while i <= last:
    if s[i] == '\13': 
      inc result
      if i < last and s[i+1] == '\10': inc(i)
    elif s[i] == '\10': 
      inc result
    inc i

proc displayMatch(str: string, start, finish: int, color = fgYellow) =
  let context_start = max(start-10, 0)
  let context_finish = min(finish+10, str.len)
  let match: string = str.substr(start, finish)
  var context: string = str.substr(context_start, context_finish)
  if context_start > 0:
    context = "..." & context
  if context_finish < str.len:
    context = context & "..."
  let match_context_start:int = strutils.find(context, match, start-context_start)
  let match_context_finish:int = match_context_start+match.len
  let line_n = $str.countLines(0, finish+1)
  stdout.write("  ")
  setForegroundColor(color, true)
  for i in 0..line_n.len:
    stdout.write(line_n[i])
  resetAttributes()
  stdout.write(": ")
  context = strutils.replace(context, "\n", " ")
  for i in 0..context.len:
    if i == match_context_start:
      setForegroundColor(color, true)
    if i == match_context_finish:
      resetAttributes()
    stdout.write(context[i])
  stdout.write("\n")

proc displayFile(str: string) =
  stdout.write "["
  setForegroundColor(fgGreen, true)
  for i in 0..str.len:
    stdout.write(str[i])
  resetAttributes()
  stdout.write "]:\n"


## Processing Options

var options = FarOptions(regex: nil, recursive: false, filter: nil, substitute: nil, directory: ".")

for kind, key, val in getOpt():
  case kind:
    of cmdArgument:
      if options.regex == nil:
        options.regex = key
      elif options.substitute == nil:
        options.substitute = key
      elif options.regex == nil and options.substitute == nil:
        quit("Too many arguments", 1)
    of cmdLongOption, cmdShortOption:
      case key:
        of "recursive", "r":
          options.recursive = true
        of "filter", "f":
          options.filter = val
        of "directory", "d":
          options.directory = val
        else:
          discard
    else:
      discard

if options.regex == nil:
  quit("No regex specified.", 2)

var scan: iterator(dir: string): string {.closure.}

if options.recursive:
  scan = iterator (dir: string): string {.closure.}=
    for path in walkDirRec(dir):
      if options.filter == nil or path.match(options.filter):
        yield path
else:
  scan = iterator (dir: string): string {.closure.} =
    for kind, path in walkDir(dir):
      if kind == pcFile and (options.filter == nil or path.match(options.filter)):
        yield path

# test

# test

## MAIN

var contents = ""
var contentsLen = 0
var matches = newSeq[StringBounds](0)
var count = 0


for f in scan(options.directory):
  count.inc
  contents = f.readfile()
  contentsLen = contents.len
  matchBoundsRec(contents, options.regex, 0, matches)
  if matches.len > 0:
    displayFile(f)
    for match in matches:
      if options.substitute != nil:
        displayMatch(contents, match[0], match[1], fgRed)
        displayMatch(contents.replace(options.regex, options.substitute, match[0]), match[0], match[0]+options.substitute.len-1, fgYellow)
      else:
        displayMatch(contents, match[0], match[1])
  matches = newSeq[StringBounds](0)

echo "=== ", count, " files processed."
  

