app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Path,
        pf.File,
        Parser,
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

# generate : List Node -> Str
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

render = \nodes ->
    List.map nodes nodeToStr
    |> Str.joinWith ",\n\n\n"

nodeToStr = \node ->
    when node is
        Text t ->
            """
            \"""
            $(t)
            \"""
            """

        Interpolation i -> "\"\$($(i))\""
        Conditional { condition, body } ->
            """
                if $(condition) then
                    $(render body)
                else 
                    ""
            """

        _ -> crash "not implemented"

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
