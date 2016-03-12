import 
  slre,
  parseopt2,
  os,
  terminal,
  strutils,
  times

type
  StringBounds = array[0..1, int]
  StringMatches = object
    start: int
    finish: int
    captures: ptr array[0..9, Capture]
  FarOptions = object
    regex: string
    recursive: bool
    filter: string
    substitute: string
    directory: string
    apply: bool
    test: bool
    flags: int

system.addQuitProc(resetAttributes)

const version = "1.0.0"

const usage = """FAR v""" & version & """ - Find & Replace Utility
  (c) 2015 Fabio Cevasco

  Usage:
    far <pattern> [<replacement>] [option1 option2 ...]

  Where:
    <pattern>           A regular expression to search for
    <replacement>       An optional replacement string

  Options:
    -a, --apply         Substitute all occurrences of <pattern> with <replacement> in all files
                        without asking for confirmation.
    -d, --directory     Search in the specified directory (default: .)
    -f, --filter        Specify a regular expression to filter file paths.
    -h, --help          Display this message.
    -i, --ignore-case   Case-insensitive matching.
    -r, --recursive     Search directories recursively.
    -t, --test          Do not perform substitutions, just print results.
    -v, --version       Display the program version.
"""

proc handleRegexErrors(match: int, ): StringBounds =
  case match:
    of -2:
      quit("Regex Error: Unexpected quantifier", match)
    of -3:
      quit("Regex Error: Unbalanced brackets", match)
    of -4:
      quit("Regex Error: Internal error", match)
    of -5:
      quit("Regex Error: Invalid character set", match)
    of -6:
      quit("Regex Error: Invalid metacharacter", match)
    of -7:
      quit("Regex Error: Too many captures (max: 9)", match)
    of -8:
      quit("Regex Error: Too many branches", match)
    of -9:
      quit("Regex Error: Too many brackets", match)
    else:
      result = [-1, match]

proc `$`(sb: StringBounds): string =
  return "($1,$2)" % [$sb[0], $sb[1]]

proc matchBounds(str, regex: string, start = 0, flags = 0): StringBounds =
  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
  var s = str.substr(start).cstring
  let match = slre_match(("(" & regex & ")").cstring, s, s.len.cint, c, 10, flags.cint)
  if match >= 0:
    result = [match-c[0].len+start, match-1+start]
  else:
    result = match.handleRegexErrors()

proc matchCaptures(str, regex: string, start = 0, flags = 0): StringMatches = 
  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
  var s = str.substr(start).cstring
  let match = slre_match(("(" & regex & ")").cstring, s, s.len.cint, c, 10, flags.cint)
  if match >= 0: 
    result = StringMatches(start: match-c[0].len+start, finish: match-1+start, captures: c)
  else:
    result = StringMatches(start: match, finish: match, captures: c)

proc matchBoundsRec(str, regex: string, start = 0, matches: var seq[StringBounds], flags = 0) =
  let match = str.matchBounds(regex, start, flags = flags)
  if match[0] >= 0:
    matches.add(match)
    matchBoundsRec(str, regex, match[1]+1, matches, flags = flags)

proc match(str, regex: string, flags = 0): bool = 
  var c  = cast[ptr array[0..9,Capture]](alloc0(sizeof(array[0..9, Capture])))
  return slre_match(regex.cstring, str.cstring, str.len.cint, c, 10, flags.cint) >= 0

proc rawReplace(str: var string, sub: string, start, finish: int) =
  str.delete(start, finish)
  str.insert(sub, start)

proc replace(str, regex: string, substitute: var string, start = 0, flags = 0): string =
  var newstr = str
  let match = str.matchCaptures(regex, start, flags = flags)
  if match.finish >= 0:
    for i in 1..9:
      # Substitute captures
      var submatches = newSeq[StringBounds](0)
      substitute.matchBoundsRec("\\\\" & $i, 0, submatches, flags = flags)
      for submatch in submatches:
        var capture = match.captures[i]
        if capture.len > 0:
          substitute.rawReplace(substr($capture.str, 0, (capture.len-1).int), submatch[0], submatch[1])
    newstr.rawReplace(substitute, match.start, match.finish)
  return newstr

proc displayMatch(str: string, start, finish: int, color = fgYellow, lineN: int) =
  let max_extra_chars = 20
  let context_start = max(start-max_extra_chars, 0)
  let context_finish = min(finish+max_extra_chars, str.len)
  let match: string = str.substr(start, finish)
  var context: string = str.substr(context_start, context_finish)
  if context_start > 0:
    context = "..." & context
  if context_finish < str.len:
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
  stdout.write "]"

proc confirm(msg: string): bool = 
  stdout.write(msg)
  var answer = stdin.readLine()
  if answer.match("y(es)?", 1):
    return true
  elif answer.match("n(o)?", 1):
    return false
  else:
    return confirm(msg)

proc processFile(f:string, options: FarOptions): int =
  var matchesN = 0
  var contents = ""
  var contentsLen = 0
  var lineN = 0
  var fileLines = newSeq[string]()
  var file: File
  if not file.open(f):
    raise newException(IOError, "Unable to open file '$1'" % f)
  while file.readline(contents):
    lineN.inc
    contentsLen = contents.len
    fileLines.add contents
    var matches = newSeq[StringBounds](0)
    matchBoundsRec(contents, options.regex, 0, matches, flags = options.flags)
    if matches.len > 0:
      matchesN = matchesN + matches.len
      var offset = 0
      var matchstart, matchend: int
      for match in matches:
        matchstart = match[0] + offset
        matchend = match[1] + offset
        displayFile(f)
        if options.substitute != nil:
          displayMatch(contents, matchstart, matchend, fgRed, lineN)
          var substitute = options.substitute
          var replacement = contents.replace(options.regex, substitute, matchstart)
          var new_offset = substitute.len-(matchend-matchstart+1)
          for i in 0..(f.len+1):
            stdout.write(" ")
          displayMatch(replacement, matchstart, matchend+new_offset, fgYellow, lineN)
          fileLines[fileLines.high] = replacement
        else:
          displayMatch(contents, match[0], match[1], fgYellow, lineN)
    if (not options.test) and (options.substitute != nil) and (options.apply or confirm("Confirm replacement? [Y/n] ")):
      f.writefile(fileLines.join("\n"))
      #contents = f.readFile()
      #offset = offset + new_offset 
  return matchesN

## MAIN

## Processing Options

var duration = cpuTime()

var options = FarOptions(regex: nil, recursive: false, filter: nil, substitute: nil, directory: ".", apply: false, test: false, flags: 0)

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
        of "ignore-case", "i":
          options.flags = 1
        else:
          discard
    else:
      discard

if options.regex == nil:
  echo usage
  quit(0)

## Processing

var count = 0
var matchesN = 0

if options.recursive:
  for f in walkDirRec(options.directory):
    if options.filter == nil or f.match(options.filter):
      try:
        count.inc
        matchesN = matchesN + processFile(f, options)
      except:
        stderr.writeLine getCurrentExceptionMsg()
        continue
else:
  for kind, f in walkDir(options.directory):
    if kind == pcFile and (options.filter == nil or f.match(options.filter)):
      try:
        count.inc
        matchesN = matchesN + processFile(f, options)
      except:
        stderr.writeLine getCurrentExceptionMsg()
        continue

echo "=== ", count, " files processed - ", matchesN, " matches found (", (cpuTime()-duration), " seconds)."


