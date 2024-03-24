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
        "page.htmr" as page : Str,
    ]
    provides [main] to pf

main =
    {} <- File.writeUtf8 (Path.fromStr "Pages.roc") (compile page)
        |> Task.onErr \e ->
            Stdout.line "Error writing file: $(Inspect.toStr e)"
        |> Task.await

    Stdout.line "Generated Pages.roc"

compile : Str -> Str
compile = \template ->
    body =
        Parser.parse template
        |> convertInterpolationsToText
        |> render
    """
    interface Pages
        exposes [page]
        imports []

    page = \\model ->
    $(body)
    """

render = \nodes ->
    when List.map nodes nodeToStr is
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

            Sequence { item, list, body } ->
                """
                List.map $(list) \\$(item) ->
                $(render body)
                |> Str.joinWith ""
                """
    indent block

convertInterpolationsToText = \nodes ->
    List.map nodes \node ->
        when node is
            Interpolation i -> Text "\$($(i))"
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
