{.compile: "vendor/libslre.c".}
{.push importc, cdecl.}
const 
  SLRE_HEADER_DEFINED* = true
type 
  Capture* = object 
    str*: cstring
    len*: cint

proc slre_match*(regexp: cstring; buf: cstring; buf_len: cint; 
                 caps: ptr array[0..9, Capture]; num_caps: cint; flags: cint): cint
# Possible flags for slre_match() 
const 
  SLRE_IGNORE_CASE* = 1
# slre_match() failure codes 
const 
  SLRE_NO_MATCH* = - 1
  SLRE_UNEXPECTED_QUANTIFIER* = - 2
  SLRE_UNBALANCED_BRACKETS* = - 3
  SLRE_INTERNAL_ERROR* = - 4
  SLRE_INVALID_CHARACTER_SET* = - 5
  SLRE_INVALID_METACHARACTER* = - 6
  SLRE_CAPS_ARRAY_TOO_SMALL* = - 7
  SLRE_TOO_MANY_BRANCHES* = - 8
  SLRE_TOO_MANY_BRACKETS* = - 9
