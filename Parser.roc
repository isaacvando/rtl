interface Parser
    exposes [parse]
    imports []

# Node : [
#     Text Str,
#     Interpolation Str,
#     Conditional { condition : Str, body : List Node },
#     For { list : Str, item : Str, body : Str },
# ]

# parse : Str -> List Node
parse = \input ->
    when Str.toUtf8 input |> (many node) is
        Match { input: [], val } -> combineTextNodes val
        _ -> crash "There is a bug!"

# combineTextNodes : List Node -> List Node
combineTextNodes = \nodes ->
    List.walk nodes [] \state, elem ->
        when (state, elem) is
            ([.. as rest, Text t1], Text t2) ->
                List.append rest (Text (Str.concat t1 t2))

            (_, Conditional { condition, body }) ->
                List.append state (Conditional { condition, body: combineTextNodes body })

            _ -> List.append state elem

# Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]

# node : Parser Node
node =
    oneOf [interpolation, conditional, text]

# interpolation : Parser Node
interpolation =
    _ <- string "{{" |> andThen

    manyUntil anyByte (string "}}")
    |> map \bytes ->
        Str.fromUtf8 bytes |> unwrap |> Interpolation

# conditional : Parser Node
conditional =
    _ <- string "{|if " |> andThen
    condition <- manyUntil anyByte (string " |}") |> andThen
    body <- manyUntil node (string "{|endif|}") |> andThen

    \input -> Match {
            input,
            val: Conditional {
                condition: Str.fromUtf8 condition |> unwrap,
                body: body,
            },
        }

# text : Parser Node
text = \input ->
    when input is
        [] -> NoMatch
        [first, .. as rest] ->
            firstStr = [first] |> Str.fromUtf8 |> unwrap
            Match { input: rest, val: Text firstStr }

# oneOf : List (Parser a) -> Parser a
oneOf = \options ->
    when options is
        [] -> \_ -> NoMatch
        [first, .. as rest] ->
            \input ->
                when first input is
                    Match m -> Match m
                    NoMatch -> (oneOf rest) input

# many : Parser a -> Parser (List a)
many = \parser ->
    help = \input, items ->
        when parser input is
            NoMatch -> Match { input: input, val: items }
            Match m -> help m.input (List.append items m.val)

    \input -> help input []

# string : Str -> Parser Str
string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

# manyUntil : Parser a, Parser * -> Parser (List a)
manyUntil = \parser, end ->
    help = \input, items ->
        when end input is
            Match state -> Match { input: state.input, val: items }
            NoMatch ->
                when parser input is
                    NoMatch -> NoMatch
                    Match m -> help m.input (List.append items m.val)

    \input -> help input []

# andThen : Parser a, (a -> Parser b) -> Parser b
andThen = \parser, mapper ->
    \input ->
        when parser input is
            NoMatch -> NoMatch
            Match m -> (mapper m.val) m.input

# anyByte : Parser U8
anyByte = \input ->
    when input is
        [first, .. as rest] -> Match { input: rest, val: first }
        _ -> NoMatch

# map : Parser a, (a -> b) -> Parser b
map = \parser, mapper ->
    \in ->
        when parser in is
            Match { input, val } -> Match { input, val: mapper val }
            NoMatch -> NoMatch

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
