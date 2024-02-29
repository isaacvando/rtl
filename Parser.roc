interface Parser
    exposes [parse, Ir]
    imports []

Ir : List Node
Node : [Text (List U8), Interpolation (List U8)]

parse : List U8 -> Ir
parse = \input -> 
    parseHelp {input, val: []}



Parser a : {input: List U8, val: a}


parseHelp : Parser Ir -> Ir
parseHelp = \state -> 
    when interpolation state.input is
        Ok {input, val} -> parseHelp {input, val: List.append state.val val}
        Err {} -> 
            when state.input is
                [] -> state.val
                [c, .. as rest] -> 
                    val = when state.val is
                        [.. as r, Text t] -> 
                            updatedText = List.append t c
                            List.append r (Text updatedText)
                        _ -> List.append state.val (Text [c])
                    parseHelp {input: rest, val}


interpolation : List U8 -> Result (Parser Node) {}
interpolation = \in -> 
    eatLineUntil = \state -> 
        when state.input is
            ['}','}', .. as rest] -> Ok {input: rest, val: state.val}
            ['\n', _] -> Err {}
            [c, .. as rest] -> eatLineUntil {input: rest, val: List.append state.val c }
            [] -> Err {}

    when in is
        ['{', '{', .. as rest] -> 
            eatLineUntil {input: rest, val: []}
            |> Result.map \state -> 
                {input: state.input, val: Interpolation state.val}

        _ -> Err {}

expect 
    result = "{{abc}}" |> Str.toUtf8 |> interpolation
    result == Ok {input: [], val: Interpolation ['a','b','c'] }

expect 
    result = "{{abc" |> Str.toUtf8 |> interpolation
    result == Err {}

expect 
    result = "{abc}}" |> Str.toUtf8 |> interpolation
    result == Err {}
