import unittest, nimbf

suite "brainf*** interpreter":
    test "interpret rot13":
        let rot13 = readFile("examples/rot13.b")
        let conv = interpret(rot13, "How I Start\n")
        check conv == "Ubj V Fgneg\n"
        check interpret(rot13, conv) == "How I Start\n"
