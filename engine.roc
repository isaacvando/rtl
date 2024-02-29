app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Path,
        pf.File,
        Parser.{Ir},
        "page.htmr" as template : List U8,
    ]
    provides [main] to pf

main =
    File.writeUtf8 (Path.fromStr "Pages.roc") (compile template)
    |> Task.onErr \e ->
        Stdout.line "Error writing file: $(Inspect.toStr e)"


compile : List U8 -> Str
compile = \temp -> 
    Parser.parse temp
    |> generate

generate : Ir -> Str
generate = \ir -> 
    body = ""
    """
    interface Pages
        exposes [page]
        imports []

    page =
        \"""
    $(body)
        \"""
        
    """
    


indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
