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

Node2 : [
    T Str,
    C { condition : Str, body : List Node2 },
    S { item : Str, list : Str, body : List Node2 },
]
# generate : List Node -> Str
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

# render : List Node -> Str
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

# nodeToStr : Node -> Str
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

# convertInterpolationsToText : List Node -> List Node2
convertInterpolationsToText = \nodes ->
    List.map nodes \node ->
        when node is
            Interpolation i -> T "\$($(i))"
            Sequence { item, list, body } -> S { item, list, body: convertInterpolationsToText body }
            Conditional { condition, body } -> C { condition, body: convertInterpolationsToText body }
            Text t -> T t
    |> List.walk [] \state, elem ->
        when (state, elem) is
            ([.., T x], T y) ->
                combined = Str.concat x y |> T
                List.dropFirst state 1 |> List.append combined

            _ -> List.append state elem

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
