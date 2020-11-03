import 
  packages/nim-sgregex/sgregex,
  std/exitprocs,
  parseopt,
  os,
  terminal,
  strutils,
  times

type
  StringBounds = array[0..1, int]
  StringMatches = object
    start: int
    finish: int
    captures: seq[string]
  FaeOptions = object
    regex: string
    insensitive: bool
    recursive: bool
    filter: string
    substitute: string
    directory: string
    apply: bool
    test: bool
    silent: bool

addExitProc(resetAttributes)

const version = "1.1.0"

const usage = """FAE v""" & version & """ - Find & Edit Utility
  (c) 2015-2020 Fabio Cevasco

  Usage:
    fae <pattern> <replacement> [option1 option2 ...]

  Where:
    <pattern>           A regular expression to search for
    <replacoement>      An optional replacement string
    <flags>             i: case-insensitive match
                        m: multiline match
                        s: treat newlines as spaces

  Options:
    -a, --apply         Substitute all occurrences of <pattern> with <replacement> in all files
                        without asking for confirmation.
    -d, --directory     Search in the specified directory (default: .)
    -f, --filter        Specify a regular expression to filter file paths.
    -h, --help          Display this message.
    -i, --insensitive   Case-insensitive matching.
    -r, --recursive     Search directories recursively.
    -s, --silent        Do not display matches.
    -t, --test          Do not perform substitutions, just print results.
    -v, --version       Display the program version.
"""

proc flags(options: FaeOptions): string = 
  if options.insensitive:
    "i"
  else:
    ""

proc matchBounds(str, expr: string, start = 0, options: FaeOptions): StringBounds = 
  if start > str.len-2:
    return [-1, -1]
  let s = str.substr(start)
  let c = s.search(expr, options.flags)
  if c.len > 0:
    let match = c[0]
    let mstart = s.find(match)
    let mfinish = mstart + match.len
    result = [mstart, mfinish]
  else:
    result = [-1, -1]


#proc old_matchBounds(str, regex: string, start = 0, flags = 0): StringBounds =
#  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
#  var s = str.substr(start).cstring
#  let match = slre_match(("(" & regex & ")").cstring, s, s.len.cint, c, 10, flags.cint)
#  if match >= 0:
#    result = [match-c[0].len+start, match-1+start]
#  else:
#    result = match.handleRegexErrors()

proc matchCaptures(str, expr: string, start = 0, options: FaeOptions): StringMatches =
  let s = str.substr(start)
  let c = s.search(expr, options.flags)
  let match = c.len 
  result = StringMatches(start: match-c[0].len+start, finish: match-1+start, captures: c)

#proc old_matchCaptures(str, regex: string, start = 0, flags = 0): StringMatches = 
#  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
#  var s = str.substr(start).cstring
#  let match = slre_match(("(" & regex & ")").cstring, s, s.len.cint, c, 10, flags.cint)
#  if match >= 0: 
#    result = StringMatches(start: match-c[0].len+start, finish: match-1+start, captures: c)
#  else:
#    result = StringMatches(start: match, finish: match, captures: c)

proc matchBoundsRec(str, regex: string, start = 0, matches: var seq[StringBounds], options: FaeOptions) =
  let match = str.matchBounds(regex, start, options)
  if match[0] >= 0:
    matches.add(match)
    matchBoundsRec(str, regex, match[1]+1, matches, options)

proc match(str, regex: string): bool = 
  str.match(regex)

proc rawReplace(str: var string, sub: string, start, finish: int) =
  str.delete(start, finish)
  str.insert(sub, start)


proc replace(str, regex: string, substitute: var string, start = 0, options: FaeOptions): string =
  return sgregex.replace(str, regex, substitute, options.flags)

#proc old_replace(str, regex: string, substitute: var string, start = 0): string =
#  var newstr = str
#  let match = str.matchCaptures(regex, start)
#  if match.finish >= 0:
#    for i in 1..9:
#      # Substitute captures
#      var submatches = newSeq[StringBounds](0)
#      substitute.matchBoundsRec("\\\\" & $i, 0, submatches)
#      for submatch in submatches:
#        var capture = match.captures[i]
#        if capture.len > 0:
#          substitute.rawReplace(substr(capture, 0, (capture.len-1).int), submatch[0], submatch[1])
#    newstr.rawReplace(substitute, match.start, match.finish)
#  return newstr

proc displayMatch(str: string, start, finish: int, color = fgYellow, lineN: int, silent = false) =
  if silent:
    return
  echo start, " - ", finish, "<<<"
  let max_extra_chars = 20
  let context_start = max(start-max_extra_chars, 0)
  let context_finish = min(finish+max_extra_chars, str.len)
  let match: string = str.substr(start, finish)
  var context: string = str.substr(context_start, context_finish)
  if context_start > 2:
    context = "..." & context
  if context_finish < str.len + 3:
    context = context & "..."
  let match_context_start:int = strutils.find(context, match, start-context_start)
  let match_context_finish:int = match_context_start+match.len
  #let lineN = $str.countLines(0, finish+1)
  stdout.write(" ")
  setForegroundColor(color, true)
  #for i in 0..lineN:
  stdout.write(lineN)
  resetAttributes()
  stdout.write(": ")
  #context = strutils.replace(context, "\n", " ")
  for i in 0 .. (context.len):
    if i == match_context_start:
      setForegroundColor(color, true)
    if i == match_context_finish:
      resetAttributes()
    if i < context.len:
      stdout.write(context[i])
  stdout.write("\n")

proc displayFile(str: string, silent = false) =
  if silent:
    return
  stdout.write "["
  setForegroundColor(fgGreen, true)
  for i in 0..str.len-1:
    stdout.write(str[i])
  resetAttributes()
  stdout.write "]"

proc confirm(msg: string): bool = 
  stdout.write(msg)
  var answer = stdin.readLine()
  if answer.match("y(es)?", "i"):
    return true
  elif answer.match("n(o)?", "i"):
    return false
  else:
    return confirm(msg)

proc processFile(f:string, options: FaeOptions): array[0..1, int] =
  var matchesN = 0
  var subsN = 0
  var contents = ""
  var contentsLen = 0
  var lineN = 0
  var fileLines = newSeq[string]()
  var hasSubstitutions = false
  var file: File
  if not file.open(f):
    raise newException(IOError, "Unable to open file '$1'" % f)
  while file.readline(contents):
    lineN.inc
    contentsLen = contents.len
    fileLines.add contents
    var match = matchBounds(contents, options.regex, 0, options)
    while match[0] >= 0:
      matchesN.inc
      var offset = 0
      var matchstart, matchend: int
      matchstart = match[0] 
      matchend = match[1] 
      if options.substitute != "":
        displayFile(f)
        displayMatch(contents, matchstart, matchend, fgRed, lineN)
        var substitute = options.substitute
        var replacement = contents.replace(options.regex, substitute, matchstart, options)
        offset = substitute.len-(matchend-matchstart+1)
        for i in 0..(f.len+1):
          stdout.write(" ")
        displayMatch(replacement, matchstart, matchend+offset, fgYellow, lineN)
        if (options.apply or confirm("Confirm replacement? [y/n] ")):
          hasSubstitutions = true
          subsN.inc
          contents = replacement
          fileLines[fileLines.high] = replacement
      else:
        displayFile(f, silent = options.silent)
        displayMatch(contents, matchstart, matchend, fgYellow, lineN, silent = options.silent)
      match = matchBounds(contents, options.regex, matchend+offset+1, options)
  file.close()
  if (not options.test) and (options.substitute != "") and hasSubstitutions: 
    f.writefile(fileLines.join("\n"))
  return [matchesN, subsN]

## MAIN

## Processing Options

var duration = cpuTime()

var options = FaeOptions(regex: "", insensitive: false, recursive: false, filter: "", substitute: "", directory: ".", apply: false, test: false, silent: false)

for kind, key, val in getOpt():
  case kind:
    of cmdArgument:
      if options.regex == "":
        options.regex = key
      elif options.substitute == "":
        options.substitute = key
      elif options.regex == "" and options.substitute == "":
        quit("Too many arguments", 1)
    of cmdLongOption, cmdShortOption:
      case key:
        of "recursive", "r":
          options.recursive = true
        of "filter", "f":
          options.filter = val
        of "directory", "d":
          options.directory = val
        of "apply", "a":
          options.apply = true
        of "test", "t":
          options.test = true
        of "help", "h":
          echo usage
          quit(0)
        of "version", "v":
          echo version
          quit(0)
        of "insensitive", "i":
          options.insensitive = true
        of "silent", "s":
          options.silent = true
        else:
          discard
    else:
      discard

if options.regex == "":
  echo usage
  quit(0)

## Processing

var count = 0
var matchesN = 0
var subsN = 0
var res: array[0..1, int]

if options.recursive:
  for f in walkDirRec(options.directory):
    if options.filter == "" or f.match(options.filter):
      try:
        count.inc
        res = processFile(f, options)
        matchesN = matchesN + res[0]
        subsN = subsN + res[1]
      except:
        stderr.writeLine getCurrentExceptionMsg()
        continue
else:
  for kind, f in walkDir(options.directory):
    if kind == pcFile and (options.filter == "" or f.match(options.filter)):
      try:
        count.inc
        res = processFile(f, options)
        matchesN = matchesN + res[0]
        subsN = subsN + res[1]
      except:
        stderr.writeLine getCurrentExceptionMsg()
        continue

if options.substitute != "":
  echo "=== ", count, " files processed - ", matchesN, " matches, ", subsN, " substitutions (", (cpuTime()-duration), " seconds)."
else:
  echo "=== ", count, " files processed - ", matchesN, " matches (", (cpuTime()-duration), " seconds)."
