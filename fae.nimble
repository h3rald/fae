import
  strutils

from os import parentDir, `/`

template thisModuleFile: string = instantiationInfo(fullPaths = true).filename

when fileExists(thisModuleFile.parentDir / "src/faepkg/config.nim"):
  # In the git repository the Nimble sources are in a ``src`` directory.
  import src/faepkg/config
else:
  # When the package is installed, the ``src`` directory disappears.
  import faepkg/config

# Package

version       = appVersion
author        = appAuthor
description   = appDescription
license       = appLicense
bin           = @[appName]
srcDir        = "src"
installExt    = @["nim", "c", "h"]

# Dependencies

requires "nim >= 1.4.0", "nifty"

before install:
  exec "nimble install nifty"
  exec "nifty install"

# Build

const
  parallel = "" #"--parallelBuild:1 --verbosity:3"
  compile = "nim c -d:release --opt:size" & " " & parallel
  linux_x64 = "--cpu:amd64 --os:linux --passL:-static"
  windows_x64 = "--cpu:amd64 --os:windows"
  macosx_x64 = ""
  app = "src/fae"
  app_file = "src/fae.nim"
  zip = "zip -X -j"

proc shell(command, args = "", dest = "") =
  exec command & " " & args & " " & dest

proc filename_for(os: string, arch: string): string =
  return appName & "_v" & version & "_" & os & "_" & arch & ".zip"

task windows_x64_build, "Build " & appName & " for Windows (x64)":
  shell compile, windows_x64, app_file

task linux_x64_build, "Build " & appName & " for Linux (x64)":
  shell compile, linux_x64,  app_file

task macosx_x64_build, "Build " & appName & " for Mac OS X (x64)":
  shell compile, macosx_x64, app_file

task release, "Release " & appName:
  echo "\n\n\n WINDOWS - x64:\n\n"
  windows_x64_buildTask()
  shell zip, "$1 $2" % [filename_for("windows", "x64"), app & ".exe"]
  shell "rm", app & ".exe"
  echo "\n\n\n LINUX - x64:\n\n"
  linux_x64_buildTask()
  shell zip, "$1 $2" % [filename_for("linux", "x64"), app]
  shell "rm", app 
  echo "\n\n\n MAC OS X - x64:\n\n"
  macosx_x64_buildTask()
  shell zip, "$1 $2" % [filename_for("macosx", "x64"), app]
  shell "rm", app
  echo "\n\n\n ALL DONE!"
