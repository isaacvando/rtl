module [to_upper]

to_upper : Str -> Result Str _
to_upper = |input|
    input
    |> Str.to_utf8
    |> List.map(
        |byte|
            if 'a' <= byte and byte <= 'z' then
                byte - 'a' + 'A'
            else
                byte,
    )
    |> Str.from_utf8
