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
    {} <- File.writeUtf8 (Path.fromStr "Pages.roc") (compile template)
        |> Task.onErr \e ->
            Stdout.line "Error writing file: $(Inspect.toStr e)"
        |> Task.await

    Stdout.line "Generated Pages.roc"

compile = \temp ->
    Parser.parse temp
    |> generate

generate : List Node -> Str
generate = \nodes ->
    body =
        nodes
        |> convertInterpolationsToText
        |> render
    """
    interface Pages
        exposes [page]
        imports []

    page = \\model ->
    $(body)
    """

RenderNode : [
    T Str,
    C { condition : Str, body : List RenderNode },
    S { item : Str, list : Str, body : List RenderNode },
]

render : List RenderNode -> Str
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

# nodeToStr : RenderNode -> Str
nodeToStr = \node ->
    block =
        when node is
            T t ->
                """
                \"""
                $(t)
                \"""
                """

            C { condition, body } ->
                """
                if $(condition) then
                $(render body)
                else
                    ""
                """

            S { item, list, body } ->
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
            Interpolation i -> T "\$($(i))"
            Text t -> T t
            Sequence { item, list, body } -> S { item, list, body: convertInterpolationsToText body }
            Conditional { condition, body } -> C { condition, body: convertInterpolationsToText body }
    |> List.walk [] \state, elem ->
        when (state, elem) is
            ([.., T x], T y) ->
                combined = Str.concat x y |> T
                List.dropFirst state 1 |> List.append combined

            _ -> List.append state elem

indent : Str -> Str
indent = \input ->
    Str.split input "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
