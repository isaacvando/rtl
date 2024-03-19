interface Parser
    exposes [parse, Node]
    imports []

Node : [
    Text Str,
    Interpolation Str,
    Conditional { condition : Str, body : Str },
    For { list : Str, item : Str, body : Str },
]

parse : Str -> { nodes : List Node, args : List Str }
parse = \input ->
    nodes =
        when Str.toUtf8 input |> template is
            Match { input: [], val } -> combineTextNodes val
            _ -> crash "There is a bug!"

    args = parseArguments nodes

    { nodes, args }

combineTextNodes : List Node -> List Node
combineTextNodes = \nodes ->
    List.walk nodes [] \state, elem ->
        when (state, elem) is
            ([.. as rest, Text t1], Text t2) ->
                List.append rest (Text (Str.concat t1 t2))

            _ -> List.append state elem

Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]

template : Parser (List Node)
template =
    many (oneOf [interpolation, text])

text : Parser Node
text = \input ->
    when input is
        [] -> NoMatch
        [first, .. as rest] ->
            firstStr = [first] |> Str.fromUtf8 |> unwrap
            Match { input: rest, val: Text firstStr }

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

interpolation : Parser Node
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
                valStr = state.val |> Str.fromUtf8 |> unwrap
                { input: state.input, val: Interpolation valStr }

        _ -> NoMatch

conditional : Parser Node
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
                { input: rest, val: Conditional { condition: state.val |> Str.fromUtf8 |> unwrap, body: "" } }

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

parseArguments : List Node -> List Str
parseArguments = \ir ->
    List.walk ir (Set.empty {}) \args, node ->
        when node is
            Interpolation i -> getArgs i |> Set.union args
            Conditional { condition, body } -> getArgs condition |> Set.union (getArgs body) |> Set.union args
            For { list, item, body } -> getArgs list |> Set.union (getArgs body) |> Set.difference (Set.fromList [item]) |> Set.union args # TODO: remove the item from args
            _ -> args
    |> Set.toList

getArgs : Str -> Set Str
getArgs = \input ->
    getArgsHelp = \args, in ->
        when in is
            [_, .. as rest] ->
                when identifier in is
                    NoMatch -> getArgsHelp args rest
                    Match ident -> getArgsHelp (Set.insert args ident.val) ident.input

            _ -> args

    getArgsHelp (Set.empty {}) (Str.toUtf8 input)
    |> Set.map \elem ->
        Str.fromUtf8 elem |> unwrap
