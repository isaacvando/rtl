interface Parser
    exposes [parse, Ir]
    imports []

Ir : List Node
Node : [Text (List U8), Interpolation (List U8)]

parse : List U8 -> Ir
parse = \input ->
    template { input, val: [] }

expect
    result = "<i>{{x}}</i>" |> Str.toUtf8 |> parse
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
