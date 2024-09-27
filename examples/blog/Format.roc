module [toUpper]

toUpper : Str -> Result Str _
toUpper = \input ->
    input
    |> Str.toUtf8
    |> List.map \byte ->
        if 'a' <= byte && byte <= 'z' then
            byte - 'a' + 'A'
        else
            byte
    |> Str.fromUtf8
