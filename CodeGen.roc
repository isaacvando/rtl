interface CodeGen
    exposes [generate]
    imports [Parser.{ Node }]

generate : List { name : Str, nodes : List Node } -> Str
generate = \templates ->
    body =
        []
        |> convertInterpolationsToText
        |> render
    """
    interface Pages
        exposes [page]
        imports []

    escapeHtml : Str -> Str
    escapeHtml = \\input ->
        input
        |> Str.replaceEach "&" "&amp;"
        |> Str.replaceEach "<" "&lt;"
        |> Str.replaceEach ">" "&gt;"
        |> Str.replaceEach "\\"" "&quot;"
        |> Str.replaceEach "'" "&#39;"

    page = \\model ->
    $(body)
    """

# \""

RenderNode : [
    Text Str,
    Conditional { condition : Str, body : List RenderNode },
    Sequence { item : Str, list : Str, body : List RenderNode },
]

render : List RenderNode -> Str
render = \nodes ->
    when List.map nodes toStr is
        [elem] -> elem
        blocks ->
            list = blocks |> Str.joinWith ",\n"
            """
            [
            $(list)
            ]
            |> Str.joinWith ""
            """
            |> indent

# toStr : RenderNode -> Str
toStr = \node ->
    block =
        when node is
            Text t ->
                """
                \"""
                $(t)
                \"""
                """

            Conditional { condition, body } ->
                """
                if $(condition) then
                $(render body)
                else
                    ""
                """

            Sequence { item, list, body } ->
                """
                List.map $(list) \\$(item) ->
                $(render body)
                |> Str.joinWith ""
                """
    indent block

convertInterpolationsToText : List Node -> List RenderNode
convertInterpolationsToText = \nodes ->
    List.map nodes \node ->
        when node is
            RawInterpolation i -> Text "\$($(i))"
            Interpolation i -> Text "\$($(i) |> escapeHtml)"
            Text t -> Text t
            Sequence { item, list, body } -> Sequence { item, list, body: convertInterpolationsToText body }
            Conditional { condition, body } -> Conditional { condition, body: convertInterpolationsToText body }
    |> List.walk [] \state, elem ->
        when (state, elem) is
            ([.. as rest, Text x], Text y) ->
                combined = Str.concat x y |> Text
                rest |> List.append combined

            _ -> List.append state elem

indent : Str -> Str
indent = \input ->
    Str.split input "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
