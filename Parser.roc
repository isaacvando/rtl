interface Parser
    exposes [parse, Ir]
    imports []

Ir : List Node
Node : [Text (List U8), Interpolation (List U8)]

parse : List U8 -> { ir : Ir, args : List Str }
parse = \input ->
    ir = template { input, val: [] }
    {
        ir,
        args: parseArguments ir,
    }

# TODO: this needs to handle nested fields like foo.bar
parseArguments : Ir -> List Str
parseArguments = \ir ->
    List.walk ir (Set.empty {}) \args, node ->
        when node is
            Interpolation i -> args
            Text _ -> args
    |> Set.toList

getArgs : List U8 -> List Str
getArgs = \str -> []

# expect getArgs "foo" == ["foo"]
# expect getArgs "foo bar" == ["foo", "bar"]
# expect getArgs "foo+bar" == ["foo", "bar"]

identifier : List U8 -> Result (Parser (List U8)) {}
identifier = \input ->
    when input is
        [c, ..] if 97 <= c && c <= 122 -> chompWhile input isAlphaNumeric |> Ok
        _ -> Err {}

expect
    input = "foo2" |> Str.toUtf8
    result = identifier input
    identToStr result == Ok { input: [], val: "foo2" }

expect
    input = ".bar" |> Str.toUtf8
    result = identifier input
    identToStr result == Err {}

expect
    input = "Baz" |> Str.toUtf8
    result = identifier input
    identToStr result == Err {}

expect
    input = "a" |> Str.toUtf8
    result = identifier input
    identToStr result == Ok { input: [], val: "a" }

expect
    input = "2foo" |> Str.toUtf8
    result = identifier input
    identToStr result == Err {}

identToStr = \result ->
    Result.map result \{ input, val } ->
        { input, val: Str.fromUtf8 val |> unwrap }

chompWhile = \input, predicate ->
    chomp = \parser ->
        when parser.input is
            [c, .. as rest] if predicate c -> chomp { input: rest, val: List.append parser.val c }
            _ -> parser

    chomp { input, val: [] }

# TODO: this should only accept identifiers, and should be aware of strings and string interpolations
# getArgsFromStr : Str -> Set Str
# getArgsFromStr = \str ->
#     Str.split str " "
#     |> List.keepIf \s ->
#         isAlphaNumeric s && startsWithAlpha s
#     |> Set.fromList

# isIdentifier : Str -> Bool
# isIdentifier = \str ->
#     bytes = Str.toUtf8 str
#     when bytes is
#         [c, ..] if 97 <= c && c <= 122 -> isAlphaNumeric bytes
#         _ -> Bool.false

# startsWithAlpha : Str -> Bool
# startsWithAlpha = \str ->
#     Str.toUtf8 str
#     |> List.any \c -> Bool.true

# isAlpha : U8 -> Bool
# isAlpha = \c ->
#     (65 <= c && c <= 90)
#     || (97 <= c && c <= 122)

isAlphaNumeric : U8 -> Bool
isAlphaNumeric = \c ->
    (48 <= c && c <= 57)
    || (65 <= c && c <= 90)
    || (97 <= c && c <= 122)

expect
    result = "<i>{{x}}</i>" |> Str.toUtf8 |> parse |> .ir
    irToStrs result == [Text "<i>", Interpolation "x", Text "</i>"]

irToStrs = \ir ->
    List.map ir \x ->
        when x is
            Text t -> Str.fromUtf8 t |> unwrap |> Text
            Interpolation i -> Str.fromUtf8 i |> unwrap |> Interpolation

Parser a : { input : List U8, val : a }

template : Parser Ir -> Ir
template = \state ->
    when interpolation state.input is
        Ok { input, val } -> template { input, val: List.append state.val val }
        Err {} ->
            when state.input is
                [] -> state.val
                [c, ..] ->
                    val =
                        when state.val is
                            [.. as r, Text t] ->
                                List.append r (Text (List.append t c))

                            _ -> List.append state.val (Text [c])
                    template { input: List.dropFirst state.input 1, val }

interpolation : List U8 -> Result (Parser Node) {}
interpolation = \in ->
    eatLineUntil = \state ->
        when state.input is
            ['}', '}', .. as rest] -> Ok { input: rest, val: state.val }
            ['\n', _] -> Err {}
            [c, .. as rest] -> eatLineUntil { input: rest, val: List.append state.val c }
            [] -> Err {}

    when in is
        ['{', '{', .. as rest] ->
            eatLineUntil { input: rest, val: [] }
            |> Result.map \state ->
                { input: state.input, val: Interpolation state.val }

        _ -> Err {}

expect
    result = "{{abc}}" |> Str.toUtf8 |> interpolation
    result == Ok { input: [], val: Interpolation ['a', 'b', 'c'] }

expect
    result = "{{abc" |> Str.toUtf8 |> interpolation
    result == Err {}

expect
    result = "{abc}}" |> Str.toUtf8 |> interpolation
    result == Err {}

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
