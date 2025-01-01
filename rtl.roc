app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.18.0/0APbwVN1_p1mJ96tXjaoiUCr8NBGamr8G8Ac_DrXR-o.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.5.1/nqyqbOkpECWgDUMbY-rG9ug883TVbOimHZFHek-bQeI.tar.br",
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
import cli.Arg exposing [Arg]
import weaver.Opt
import weaver.Cli

main! : List Arg => Result {} [Exit I32 Str]_
main! = \args ->

    start = Utc.now! {}

    cliParser : Cli.CliParser { maybeInputDir : _, maybeOutputDir : _, maybeExtension : _ }
    cliParser =
        { Cli.weave <-
            maybeInputDir: Opt.maybe_str { short: "i", long: "input-directory", help: "The directory containing the templates to be compiled. Defaults to the current directory." },
            maybeOutputDir: Opt.maybe_str { short: "o", long: "output-directory", help: "The directory Pages.roc will be written to. Defaults to the current directory." },
            maybeExtension: Opt.maybe_str { short: "e", long: "extension", help: "The extension of the template files the CLI will search for. Defaults to `rtl`." },
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
        |> Cli.assert_valid

    when Cli.parse_or_display_message cliParser args Arg.to_os_raw is
        Err msg -> Stdout.line! msg
        Ok parsedArgs -> generate! parsedArgs start

generate! : { maybeInputDir : Result Str *, maybeOutputDir : Result Str *, maybeExtension : Result Str * }, Utc => Result {} _
generate! = \args, start ->
    inputDir = args.maybeInputDir |> Result.withDefault "."
    outputDir = args.maybeOutputDir |> Result.withDefault "."
    extension = args.maybeExtension |> Result.withDefault "rtl" |> Str.withPrefix "."
    _ = info! "Searching for templates in $(inputDir) with extension $(extension)"
    paths =
        Dir.list! inputDir
        |> Result.map \ps ->
            keepTemplates ps extension
        |> Result.mapErr \e -> error "Could not list directories: $(Inspect.toStr e)"
        |> try

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
        |> Err
        else

    templates =
        mapTry! paths \path ->
            File.read_utf8! path
            |> Result.map \template -> { path, template }
            |> Result.mapErr \e -> error "Could not read the templates: $(Inspect.toStr e)"
        |> try

    if List.isEmpty templates then
        info! "No templates found"
        else

    # If the directory already exists, Dir.createAll will return an error. This is fine, so we continue anyway.
    _ =
        Dir.create_all! outputDir
        |> Result.onErr! \_ -> Ok {}

    filePath = "$(outputDir)/Pages.roc"
    _ = info! "Compiling templates"
    _ =
        File.write_utf8! (compile templates extension) filePath
        |> Result.mapErr \e -> error "Could not write file: $(Inspect.toStr e)"
    time = Utc.delta_as_millis start (Utc.now! {}) |> Num.toStr
    _ = info! "Generated $(filePath) in $(time)ms"

    rocCheck! filePath

rocCheck! : Str => Result {} _
rocCheck! = \filePath ->
    _ = info! "Running `roc check` on $(filePath)"

    Cmd.new "roc"
    |> Cmd.args ["check", filePath]
    |> Cmd.status!
    |> Result.onErr \CmdStatusErr err ->
        when err is
            ExitCode code -> Err (Exit code "")
            _ -> Err (Exit 1 "")
    |> Result.map \_ -> {}

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
    when Str.splitOn path "/" is
        [.., filename] -> filename
        _ -> crash "This is a bug! This case should not happen."

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

info! : Str => Result {} _
info! = \msg ->
    Stdout.line! "\u(001b)[34mINFO:\u(001b)[0m $(msg)"

error : Str -> [Exit (Num *) Str]
error = \msg ->
    Exit 1 "\u(001b)[31mERROR:\u(001b)[0m $(msg)"

mapTry! : List input, (input => Result output error) => Result (List output) error
mapTry! = \list, func! ->
    help! = \remaining, output ->
        when remaining is
            [] -> Ok output
            [first, .. as rest] ->
                result = try func! first
                help! rest (List.append output result)
    help! list []
