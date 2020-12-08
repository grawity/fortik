﻿# Author: Peter Sovietov

import sys


def parse(tokens):
    code = []
    while tokens:
        word = tokens.pop(0)
        if word.isdigit():
            code.append(("num", int(word)))
        elif word == ":":
            name = tokens.pop(0)
            defined = []
            while tokens[0] != ";":
                defined.append(tokens.pop(0))
            tokens.pop(0)
            code.append((":", (name, parse(defined))))
        elif word == "repeat":
            code.append(("repeat", tokens.pop(0)))
        elif word == "ifelse":
            code.append(("ifelse", (tokens.pop(0), tokens.pop(0))))
        else:
            code.append(("call", word))
    return code


def execute(words, stack, code, pc=0):
    while pc < len(code):
        t, v = code[pc]
        pc += 1
        if t == "num":
            stack.append(v)
        elif t == "call":
            if v in words:
                execute(words, stack, words[v])
            elif v in PRIMS:
                PRIMS[v](words, stack)
            else:
                sys.exit("unknown word: " + v)
        elif t == ":":
            words[v[0]] = v[1]
        elif t == "repeat":
            for _ in range(stack.pop()):
                execute(words, stack, words[v])
        elif t == "ifelse":
            w = v[0] if stack.pop() else v[1]
            execute(words, stack, words[w])


def binop(func):
    def word(words, stack):
        tos = stack.pop()
        stack.append(func(stack.pop(), tos))
    return word


def dup(words, stack):
    stack.append(stack[-1])


def drop(words, stack):
    stack.pop()


def dot(words, stack):
    print(stack.pop())


def emit(words, stack):
    print(chr(stack.pop()), end="")


PRIMS = {
    "+": binop(lambda a, b: a + b),
    "-": binop(lambda a, b: a - b),
    "*": binop(lambda a, b: a * b),
    "/": binop(lambda a, b: a // b),
    "<": binop(lambda a, b: int(a < b)),
    "dup": dup,
    "drop": drop,
    ".": dot,
    "emit": emit
}


def repl():
    words, stack = {}, []
    while True:
        execute(words, stack, parse(input("> ").split()))


source = """
: cr 10 emit ;
: star1 42 emit ;
: star2 10 repeat star1 cr ;
: star 10 repeat star2 ;
star
: fact1 drop 1 ;
: fact2 dup 1 - fact * ;
: fact dup 1 < ifelse fact1 fact2 ;
5 fact .
"""

execute({}, [], parse(source.split()))
repl()
