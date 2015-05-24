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
  let match = slre_match(("(" & regex & ")").cstring, str.cstring, str.len.cint, c, 10, 0)
  if match >= 0:
    result = [match-c[0].len+start, match-1+start]
  else:
    result = [-1, match]

proc matchBoundsRec(str, regex: string, start = 0, matches: var seq[StringBounds]) =
  let match = matchBounds(str, regex, start)
  if match[0] >= 0:
    matches.add(match)
    matchBoundsRec(str, regex, start+match[1]+1, matches)

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

proc displayMatch(str: string, start, finish: int) =
  let context_start = max(start-10, 0)
  let context_finish = min(finish+10, str.len)
  let match: string = str.substr(start, finish)
  var context: string = str.substr(context_start, context_finish)
  if context_start > 0:
    context = "..." & context
  if context_finish < str.len:
    context = context & "..."
  let match_context_start:int = strutils.find(context, match)
  let match_context_finish:int = match_context_start+match.len
  let line_n = $str.countLines(0, finish+1)
  stdout.write("  ")
  setForegroundColor(fgYellow, true)
  for i in 0..line_n.len:
    stdout.write(line_n[i])
  resetAttributes()
  stdout.write(": ")
  context = context.replace("\n", " ")
  for i in 0..context.len:
    if i == match_context_start:
      setForegroundColor(fgYellow, true)
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

### MAIN

var options = FarOptions(regex: nil, recursive: false, filter: nil, substitute: nil, directory: ".")

for kind, key, val in getOpt():
  case kind:
    of cmdArgument:
      options.regex = key
    of cmdLongOption, cmdShortOption:
      case key:
        of "recursive", "r":
          options.recursive = true
        of "filter", "f":
          options.filter = val
        of "substitute", "s":
          options.substitute = val 
        of "directory", "d":
          options.directory = val
        else:
          discard
    else:
      discard

if options.regex == nil:
  quit("No regex specified.", 1)

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
      displayMatch(contents, match[0], match[1])
  matches = newSeq[StringBounds](0)

echo "=== End: ", count, " files processed."
  

