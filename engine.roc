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
        CodeGen,
    ]
    provides [main] to pf

main =
    {} <- File.writeUtf8 (Path.fromStr "Pages.roc") (compile "foo")
        |> Task.onErr \e ->
            Stdout.line "Error writing file: $(Inspect.toStr e)"
        |> Task.await

    Stdout.line "Generated Pages.roc"

compile : Str -> Str
compile = \template ->
    Parser.parse template
    |> CodeGen.generate
