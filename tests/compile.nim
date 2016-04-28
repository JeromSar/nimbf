import unittest, nimbf, streams

suite "brainf*** compiler":
    test "compile rot13":
        proc rot13(input: string): string = 
            compileFile("../examples/rot13.b", input, result)
        let conv = rot13("How I Start\n")
        check conv == "Ubj V Fgneg\n"
        check rot13(conv) == "How I Start\n"
        check rot13(conv) == "How I Start\n"