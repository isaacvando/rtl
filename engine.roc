app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Path,
        pf.File,
        "page.htmr" as template : Str,
    ]
    provides [main] to pf

main =
    File.writeUtf8 (Path.fromStr "Pages.roc") output
    |> Task.onErr \e ->
        Stdout.line "Error writing file: $(Inspect.toStr e)"

output =
    """
    interface Pages
        exposes [page]
        imports []

    page =
        \"""
    $(indent template)
        \"""
        
    """

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
