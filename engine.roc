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
    body = List.walk nodes "" \state, elem ->
        when elem is
            Text t -> Str.concat state t
            Interpolation i ->
                Str.concat state "\$($(i))"

            _ -> state

    """
    interface Pages
        exposes [page]
        imports []

    page = \\model ->
        \"""
    $(body |> indent)\"""
        
    """

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"

unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
