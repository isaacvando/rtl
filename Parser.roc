interface Parser
    exposes [parse, Node]
    imports []

Node : [
    Text Str,
    Interpolation Str,
    Conditional { condition : Str, body : Str },
    For { list : Str, item : Str, body : Str },
]

parse : Str -> { nodes : List Node, args : Set Str }
parse = \input ->
    nodes =
        when Str.toUtf8 input |> (many node) is
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

node : Parser Node
node =
    oneOf [interpolation, conditional, text]

interpolation : Parser Node
interpolation =
    _ <- string "{{" |> andThen

    manyUntil anyByte (string "}}")
    |> map \bytes ->
        Str.fromUtf8 bytes |> unwrap |> Interpolation

conditional : Parser Node
conditional =
    _ <- string "{|if " |> andThen
    condition <- manyUntil anyByte (string " |}") |> andThen
    body <- manyUntil anyByte (string "{|endif|}") |> andThen

    \input -> Match {
            input,
            val: Conditional {
                condition: Str.fromUtf8 condition |> unwrap,
                body: Str.fromUtf8 body |> unwrap,
            },
        }

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
    help = \input, items ->
        when parser input is
            NoMatch -> Match { input: input, val: items }
            Match m -> help m.input (List.append items m.val)

    \input -> help input []

string : Str -> Parser Str
string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

manyUntil : Parser a, Parser * -> Parser (List a)
manyUntil = \parser, end ->
    help = \input, items ->
        when end input is
            Match state -> Match { input: state.input, val: items }
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

anyByte : Parser U8
anyByte = \input ->
    when input is
        [first, .. as rest] -> Match { input: rest, val: first }
        _ -> NoMatch

# conditional : Parser Node
# conditional = \in ->
#     eatLineUntil = \state ->
#         when state.input is
#             ['|', '}', .. as rest] -> Match { input: rest, val: state.val }
#             ['\n', _] -> NoMatch
#             [c, .. as rest] -> eatLineUntil { input: rest, val: List.append state.val c }
#             [] -> NoMatch

#     when in is
#         ['{', '|', 'i', 'f', ' ', .. as rest] ->
#             eatLineUntil { input: rest, val: [] }
#             |> map \state ->
#                 { input: rest, val: Conditional { condition: state.val |> Str.fromUtf8 |> unwrap, body: "" } }

#         _ -> NoMatch

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

map : Parser a, (a -> b) -> Parser b
map = \parser, mapper ->
    \in ->
        when parser in is
            Match { input, val } -> Match { input, val: mapper val }
            NoMatch -> NoMatch

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v

# Extract arguments

parseArguments : List Node -> Set Str
parseArguments = \ir ->
    List.walk ir (Set.empty {}) \args, n ->
        when n is
            Interpolation i -> getArgs i |> Set.union args
            Conditional { condition, body } -> getArgs condition |> Set.union (getArgs body) |> Set.union args
            For { list, item, body } -> getArgs list |> Set.union (getArgs body) |> Set.difference (Set.fromList [item]) |> Set.union args # TODO: remove the item from args
            _ -> args

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
