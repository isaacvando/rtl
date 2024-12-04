module [parse, Node]

Node : [
    Text Str,
    Interpolation Str,
    RawInterpolation Str,
    ModuleImport Str,
    Conditional { condition : Str, trueBranch : List Node, falseBranch : List Node },
    Sequence { item : Str, list : Str, body : List Node },
    WhenIs { expression : Str, cases : List { pattern : Str, branch : List Node } },
]

parse : Str -> List Node
parse = \input ->
    when Str.toUtf8 input |> (many node) is
        Match { input: [], val } -> combineTextNodes val
        Match _ -> crash "There is a bug! Not all input was consumed."
        NoMatch -> crash "There is a bug! The parser didn't match."

combineTextNodes : List Node -> List Node
combineTextNodes = \nodes ->
    List.walk nodes [] \state, elem ->
        when (state, elem) is
            ([.. as rest, Text t1], Text t2) ->
                List.append rest (Text (Str.concat t1 t2))

            (_, Conditional { condition, trueBranch, falseBranch }) ->
                List.append state (Conditional { condition, trueBranch: combineTextNodes trueBranch, falseBranch: combineTextNodes falseBranch })

            (_, Sequence { item, list, body }) ->
                List.append state (Sequence { item, list, body: combineTextNodes body })

            (_, WhenIs { expression, cases }) ->
                combined = WhenIs {
                    expression,
                    cases: List.map cases \{ pattern, branch } ->
                        { pattern, branch: combineTextNodes branch },
                }
                List.append state combined

            _ -> List.append state elem

# Parsers

Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]

node =
    oneOf [
        text Bool.false,
        rawInterpolation,
        interpolation,
        importModule,
        sequence,
        whenIs,
        conditional,
        text Bool.true,
    ]

interpolation : Parser Node
interpolation =
    manyUntil horizontalByte (string "}}")
    |> startWith (string "{{")
    |> map \(bytes, _) ->
        bytes
        |> unsafeFromUtf8
        |> Str.trim
        |> Interpolation

importModule : Parser Node
importModule =
    manyUntil horizontalByte (string "|}")
    |> startWith (string "{|import")
    |> map \(bytes, _) ->
        bytes
        |> unsafeFromUtf8
        |> Str.trim
        |> ModuleImport

rawInterpolation : Parser Node
rawInterpolation =
    manyUntil horizontalByte (string "}}}")
    |> startWith (string "{{{")
    |> map \(bytes, _) ->
        bytes
        |> unsafeFromUtf8
        |> Str.trim
        |> RawInterpolation

whenIs : Parser Node
whenIs =
    manyUntil horizontalByte (string " |}" |> endWith whitespace)
    |> startWith (string "{|when ")
    |> andThen \(expression, _) ->

        case =
            manyUntil horizontalByte (string " |}")
            |> startWith (string "{|is ")
            |> andThen \(pattern, _) ->

                manyBefore node (oneOf [string "{|is ", string "{|endwhen|}"])
                |> map \branch ->

                    { pattern: unsafeFromUtf8 pattern, branch }

        manyUntil case (string "{|endwhen|}")
        |> map \(cases, _) ->

            WhenIs {
                expression: unsafeFromUtf8 expression,
                cases,
            }

sequence : Parser Node
sequence =
    manyUntil horizontalByte (string " : ")
    |> startWith (string "{|list ")
    |> andThen \(item, _) ->

        manyUntil horizontalByte (string " |}")
        |> andThen \(list, _) ->

            manyUntil node (string "{|endlist|}")
            |> map \(body, _) ->

                Sequence {
                    item: unsafeFromUtf8 item,
                    list: unsafeFromUtf8 list,
                    body: body,
                }

conditional =
    manyUntil horizontalByte (string " |}")
    |> startWith (string "{|if ")
    |> andThen \(condition, _) ->

        manyUntil node (oneOf [string "{|endif|}", string "{|else|}"])
        |> andThen \(trueBranch, separator) ->

            parseFalseBranch =
                if separator == "{|endif|}" then
                    \input -> Match { input, val: [] }
                else
                    manyUntil node (string "{|endif|}")
                    |> map .0

            parseFalseBranch
            |> map \falseBranch ->

                Conditional {
                    condition: unsafeFromUtf8 condition,
                    trueBranch,
                    falseBranch,
                }

text : Bool -> Parser Node
text = \allowTags -> \input ->
        startsWithTags = \bytes ->
            List.startsWith bytes ['{', '{'] || List.startsWith bytes ['{', '|']
        inputStartsWithTags = startsWithTags input
        if !allowTags && inputStartsWithTags then
            NoMatch
        else if inputStartsWithTags then
            { before, others } = List.splitAt input 2
            (consumed, remaining) = splitWhen others startsWithTags

            Match {
                input: remaining,
                val: List.concat before consumed |> unsafeFromUtf8 |> Text,
            }
        else
            (consumed, remaining) = splitWhen input startsWithTags

            Match {
                input: remaining,
                val: unsafeFromUtf8 consumed |> Text,
            }

splitWhen : List U8, (List U8 -> Bool) -> (List U8, List U8)
splitWhen = \bytes, pred ->
    help = \acc, remaining ->
        when remaining is
            [first, .. as rest] if !(pred remaining) ->
                help (List.append acc first) rest

            _ -> (acc, remaining)
    help [] bytes

string : Str -> Parser Str
string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

horizontalByte : Parser U8
horizontalByte = \input ->
    when input is
        [first, .. as rest] if first != '\n' -> Match { input: rest, val: first }
        _ -> NoMatch

scalar : U8 -> Parser U8
scalar = \byte ->
    \input ->
        when input is
            [x, .. as rest] if x == byte -> Match { val: byte, input: rest }
            _ -> NoMatch

whitespace : Parser (List U8)
whitespace =
    oneOf [scalar ' ', scalar '\t', scalar '\n']
    |> many

# Combinators

startWith : Parser a, Parser * -> Parser a
startWith = \parser, start ->
    andThen start \_ -> parser

endWith : Parser a, Parser * -> Parser a
endWith = \parser, end ->
    andThen parser \result -> end |> map \_ -> result

oneOf : List (Parser a) -> Parser a
oneOf = \options ->
    when options is
        [] -> \_ -> NoMatch
        [first, .. as rest] ->
            \input ->
                if List.isEmpty input then
                    NoMatch
                else
                    when first input is
                        Match m -> Match m
                        NoMatch -> (oneOf rest) input

many : Parser a -> Parser (List a)
many = \parser ->
    help = \input, items ->
        when parser input is
            NoMatch -> Match { input: input, val: items }
            Match m -> help m.input (List.append items m.val)

    \input -> help input []

# Match many occurances of a parser until another parser matches. Return the results of both parsers.
manyUntil : Parser a, Parser b -> Parser (List a, b)
manyUntil = \parser, end ->
    help = \input, items ->
        when end input is
            Match endMatch -> Match { input: endMatch.input, val: (items, endMatch.val) }
            NoMatch ->
                when parser input is
                    NoMatch -> NoMatch
                    Match m -> help m.input (List.append items m.val)

    \input -> help input []

# Match many occurances of a parser before another parser matches. Do not consume input for the ending parser.
manyBefore : Parser a, Parser b -> Parser (List a)
manyBefore = \parser, end ->
    help = \input, items ->
        when end input is
            Match _ -> Match { input, val: items }
            NoMatch ->
                when parser input is
                    NoMatch -> NoMatch
                    Match m -> help m.input (List.append items m.val)

    \input -> help input []

andThen : Parser a, (a -> Parser b) -> Parser b
andThen = \parser, mapper ->
    \input ->
        when parser input is
            NoMatch -> NoMatch
            Match m -> (mapper m.val) m.input

map : Parser a, (a -> b) -> Parser b
map = \parser, mapper ->
    \in ->
        when parser in is
            Match { input, val } -> Match { input, val: mapper val }
            NoMatch -> NoMatch

unsafeFromUtf8 = \bytes ->
    when Str.fromUtf8 bytes is
        Ok s -> s
        Err _ ->
            crash "There is a bug! I was unable to convert these bytes into a string: $(Inspect.toStr bytes)."

# Tests

# just text
expect
    result = parse "foo"
    result == [Text "foo"]

# interpolation in paragraph
expect
    result = parse "<p>{{name}}</p>"
    result == [Text "<p>", Interpolation "name", Text "</p>"]

# sneaky interpolation
expect
    result = parse "{{foo}bar}}"
    result == [Interpolation "foo}bar"]

# raw interpolation
expect
    result = parse "{{{raw val}}}"
    result == [RawInterpolation "raw val"]

# interpolation containing record that looks like raw interpolation
expect
    result = parse "{{{ foo : 10 } |> \\x -> Num.toStr x.foo}}"
    result == [Interpolation "{ foo : 10 } |> \\x -> Num.toStr x.foo"]

# interpolation with piping
expect
    result = parse "{{func arg1 arg2 |> func2 arg2}}"
    result == [Interpolation "func arg1 arg2 |> func2 arg2"]

# simple inline conditional
expect
    result = parse "{|if x > y |}foo{|endif|}"
    result == [Conditional { condition: "x > y", trueBranch: [Text "foo"], falseBranch: [] }]

# conditional
expect
    result = parse
        """
        {|if x > y |}
        foo
        {|endif|}
        """
    result == [Conditional { condition: "x > y", trueBranch: [Text "\nfoo\n"], falseBranch: [] }]

# if else
expect
    result = parse
        """
        {|if model.field |}
        Hello
        {|else|}
        goodbye
        {|endif|}
        """
    result
    == [
        Conditional {
            condition: "model.field",
            trueBranch: [Text "\nHello\n"],
            falseBranch: [Text "\ngoodbye\n"],
        },
    ]

# nested conditionals
expect
    result = parse
        """
        {|if model.someField |}
        {|if Bool.false |}
        bar
        {|endif|}
        {|endif|}
        """
    result
    == [
        Conditional {
            condition: "model.someField",
            trueBranch: [
                Text "\n",
                Conditional { condition: "Bool.false", trueBranch: [Text "\nbar\n"], falseBranch: [] },
                Text "\n",
            ],
            falseBranch: [],
        },
    ]

# interpolation without inner spaces
expect
    result = parse
        """
        foo
        bar
        {{model.baz}}
        foo
        """
    result == [Text "foo\nbar\n", Interpolation "model.baz", Text "\nfoo"]

# Simple import
expect
    result = parse
        "{|import SomeModule |}"
    result == [ModuleImport "SomeModule"]

# import within conditional
expect
    result = parse
        "{|if Bool.true |}{|import SomeModule |}{|endif|}"
    result == [Conditional { condition: "Bool.true", trueBranch: [ModuleImport "SomeModule"], falseBranch: [] }]

# paragraph containing conditional
expect
    result = parse
        """
        <p>
            {|if foo |}
            bar
            {|endif|}
        </p>
        """
    result
    == [
        Text "<p>\n    ",
        Conditional { condition: "foo", trueBranch: [Text "\n    bar\n    "], falseBranch: [] },
        Text "\n</p>",
    ]

# inline conditional
expect
    result = parse
        """
        <div>{|if model.username == "isaac" |}Hello{|endif|}</div>
        """
    result
    ==
    [
        Text "<div>",
        Conditional { condition: "model.username == \"isaac\"", trueBranch: [Text "Hello"], falseBranch: [] },
        Text "</div>",
    ]

# list containing paragraph
expect
    result = parse
        """
        {|list user : users |}
        <p>Hello {{user}}!</p>
        {|endlist|}
        """

    result
    ==
    [
        Sequence {
            item: "user",
            list: "users",
            body: [
                Text "\n<p>Hello ",
                Interpolation "user",
                Text "!</p>\n",
            ],
        },
    ]

# when is on result
expect
    result = parse
        """
        {|when x |}
        {|is Err "foo" |}there was an error
        {|is Ok "bar" |}we are ok!
        {|endwhen|}
        """

    result
    == [
        WhenIs {
            expression: "x",
            cases: [
                { pattern: "Err \"foo\"", branch: [Text "there was an error\n"] },
                { pattern: "Ok \"bar\"", branch: [Text "we are ok!\n"] },
            ],
        },
    ]

# when is with single branch
expect
    result = parse
        """
        {|when x |}
        {|is _ |} catch all
        {|endwhen|}
        """

    result
    == [
        WhenIs {
            expression: "x",
            cases: [
                { pattern: "_", branch: [Text " catch all\n"] },
            ],
        },
    ]

# nested when is
expect
    result = parse
        """
        {|when (foo, bar) |}
        {|is (1, 2) |}
            {|when x |}
            {|is _ |} {{ x }}
            {|endwhen|}
        {|is (_, _) |}
            hello
        {|endwhen|}
        """
    result
    == [
        WhenIs {
            cases: [
                {
                    branch: [
                        Text "\n    ",
                        WhenIs {
                            cases: [{ branch: [Text " ", Interpolation "x", Text "\n    "], pattern: "_" }],
                            expression: "x",
                        },
                        Text "\n",
                    ],
                    pattern: "(1, 2)",
                },
                {
                    branch: [Text "\n    hello\n"],
                    pattern: "(_, _)",
                },
            ],
            expression: "(foo, bar)",
        },
    ]

# parses unicode characters correctly
expect
    result = parse
        """
        中文繁體{{model.foo "🐱"}}🙂‍↕️🥝
        {|if "🥝" == "🥝" |}foo{|endif|}
        """

    result
    == [
        Text "中文繁體",
        Interpolation
            """
            model.foo "🐱"
            """,
        Text "🙂‍↕️🥝\n",
        Conditional {
            condition:
            """
            "🥝" == "🥝"
            """,
            trueBranch: [Text "foo"],
            falseBranch: [],
        },
    ]

# unclosed tags are parsed as Text
expect
    result = parse "{|if Bool.true |}{|list model.cities |}"
    result == [Text "{|if Bool.true |}{|list model.cities |}"]

# multiline tags are not allowed
expect
    result = parse
        """
        {{ "firstline"
        |> Str.concat "secondline"}}
        {{{"raw"
        }}}
        {|if Bool.true
        |}{|endif|}
        {|when result
        |}
        {| _ |} foo
        {|endwhen|}
        {|list item
        : list|}
        {|endlist|}
        {|import
        Module |}
        """
    result
    == [
        Text
            """
            {{ "firstline"
            |> Str.concat "secondline"}}
            {{{"raw"
            }}}
            {|if Bool.true
            |}{|endif|}
            {|when result
            |}
            {| _ |} foo
            {|endwhen|}
            {|list item
            : list|}
            {|endlist|}
            {|import
            Module |}
            """,
    ]
