interface Parser
    exposes [parse, Node]
    imports []

Node : [
    Text (List U8),
    Interpolation (List U8),
    Conditional { condition : List U8, body : List U8 },
    For { list : List U8, item : List U8, body : List U8 },
]

parse : List U8 -> { nodes: List Node, args : List Str }
parse = \input ->
    nodes = template { input, val: [] }
    args = parseArguments nodes
    {nodes, args}

parseArguments : List Node -> List Str
parseArguments = \ir ->
    List.walk ir (Set.empty {}) \args, node ->
        when node is
            Interpolation i -> args
            Text _ -> args
            Conditional _ -> args
            _ -> args
    |> Set.toList

getArgs : List U8 -> List Str
getArgs = \input ->
    getArgsHelp = \args, in ->
        when in is
            [_, .. as rest] ->
                when identifier in is
                    Err _ -> getArgsHelp args rest
                    Ok ident -> getArgsHelp (List.append args ident.val) ident.input

            _ -> args

    getArgsHelp [] input
    |> List.map \elem ->
        Str.fromUtf8 elem |> unwrap

identifier : List U8 -> Result (Parser (List U8)) {}
identifier = \input ->
    when input is
        [c, ..] if 97 <= c && c <= 122 -> chompWhile input isAlphaNumeric |> Ok
        _ -> Err {}

identToStr = \result ->
    Result.map result \{ input, val } ->
        { input, val: Str.fromUtf8 val |> unwrap }

chompWhile = \input, predicate ->
    chomp = \parser ->
        when parser.input is
            [c, .. as rest] if predicate c -> chomp { input: rest, val: List.append parser.val c }
            _ -> parser

    chomp { input, val: [] }

isAlphaNumeric : U8 -> Bool
isAlphaNumeric = \c ->
    (48 <= c && c <= 57)
    || (65 <= c && c <= 90)
    || (97 <= c && c <= 122)

Parser a : { input : List U8, val : a }

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

# conditional : List U8 -> Result (Parser Node) {}
conditional = \in ->
    eatLineUntil = \state ->
        when state.input is
            ['|', '}', .. as rest] -> Ok { input: rest, val: state.val }
            ['\n', _] -> Err {}
            [c, .. as rest] -> eatLineUntil { input: rest, val: List.append state.val c }
            [] -> Err {}

    when in is
        ['{', '|', 'i', 'f', ' ', .. as rest] ->
            when eatLineUntil { input: rest, val: [] } is
                Ok state ->
                    Ok (Conditional { condition: state.val, body: [] })

                Err _ -> Err {}

        _ -> Err {}

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
