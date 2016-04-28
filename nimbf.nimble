# Package

version       = "0.1.0"
author        = "Jerom van der Sar"
description   = "A brainf*** interpreter"
license       = "MIT"

srcDir        = "src"
bin           = @["nimbf"]

# Dependencies

requires "nim >= 0.13.0"
requires "docopt >= 0.6.2"

task test, "Test language":
    exec "nim c -r tests/all"