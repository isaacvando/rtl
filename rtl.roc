app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
}

import cli.Stdout
import cli.File
import cli.Path exposing [Path]
import cli.Dir
import cli.Arg
import cli.Cmd
import cli.Utc exposing [Utc]
import Parser
import CodeGen
import cli.Arg
import cli.Arg.Opt as Opt
import cli.Arg.Cli as Cli

main : Task {} [Exit I32 Str]_
main =

    start = Utc.now! {}

    cliParser : Cli.CliParser { maybeInputDir : _, maybeOutputDir : _, maybeExtension : _ }
    cliParser =
        { Cli.combine <-
            maybeInputDir: Opt.maybeStr { short: "i", long: "input-directory", help: "The directory containing the templates to be compiled. Defaults to the current directory." },
            maybeOutputDir: Opt.maybeStr { short: "o", long: "output-directory", help: "The directory Pages.roc will be written to. Defaults to the current directory." },
            maybeExtension: Opt.maybeStr { short: "e", long: "extension", help: "The extension of the template files the CLI will search for. Defaults to `rtl`." },
        }
        |> Cli.finish {
            name: "rtl",
            version: "0.2.0",
            authors: ["Isaac Van Doren <https://github.com/isaacvando>"],
            description:
            """
            Welcome to Roc Template Language (RTL)!

            In a directory containing template files, run `rtl` to generate Pages.roc. Then import Pages to use your templates.

            Get the latest version at https://github.com/isaacvando/rtl.
            """,
        }
        |> Cli.assertValid

    args =
        Cli.parseOrDisplayMessage cliParser (Arg.list! {})
            |> Task.fromResult
            |> Task.mapErr! error

    generate! args start

generate : { maybeInputDir : Result Str *, maybeOutputDir : Result Str *, maybeExtension : Result Str * }, Utc -> Task {} _
generate = \args, start ->
    inputDir = args.maybeInputDir |> Result.withDefault "."
    outputDir = args.maybeOutputDir |> Result.withDefault "."
    extension = args.maybeExtension |> Result.withDefault "rtl" |> Str.withPrefix "."
    info! "Searching for templates in $(inputDir) with extension $(extension)"
    paths =
        Dir.list inputDir
            |> Task.map \paths ->
                keepTemplates paths extension
            |> Task.mapErr! \e -> error "Could not list directories: $(Inspect.toStr e)"

    invalidTemplateNames =
        List.map paths \p ->
            getFileName p
            |> Str.replaceLast extension ""
        |> List.dropIf isValidFunctionName

    if !(List.isEmpty invalidTemplateNames) then
        error
            """
            The following templates have invalid names: $(invalidTemplateNames |> Str.joinWith ", ")
            Each template must start with a lowercase letter and only contain letters and numbers.
            """
        |> Task.err
    else
        templates =
            taskAll! paths \path ->
                File.readUtf8 path
                |> Task.map \template -> { path, template }
                |> Task.mapErr \e -> error "Could not read the templates: $(Inspect.toStr e)"

        if List.isEmpty templates then
            info! "No templates found"
        else
            # If the directory already exists, Dir.createAll will return an error. This is fine, so we continue anyway.
            Dir.createAll outputDir
                |> Task.onErr! \_ -> Task.ok {}

            filePath = "$(outputDir)/Pages.roc"
            info! "Compiling templates"
            File.writeUtf8 filePath (compile templates extension)
                |> Task.mapErr! \e -> error "Could not write file: $(Inspect.toStr e)"
            time = Utc.deltaAsMillis start (Utc.now! {}) |> Num.toStr
            info! "Generated $(filePath) in $(time)ms"

            rocCheck! filePath

rocCheck : Str -> Task {} _
rocCheck = \filePath ->
    info! "Running `roc check` on $(filePath)"

    Cmd.new "roc"
    |> Cmd.args ["check", filePath]
    |> Cmd.status
    |> Task.onErr \CmdError err ->
        when err is
            ExitCode code -> Task.err (Exit code "")
            _ -> Task.err (Exit 1 "")

keepTemplates : List Path, Str -> List Str
keepTemplates = \paths, extension ->
    paths
    |> List.map Path.display
    |> List.keepIf \str -> Str.endsWith str extension

compile : List { path : Str, template : Str }, Str -> Str
compile = \templates, extension ->
    templates
    |> List.map \{ path, template } ->
        name =
            getFileName path
            |> Str.replaceLast extension ""
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

error : Str -> [Exit (Num *) Str]
error = \msg ->
    Exit 1 "\u(001b)[31mERROR:\u(001b)[0m $(msg)"
