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
    """
    interface Pages
        exposes [page]
        imports []

    page = \\model ->
        [
    $(render nodes |> indent)
        ] |> Str.joinWith ""
        
    """

render : List Node -> Str
render = \nodes ->
    condense nodes
    |> List.map nodeToStr
    |> Str.joinWith ",\n\n\n"

# nodeToStr : Node -> Str
nodeToStr = \node ->
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
                    $(render body |> indent)
                else 
                    ""
            """

        _ -> crash "not implemented"

# condense : List Node -> List Node
condense = \nodes ->
    nodes
# List.map nodes \node ->
#     when node is
#         Interpolation i -> Text "\$($(i))"
#         _ -> node
# |> List.walk [] \state, elem ->
#     when (state, elem) is
#         ([_, Text x], Text y) ->
#             combined = Str.concat x y |> Text
#             List.dropFirst state 1 |> List.append combined

#         _ -> List.append state elem

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
