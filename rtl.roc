app "rtl"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Stderr,
        pf.Task.{ Task },
        pf.Path.{ Path },
        pf.File,
        pf.Dir,
        pf.Arg,
        Parser,
        CodeGen,
    ]
    provides [main] to pf

main =
    args <- Arg.list |> Task.await
    when args is
        [_, "--help"] | [_, "-h"] ->
            Stdout.line
                """
                Welcome to Roc Template Language (RTL)!

                In a directory containing .rtl files, run `rtl` to generate Pages.roc.

                Get the latest version at https://github.com/isaacvando/rtl
                """

        _ ->
            paths <- Dir.list (Path.fromStr ".")
                |> Task.onErr \e ->
                    {} <- Stderr.line "Error listing directories: $(Inspect.toStr e)" |> Task.await
                    Task.err 1
                |> Task.map keepTemplates
                |> Task.await

            invalidTemplateNames =
                List.map paths \p ->
                    getFileName p
                    |> Str.replaceLast extension ""
                |> List.dropIf isValidFunctionName

            if !(List.isEmpty invalidTemplateNames) then
                {} <- Stderr.line
                        """
                        The following templates have invalid names: $(invalidTemplateNames |> Str.joinWith ", ")
                        Each template must start with a lowercase letter and only contain letters and numbers.
                        """
                    |> Task.await
                Task.err 1
            else
                templates <- taskAll paths \path ->
                        File.readUtf8 path
                        |> Task.map \template ->
                            { path, template }
                    |> Task.onErr \e ->
                        {} <- Stderr.line "There was an error reading the templates: $(Inspect.toStr e)" |> Task.await
                        Task.err 1
                    |> Task.await

                if List.isEmpty templates then
                    Stdout.line "No .rtl templates found in the current directory"
                else
                    {} <- File.writeUtf8 (Path.fromStr "Pages.roc") (compile templates)
                        |> Task.onErr \e ->
                            {} <- Stderr.line "Error writing file: $(Inspect.toStr e)" |> Task.await
                            Task.err 1
                        |> Task.await

                    Stdout.line "Generated Pages.roc"

keepTemplates : List Path -> List Path
keepTemplates = \paths ->
    List.keepIf paths \p ->
        Path.display p
        |> Str.endsWith extension

compile : List { path : Path, template : Str } -> Str
compile = \templates ->
    templates
    |> List.map \{ path, template } ->
        name =
            getFileName path
            |> Str.replaceLast extension ""
        { name, nodes: Parser.parse template }
    |> CodeGen.generate

getFileName : Path -> Str
getFileName = \path ->
    display = Path.display path
    when Str.split display "/" is
        [.., filename] -> filename
        _ -> crash "This is a bug! This case should not happen."

extension = ".rtl"

taskAll : List a, (a -> Task b err) -> Task (List b) err
taskAll = \items, task ->
    Task.loop { vals: [], rest: items } \{ vals, rest } ->
        when rest is
            [] -> Done vals |> Task.ok
            [item, .. as remaining] ->
                Task.map (task item) \val ->
                    Step { vals: List.append vals val, rest: remaining }

isValidFunctionName : Str -> Bool
isValidFunctionName = \str ->
    bytes = Str.toUtf8 str
    when bytes is
        [first, .. as rest] if 97 <= first && first <= 122 ->
            List.all rest isAlphaNumeric

        _ -> Bool.false

expect isValidFunctionName "fooBar"
expect isValidFunctionName "a"
expect isValidFunctionName "abc123"
expect isValidFunctionName "123four" |> Bool.not
expect isValidFunctionName "snake_case" |> Bool.not
expect isValidFunctionName "punctuation!" |> Bool.not

isAlphaNumeric : U8 -> Bool
isAlphaNumeric = \c ->
    (48 <= c && c <= 57)
    || (65 <= c && c <= 90)
    || (97 <= c && c <= 122)
