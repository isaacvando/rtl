app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.12.0/Lb8EgiejTUzbggO2HVVuPJFkwvvsfW6LojkLR20kTVE.tar.br",
}

import cli.Stdout
import cli.Task exposing [Task]
import cli.File
import cli.Path exposing [Path]
import cli.Dir
import cli.Arg
import cli.Cmd
import cli.Utc
import Parser
import CodeGen
import cli.Arg
import cli.Arg.Opt as Opt
import cli.Arg.Cli as Cli

main =
    cliParser =
        Cli.build {
            maybeExt: <- Opt.maybeStr { short: "e", long: "ext", help: "Extension of template files -- default is .rtl" },
            maybePath: <- Opt.maybeStr { short: "p", long: "path", help: "Path templates -- default is current directory ./"},
        }
        |> Cli.finish {
            name: "rtl",
            version: "0.2.0",
            authors: ["Isaac Van Doren <https://github.com/isaacvando>"],
            description:
                """
                Welcome to Roc Template Language (RTL)!

                In a directory containing template files, run `rtl` to generate Pages.roc.

                Get the latest version at https://github.com/isaacvando/rtl
                """,
        }
        |> Cli.assertValid

    when Cli.parseOrDisplayMessage cliParser (Arg.list! {}) is
        Ok args -> generate args
        Err errMsg -> Task.err (Exit 1 errMsg)

generate : { maybeExt : Result Str err, maybePath : Result Str err} -> Task {} _
generate = \{ maybeExt, maybePath } ->

    templateExt = maybeExt |> Result.withDefault ".rtl"
    searchDir = maybePath |> Result.withDefault "."

    start = Utc.now!

    info! "Searching for templates in $(searchDir) with extension $(templateExt) ..."
    paths =
        Dir.list searchDir
            |> Task.map \path -> keepTemplates path templateExt
            |> Task.mapErr! \e -> Exit 1 "Error listing directories: $(Inspect.toStr e)"

    invalidTemplateNames =
        List.map paths \p ->
            getFileName p
            |> Str.replaceLast templateExt ""
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

        info! "Reading templates..."

        templates =
            taskAll! paths \path ->
                File.readUtf8 path
                |> Task.map \template -> { path, template }
                |> Task.mapErr \e -> Exit 1 "There was an error reading the templates: $(Inspect.toStr e)"

        if List.isEmpty templates then
            Stdout.line "No templates found in the current directory"
        else

            filePath = "$(searchDir)/Pages.roc"

            info! "Compiling templates..."
            File.writeUtf8 filePath (compile templates templateExt)
                |> Task.mapErr! \e -> Exit 1 "Error writing file: $(Inspect.toStr e)"

            end = Utc.now!

            time = Utc.toMillisSinceEpoch end - Utc.toMillisSinceEpoch start
            info! "Generated $(filePath) in $(time |> Num.toStr)ms"

            rocCheck! filePath

rocCheck : Str -> Task {} _
rocCheck = \filePath ->

    info! "Checking generates $(filePath) for syntax errors..."

    Cmd.new "roc"
    |> Cmd.args ["check", filePath]
    |> Cmd.status
    |> Task.onErr \CmdError err ->
        when err is
            ExitCode code -> Task.err (Exit code "")
            _ -> Task.err (Exit 1 "")

keepTemplates : List Path, Str -> List Str
keepTemplates = \paths, templateExt ->
    paths
    |> List.map Path.display
    |> List.keepIf \str -> Str.endsWith str templateExt

compile : List { path : Str, template : Str }, Str -> Str
compile = \templates, templateExt ->
    templates
    |> List.map \{ path, template } ->
        name =
            getFileName path
            |> Str.replaceLast templateExt ""
        { name, nodes: Parser.parse template }
    |> CodeGen.generate

getFileName : Str -> Str
getFileName = \path ->
    when Str.split path "/" is
        [.., filename] -> filename
        _ -> crash "This is a bug! This case should not happen."

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

info : Str -> Task {} _
info = \msg ->
    Stdout.line! "\u(001b)[34mINFO:\u(001b)[0m $(msg)"
