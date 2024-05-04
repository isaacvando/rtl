app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
}

import pf.Stdout
import pf.Task exposing [Task]
import pf.Path exposing [Path]
import pf.File
import pf.Dir
import pf.Arg
import Parser
import CodeGen

main =
    when Arg.list! is
        [_, "--help"] | [_, "-h"] ->
            Stdout.line
                """
                Welcome to Roc Template Language (RTL)!

                In a directory containing .rtl files, run `rtl` to generate Pages.roc.

                Get the latest version at https://github.com/isaacvando/rtl
                """

        _ ->
            paths =
                Dir.list! (Path.fromStr ".")
                    |> Task.mapErr \e ->
                        Exit 1 "Error listing directories: $(Inspect.toStr e)"
                    |> Task.map keepTemplates

            invalidTemplateNames =
                List.map paths \p ->
                    getFileName p
                    |> Str.replaceLast extension ""
                |> List.dropIf isValidFunctionName

            if !(List.isEmpty invalidTemplateNames) then
                Exit
                    1
                    """
                    The following templates have invalid names: $(invalidTemplateNames |> Str.joinWith ", ")
                    Each template must start with a lowercase letter and only contain letters and numbers.
                    """
                |> Task.err
            else
                templates =
                    taskAll! paths \path ->
                        File.readUtf8 path
                        |> Task.map \template ->
                            { path, template }
                        |> Task.mapErr \e ->
                            Exit 1 "There was an error reading the templates: $(Inspect.toStr e)"

                if List.isEmpty templates then
                    Stdout.line "No .rtl templates found in the current directory"
                else
                    File.writeUtf8! (Path.fromStr "Pages.roc") (compile templates)
                        |> Task.mapErr \e ->
                            Exit 1 "Error writing file: $(Inspect.toStr e)"

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
