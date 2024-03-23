app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Path,
        pf.File,
        Parser.{ Node },
        "page.htmr" as template : Str,
    ]
    provides [main] to pf

main =
    File.writeUtf8 (Path.fromStr "Pages.roc") (compile template)
    |> Task.onErr \e ->
        Stdout.line "Error writing file: $(Inspect.toStr e)"
    |> Task.await \_ ->
        Stdout.line "Generated Pages.roc"

compile = \temp ->
    Parser.parse temp
    |> generate

generate : List Node -> Str
generate = \nodes ->
    dbg nodes

    """
    interface Pages
        exposes [page]
        imports []

    page = \\model ->
    $(render nodes)
    """

render : List Node -> Str
render = \nodes ->
    blocks = condense nodes |> List.map nodeToStr

    when blocks is
        [elem] -> elem
        _ ->
            list = blocks |> Str.joinWith ",\n"
            """
            [
            $(list)
            ]
            |> Str.joinWith ""
            """
            |> indent

# nodeToStr : Node -> Str
nodeToStr = \node ->
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

            Sequence { item, list, body } -> ""
            # """
            # List.map $(list) \\$(item) ->
            #     $(render body)
            # |> Str.joinWith ""
            # """
            _ -> "not implemented"
    indent block

# condense : List Node -> List Node
condense = \nodes ->
    List.map nodes \node ->
        when node is
            Interpolation i -> Text "\$($(i))"
            _ -> node
    |> List.walk [] \state, elem ->
        when (state, elem) is
            ([.., Text x], Text y) ->
                combined = Str.concat x y |> Text
                List.dropFirst state 1 |> List.append combined

            _ -> List.append state elem

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"

