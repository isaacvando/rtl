interface Parser
    exposes [parse, Node]
    imports []

Node a : [
    Text a,
    Interpolation a,
    Conditional { condition : a, body : a },
    For { list : a, item : a, body : a },
]

nodeMap : Node a, (a -> b) -> Node b
nodeMap = \node, mapper ->
    when node is
        Text val -> Text (mapper val)
        Interpolation val -> Interpolation (mapper val)
        Conditional { condition, body } -> Conditional { condition: mapper condition, body: mapper body }
        For { list, item, body } -> For { list: mapper list, item: mapper item, body: mapper body }

parse : Str -> { nodes : List (Node Str), args : List Str }
parse = \input ->
    bytesNodes =
        when Str.toUtf8 input |> template is
            Match { input: [], val: nodes } -> nodes
            _ -> crash "There is a bug!"

    strNodes =
        bytesNodes
        |> List.map \node ->
            nodeMap node \bytes ->
                Str.fromUtf8 bytes |> unwrap

    args = parseArguments bytesNodes
    { nodes: strNodes, args }

Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]

# template = \state ->
#     when interpolation state.input is
#         Match { input, val } -> template { input, val: List.append state.val val }
#         NoMatch ->
#             when state.input is
#                 [] -> state.val
#                 [c, ..] ->
#                     val =
#                         when state.val is
#                             [.. as r, Text t] ->
#                                 List.append r (Text (List.append t c))

#                             _ -> List.append state.val (Text [c])
#                     template { input: List.dropFirst state.input 1, val }

template : Parser (List (Node (List U8)))
template =
    many (oneOf [interpolation])

oneOf : List (Parser a) -> Parser a
oneOf = \options ->
    when options is
        [] -> \_ -> NoMatch
        [first, .. as rest] ->
            \input ->
                when first input is
                    Match m -> Match m
                    NoMatch -> (oneOf rest) input

many : Parser a -> Parser (List a)
many = \parser ->
    help = \p, input, items ->
        when parser input is
            NoMatch -> Match { input: input, val: items }
            Match m -> help p m.input (List.append items m.val)

    \in -> help parser in []

interpolation : Parser (Node (List U8))
interpolation = \in ->
    eatLineUntil = \state ->
        when state.input is
            ['}', '}', .. as rest] -> Match { input: rest, val: state.val }
            ['\n', _] -> NoMatch
            [c, .. as rest] -> eatLineUntil { input: rest, val: List.append state.val c }
            [] -> NoMatch

    when in is
        ['{', '{', .. as rest] ->
            eatLineUntil { input: rest, val: [] }
            |> map \state ->
                { input: state.input, val: Interpolation state.val }

        _ -> NoMatch

conditional : Parser (Node (List U8))
conditional = \in ->
    eatLineUntil = \state ->
        when state.input is
            ['|', '}', .. as rest] -> Match { input: rest, val: state.val }
            ['\n', _] -> NoMatch
            [c, .. as rest] -> eatLineUntil { input: rest, val: List.append state.val c }
            [] -> NoMatch

    when in is
        ['{', '|', 'i', 'f', ' ', .. as rest] ->
            eatLineUntil { input: rest, val: [] }
            |> map \state ->
                { input: rest, val: Conditional { condition: state.val, body: [] } }

        _ -> NoMatch

# Parsing functions

identifier : Parser (List U8)
identifier = \input ->
    when input is
        [c, ..] if 97 <= c && c <= 122 -> (chompWhile isAlphaNumeric) input
        _ -> NoMatch

chompWhile : (U8 -> Bool) -> Parser (List U8)
chompWhile = \predicate -> \input ->
        chomp = \parser ->
            when parser.input is
                [c, .. as rest] if predicate c -> chomp { input: rest, val: List.append parser.val c }
                _ -> parser

        chomp { input, val: [] } |> Match

isAlphaNumeric : U8 -> Bool
isAlphaNumeric = \c ->
    (48 <= c && c <= 57)
    || (65 <= c && c <= 90)
    || (97 <= c && c <= 122)

map : [Match a, NoMatch], (a -> b) -> [Match b, NoMatch]
map = \match, mapper ->
    when match is
        Match m -> Match (mapper m)
        NoMatch -> NoMatch

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v

# Extract arguments

parseArguments : List (Node (List U8)) -> List Str
parseArguments = \ir ->
    List.walk ir (Set.empty {}) \args, node ->
        when node is
            Interpolation i -> getArgs i |> Set.union args
            Conditional { condition, body } -> getArgs condition |> Set.union (getArgs body) |> Set.union args
            For { list, item, body } -> getArgs list |> Set.union (getArgs body) |> Set.union args # TODO: remove the item from args
            _ -> args
    |> Set.toList

getArgs : List U8 -> Set Str
getArgs = \input ->
    getArgsHelp = \args, in ->
        when in is
            [_, .. as rest] ->
                when identifier in is
                    NoMatch -> getArgsHelp args rest
                    Match ident -> getArgsHelp (Set.insert args ident.val) ident.input

            _ -> args

    getArgsHelp (Set.empty {}) input
    |> Set.map \elem ->
        Str.fromUtf8 elem |> unwrap
