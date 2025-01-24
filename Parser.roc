module [parse, Node]

Node : [
    Text Str,
    Interpolation Str,
    RawInterpolation Str,
    ModuleImport Str,
    Conditional { condition : Str, true_branch : List Node, false_branch : List Node },
    Sequence { item : Str, list : Str, body : List Node },
    WhenIs { expression : Str, cases : List { pattern : Str, branch : List Node } },
]

parse : Str -> List Node
parse = |input|
    when Str.to_utf8(input) |> (many(node)) is
        Match({ input: [], val }) -> combine_text_nodes(val)
        Match(_) -> crash("There is a bug! Not all input was consumed.")
        NoMatch -> crash("There is a bug! The parser didn't match.")

combine_text_nodes : List Node -> List Node
combine_text_nodes = |nodes|
    List.walk(
        nodes,
        [],
        |state, elem|
            when (state, elem) is
                ([.. as rest, Text(t1)], Text(t2)) ->
                    List.append(rest, Text(Str.concat(t1, t2)))

                (_, Conditional({ condition, true_branch, false_branch })) ->
                    List.append(state, Conditional({ condition, true_branch: combine_text_nodes(true_branch), false_branch: combine_text_nodes(false_branch) }))

                (_, Sequence({ item, list, body })) ->
                    List.append(state, Sequence({ item, list, body: combine_text_nodes(body) }))

                (_, WhenIs({ expression, cases })) ->
                    combined = WhenIs(
                        {
                            expression,
                            cases: List.map(
                                cases,
                                |{ pattern, branch }|
                                    { pattern, branch: combine_text_nodes(branch) },
                            ),
                        },
                    )
                    List.append(state, combined)

                _ -> List.append(state, elem),
    )

# Parsers

Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]

node =
    one_of(
        [
            text(Bool.false),
            raw_interpolation,
            interpolation,
            import_module,
            sequence,
            when_is,
            conditional,
            text(Bool.true),
        ],
    )

interpolation : Parser Node
interpolation =
    many_until(horizontal_byte, string("}}"))
    |> start_with(string("{{"))
    |> map(
        |(bytes, _)|
            bytes
            |> unsafe_from_utf8
            |> Str.trim
            |> Interpolation,
    )

import_module : Parser Node
import_module =
    many_until(horizontal_byte, string("|}"))
    |> start_with(string("{|import"))
    |> map(
        |(bytes, _)|
            bytes
            |> unsafe_from_utf8
            |> Str.trim
            |> ModuleImport,
    )

raw_interpolation : Parser Node
raw_interpolation =
    many_until(horizontal_byte, string("}}}"))
    |> start_with(string("{{{"))
    |> map(
        |(bytes, _)|
            bytes
            |> unsafe_from_utf8
            |> Str.trim
            |> RawInterpolation,
    )

when_is : Parser Node
when_is =
    many_until(horizontal_byte, (string(" |}") |> end_with(whitespace)))
    |> start_with(string("{|when "))
    |> and_then(
        |(expression, _)|

            case =
                many_until(horizontal_byte, string(" |}"))
                |> start_with(string("{|is "))
                |> and_then(
                    |(pattern, _)|

                        many_before(node, one_of([string("{|is "), string("{|endwhen|}")]))
                        |> map(
                            |branch|

                                { pattern: unsafe_from_utf8(pattern), branch },
                        ),
                )

            many_until(case, string("{|endwhen|}"))
            |> map(
                |(cases, _)|

                    WhenIs(
                        {
                            expression: unsafe_from_utf8(expression),
                            cases,
                        },
                    ),
            ),
    )

sequence : Parser Node
sequence =
    many_until(horizontal_byte, string(" : "))
    |> start_with(string("{|list "))
    |> and_then(
        |(item, _)|

            many_until(horizontal_byte, string(" |}"))
            |> and_then(
                |(list, _)|

                    many_until(node, string("{|endlist|}"))
                    |> map(
                        |(body, _)|

                            Sequence(
                                {
                                    item: unsafe_from_utf8(item),
                                    list: unsafe_from_utf8(list),
                                    body: body,
                                },
                            ),
                    ),
            ),
    )

conditional =
    many_until(horizontal_byte, string(" |}"))
    |> start_with(string("{|if "))
    |> and_then(
        |(condition, _)|

            many_until(node, one_of([string("{|endif|}"), string("{|else|}")]))
            |> and_then(
                |(true_branch, separator)|

                    parse_false_branch =
                        if separator == "{|endif|}" then
                            |input| Match({ input, val: [] })
                        else
                            many_until(node, string("{|endif|}"))
                            |> map(.0)

                    parse_false_branch
                    |> map(
                        |false_branch|

                            Conditional(
                                {
                                    condition: unsafe_from_utf8(condition),
                                    true_branch,
                                    false_branch,
                                },
                            ),
                    ),
            ),
    )

text : Bool -> Parser Node
text = |allow_tags|
    |input|
        starts_with_tags = |bytes|
            List.starts_with(bytes, ['{', '{']) or List.starts_with(bytes, ['{', '|'])
        input_starts_with_tags = starts_with_tags(input)
        if !allow_tags and input_starts_with_tags then
            NoMatch
        else if input_starts_with_tags then
            { before, others } = List.split_at(input, 2)
            (consumed, remaining) = split_when(others, starts_with_tags)

            Match(
                {
                    input: remaining,
                    val: List.concat(before, consumed) |> unsafe_from_utf8 |> Text,
                },
            )
        else
            (consumed, remaining) = split_when(input, starts_with_tags)

            Match(
                {
                    input: remaining,
                    val: unsafe_from_utf8(consumed) |> Text,
                },
            )

split_when : List U8, (List U8 -> Bool) -> (List U8, List U8)
split_when = |bytes, pred|
    help = |acc, remaining|
        when remaining is
            [first, .. as rest] if !(pred(remaining)) ->
                help(List.append(acc, first), rest)

            _ -> (acc, remaining)
    help([], bytes)

string : Str -> Parser Str
string = |str|
    |input|
        bytes = Str.to_utf8(str)
        if List.starts_with(input, bytes) then
            Match({ input: List.drop_first(input, List.len(bytes)), val: str })
        else
            NoMatch

horizontal_byte : Parser U8
horizontal_byte = |input|
    when input is
        [first, .. as rest] if first != '\n' -> Match({ input: rest, val: first })
        _ -> NoMatch

scalar : U8 -> Parser U8
scalar = |byte|
    |input|
        when input is
            [x, .. as rest] if x == byte -> Match({ val: byte, input: rest })
            _ -> NoMatch

whitespace : Parser (List U8)
whitespace =
    one_of([scalar(' '), scalar('\t'), scalar('\n')])
    |> many

# Combinators

start_with : Parser a, Parser * -> Parser a
start_with = |parser, start|
    and_then(start, |_| parser)

end_with : Parser a, Parser * -> Parser a
end_with = |parser, end|
    and_then(parser, |result| end |> map(|_| result))

one_of : List (Parser a) -> Parser a
one_of = |options|
    when options is
        [] -> |_| NoMatch
        [first, .. as rest] ->
            |input|
                if List.is_empty(input) then
                    NoMatch
                else
                    when first(input) is
                        Match(m) -> Match(m)
                        NoMatch -> (one_of(rest))(input)

many : Parser a -> Parser (List a)
many = |parser|
    help = |input, items|
        when parser(input) is
            NoMatch -> Match({ input: input, val: items })
            Match(m) -> help(m.input, List.append(items, m.val))

    |input| help(input, [])

# Match many occurances of a parser until another parser matches. Return the results of both parsers.
many_until : Parser a, Parser b -> Parser (List a, b)
many_until = |parser, end|
    help = |input, items|
        when end(input) is
            Match(end_match) -> Match({ input: end_match.input, val: (items, end_match.val) })
            NoMatch ->
                when parser(input) is
                    NoMatch -> NoMatch
                    Match(m) -> help(m.input, List.append(items, m.val))

    |input| help(input, [])

# Match many occurances of a parser before another parser matches. Do not consume input for the ending parser.
many_before : Parser a, Parser b -> Parser (List a)
many_before = |parser, end|
    help = |input, items|
        when end(input) is
            Match(_) -> Match({ input, val: items })
            NoMatch ->
                when parser(input) is
                    NoMatch -> NoMatch
                    Match(m) -> help(m.input, List.append(items, m.val))

    |input| help(input, [])

and_then : Parser a, (a -> Parser b) -> Parser b
and_then = |parser, mapper|
    |input|
        when parser(input) is
            NoMatch -> NoMatch
            Match(m) -> (mapper(m.val))(m.input)

map : Parser a, (a -> b) -> Parser b
map = |parser, mapper|
    |in|
        when parser(in) is
            Match({ input, val }) -> Match({ input, val: mapper(val) })
            NoMatch -> NoMatch

unsafe_from_utf8 = |bytes|
    when Str.from_utf8(bytes) is
        Ok(s) -> s
        Err(_) ->
            crash("There is a bug! I was unable to convert these bytes into a string: ${Inspect.to_str(bytes)}.")

# Tests

# just text
expect
    result = parse("foo")
    result == [Text("foo")]

# interpolation in paragraph
expect
    result = parse("<p>{{name}}</p>")
    result == [Text("<p>"), Interpolation("name"), Text("</p>")]

# sneaky interpolation
expect
    result = parse("{{foo}bar}}")
    result == [Interpolation("foo}bar")]

# raw interpolation
expect
    result = parse("{{{raw val}}}")
    result == [RawInterpolation("raw val")]

# interpolation containing record that looks like raw interpolation
expect
    result = parse("{{{ foo : 10 } |> \\x -> Num.toStr x.foo}}")
    result == [Interpolation("{ foo : 10 } |> \\x -> Num.toStr x.foo")]

# interpolation with piping
expect
    result = parse("{{func arg1 arg2 |> func2 arg2}}")
    result == [Interpolation("func arg1 arg2 |> func2 arg2")]

# simple inline conditional
expect
    result = parse("{|if x > y |}foo{|endif|}")
    result == [Conditional({ condition: "x > y", true_branch: [Text("foo")], false_branch: [] })]

# conditional
expect
    result = parse(
        """
        {|if x > y |}
        foo
        {|endif|}
        """,
    )
    result == [Conditional({ condition: "x > y", true_branch: [Text("\nfoo\n")], false_branch: [] })]

# if else
expect
    result = parse(
        """
        {|if model.field |}
        Hello
        {|else|}
        goodbye
        {|endif|}
        """,
    )
    result
    == [
        Conditional(
            {
                condition: "model.field",
                true_branch: [Text("\nHello\n")],
                false_branch: [Text("\ngoodbye\n")],
            },
        ),
    ]

# nested conditionals
expect
    result = parse(
        """
        {|if model.someField |}
        {|if Bool.false |}
        bar
        {|endif|}
        {|endif|}
        """,
    )
    result
    == [
        Conditional(
            {
                condition: "model.someField",
                true_branch: [
                    Text("\n"),
                    Conditional({ condition: "Bool.false", true_branch: [Text("\nbar\n")], false_branch: [] }),
                    Text("\n"),
                ],
                false_branch: [],
            },
        ),
    ]

# interpolation without inner spaces
expect
    result = parse(
        """
        foo
        bar
        {{model.baz}}
        foo
        """,
    )
    result == [Text("foo\nbar\n"), Interpolation("model.baz"), Text("\nfoo")]

# Simple import
expect
    result = parse(
        "{|import SomeModule |}",
    )
    result == [ModuleImport("SomeModule")]

# import within conditional
expect
    result = parse(
        "{|if Bool.true |}{|import SomeModule |}{|endif|}",
    )
    result == [Conditional({ condition: "Bool.true", true_branch: [ModuleImport("SomeModule")], false_branch: [] })]

# paragraph containing conditional
expect
    result = parse(
        """
        <p>
            {|if foo |}
            bar
            {|endif|}
        </p>
        """,
    )
    result
    == [
        Text("<p>\n    "),
        Conditional({ condition: "foo", true_branch: [Text("\n    bar\n    ")], false_branch: [] }),
        Text("\n</p>"),
    ]

# inline conditional
expect
    result = parse(
        """
        <div>{|if model.username == "isaac" |}Hello{|endif|}</div>
        """,
    )
    result
    ==
    [
        Text("<div>"),
        Conditional({ condition: "model.username == \"isaac\"", true_branch: [Text("Hello")], false_branch: [] }),
        Text("</div>"),
    ]

# list containing paragraph
expect
    result = parse(
        """
        {|list user : users |}
        <p>Hello {{user}}!</p>
        {|endlist|}
        """,
    )

    result
    ==
    [
        Sequence(
            {
                item: "user",
                list: "users",
                body: [
                    Text("\n<p>Hello "),
                    Interpolation("user"),
                    Text("!</p>\n"),
                ],
            },
        ),
    ]

# when is on result
expect
    result = parse(
        """
        {|when x |}
        {|is Err "foo" |}there was an error
        {|is Ok "bar" |}we are ok!
        {|endwhen|}
        """,
    )

    result
    == [
        WhenIs(
            {
                expression: "x",
                cases: [
                    { pattern: "Err \"foo\"", branch: [Text("there was an error\n")] },
                    { pattern: "Ok \"bar\"", branch: [Text("we are ok!\n")] },
                ],
            },
        ),
    ]

# when is with single branch
expect
    result = parse(
        """
        {|when x |}
        {|is _ |} catch all
        {|endwhen|}
        """,
    )

    result
    == [
        WhenIs(
            {
                expression: "x",
                cases: [
                    { pattern: "_", branch: [Text(" catch all\n")] },
                ],
            },
        ),
    ]

# nested when is
expect
    result = parse(
        """
        {|when (foo, bar) |}
        {|is (1, 2) |}
            {|when x |}
            {|is _ |} {{ x }}
            {|endwhen|}
        {|is (_, _) |}
            hello
        {|endwhen|}
        """,
    )
    result
    == [
        WhenIs(
            {
                cases: [
                    {
                        branch: [
                            Text("\n    "),
                            WhenIs(
                                {
                                    cases: [{ branch: [Text(" "), Interpolation("x"), Text("\n    ")], pattern: "_" }],
                                    expression: "x",
                                },
                            ),
                            Text("\n"),
                        ],
                        pattern: "(1, 2)",
                    },
                    {
                        branch: [Text("\n    hello\n")],
                        pattern: "(_, _)",
                    },
                ],
                expression: "(foo, bar)",
            },
        ),
    ]

# parses unicode characters correctly
expect
    result = parse(
        """
        中文繁體{{model.foo "🐱"}}🙂‍↕️🥝
        {|if "🥝" == "🥝" |}foo{|endif|}
        """,
    )

    result
    == [
        Text("中文繁體"),
        Interpolation(
            """
            model.foo "🐱"
            """,
        ),
        Text("🙂‍↕️🥝\n"),
        Conditional(
            {
                condition:
                """
                "🥝" == "🥝"
                """,
                true_branch: [Text("foo")],
                false_branch: [],
            },
        ),
    ]

# unclosed tags are parsed as Text
expect
    result = parse("{|if Bool.true |}{|list model.cities |}")
    result == [Text("{|if Bool.true |}{|list model.cities |}")]

# multiline tags are not allowed
expect
    result = parse(
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
    )
    result
    == [
        Text(
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
        ),
    ]
