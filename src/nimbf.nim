## :Author: Jerom van der Sar
##
## Reconstructed from scratch from https://howistart.org/posts/nim/1
## Thanks to: Denis Felsing
##
## This module implements an interpreter for the brainfuck programming language
## as well as a compiler that translates brainfuck into efficient Nim code.
##
## Example:
##
## .. code:: nim
##   import brainfuck, streams
##
##   # Prints "Hello World!"
##   interpret("++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.")
##
##   # Draws a mandelbrot set
##   proc mandelbrot = compileFile("examples/mandelbrot.b")
##   mandelbrot()
##

import streams
import macros # metaprogramming

# Some procedures for raw incrementing and decrementing without causing overflows
{.push overflowchecks: off.}
proc xinc*(c: var char) = inc c
proc xdec*(c: var char) = dec c
{.pop.}

proc readCharEOF*(input: Stream): char =
    result = input.readChar
    if result == '\0': # Streams return 0 for EOF
        result = '\255' # BF assumes EOF to be -1

proc interpret*(code: string; input, output: Stream) =
    ## Interpret the brainfuck `code` string, reading from `input` and writing to `output`
    ##
    ## Example:
    ##
    ## .. code:: nim
    ##   var ips = newStringStream("Hello, world!\n")
    ##   var ops = newFileStream(stdout)
    ##   interpret(readFile("examples/rot13"), ips, ops)
    ##
    
    var
        tape = newSeq[char]()
        codePos = 0
        tapePos = 0
      
    proc run(skip = false): bool =
        #echo "codePos: ", codePos, " tapePos: ", tapePos
        while tapePos >= 0 and codePos < code.len:
            if tapePos >= tape.len:
                tape.add '\0'
          
            if code[codePos] == '[':
                inc codePos
                let oldPos = codePos
                while run(tape[tapePos] == '\0'):
                    codePos = oldPos
            elif code[codePos] == ']':
                return tape[tapePos] != '\0'
            elif not skip:
                case code[codePos]
                of '+': xinc tape[tapePos]
                of '-': xdec tape[tapePos]
                of '>': inc tapePos
                of '<': dec tapePos
                of '.': output.write tape[tapePos]
                of ',': tape[tapePos] = input.readCharEOF
                else: discard

            inc codePos
      
    discard run()

proc interpret*(code, input: string): string =
    ## Interprets the brainfuck `code` string, reading from `inpu` and returning
    ## the result directly.

    var ops = newStringStream()
    interpret(code, input.newStringStream, ops)
    result = ops.data
 
proc interpret*(code: string) =
    ## Interprets the brainfuck `code` string, reading from stdin and writing to
    ## stdout.
    ##
    ## Example:
    ##
    ## .. code:: nim
    ##   interpret(readFile("examples/rot13.b"))
    ##
    interpret(code, stdin.newFileStream, stdout.newFileStream)
 
proc compile*(code, input, output: string): NimNode {.compiletime.} =
    var stmts = @[newStmtList()]

    template addStmt(text): stmt =
        stmts[stmts.high].add parseStmt(text)

    addStmt """
        when not compiles(newStringStream()):
            static:
                quit("Error: Import the streams module to compile brainfuck code", 1)
    """

    addStmt "var tape: array[1_000_000, char]"
    addStmt "var ips = " & input
    addStmt "var ops = " & output
    addStmt "var tapePos = 0"

    for c in code:
        case c
        of '+': addStmt "xinc tape[tapePos]"
        of '-': addStmt "xdec tape[tapePos]"
        of '>': addStmt "inc tapePos"
        of '<': addStmt "dec tapePos"
        of '.': addStmt "ops.write tape[tapePos]"
        of ',': addStmt "tape[tapePos] = ips.readCharEOF"
        of '[': stmts.add newStmtList()
        of ']':
            var loop = newNimNode(nnkWhileStmt)
            loop.add parseExpr("tape[tapePos] != '\\0'")
            loop.add stmts.pop
            stmts[stmts.high].add loop
        else: discard

    result = stmts[0]
    #echo result.repr

macro compileString*(code: string; input, output: expr): stmt =
    result = compile(
      $code,
      "newStringStream(" & $input & ")",
      "newStringStream()")
    result.add parseStmt($output & " =  ops.data")

macro compileString*(code: string): stmt =
    ## Compiles the brainfuck `code` string into Nim code that reads from stdin
    ## and writes to stdout.
    compile(
      $code,
      "stdin.newFileStream",
      "stdout.newFileStream")

macro compileFile*(filename: string; input, output: expr): stmt =
    ## Compiles the brainfuck code read from `filename` at compile time into Nim
    ## code that reads from stdin and writes to stdout.
    result = compile(
      staticRead(filename.strval),
      "newStringStream(" & $input & ")",
      "newStringStream()")
    result.add parseStmt($output & " = ops.data")

      
macro compileFile*(filename: string): stmt =
    ## Compiles the brainfuck code read from `filename` at compile time into Nim
    ## code that reads from stdin and writes to stdout.
    compile(staticRead(filename.strval),
      "stdin.newFileStream", "stdout.newFileStream")

when isMainModule:
    import docopt, tables, strutils

    proc mandelbrot = compileFile("../examples/mandelbrot.b")
    
    let doc = """
brainfuck

Usage:
  brainfuck mandelbrot
  brainfuck interpret [<file.b>]
  brainfuck (-h | --help)
  brainfuck (-v | --version)
  
Options:
  -h, --help     Shows this screen.
  -v, --version  Shows the version.
"""

    let args = docopt(doc, version = "brainfuck 1.0")
    
    if args["mandelbrot"]:
        mandelbrot()
      
    elif args["interpret"]:
        let code = if args["<file.b>"]: readFile($args["file.b"])
                   else: readAll stdin
      
        interpret(code)
