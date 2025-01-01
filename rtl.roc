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

    cli_parser : Cli.CliParser { input_dir : _, output_dir : _, extensionWithoutDot : _ }
    cli_parser =
        { Cli.weave <-
            input_dir: Opt.str { short: "i", long: "input-directory", help: "The directory containing the templates to be compiled. Defaults to the current directory.", default: Value "." },
            output_dir: Opt.str { short: "o", long: "output-directory", help: "The directory Pages.roc will be written to. Defaults to the current directory.", default: Value "." },
            extensionWithoutDot: Opt.str { short: "e", long: "extension", help: "The extension of the template files the CLI will search for. Defaults to `rtl`.", default: Value "rtl" },
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

    when Cli.parse_or_display_message cli_parser args Arg.to_os_raw is
        Err msg -> Stdout.line! msg
        Ok parsedArgs -> generate! parsedArgs start

generate! : { input_dir : Str, output_dir : Str, extensionWithoutDot : Str }, Utc => Result {} _
generate! = \{ input_dir, output_dir, extensionWithoutDot }, start ->
    extension = extensionWithoutDot |> Str.withPrefix "."
    _ = info! "Searching for templates in $(input_dir) with extension $(extension)"
    paths =
        Dir.list! input_dir
        |> Result.map \ps ->
            keep_templates ps extension
        |> Result.mapErr \e -> error "Could not list directories: $(Inspect.toStr e)"
        |> try

    invalid_template_names =
        List.map paths \p ->
            get_file_name p
            |> Str.replaceLast extension ""
        |> List.dropIf is_valid_function_name

    if !(List.isEmpty invalid_template_names) then
        error
            """
            The following templates have invalid names: $(invalid_template_names |> Str.joinWith ", ")
            Each template must start with a lowercase letter and only contain letters and numbers.
            """
        |> Err
        else

    templates =
        map_try! paths \path ->
            File.read_utf8! path
            |> Result.map \template -> { path, template }
            |> Result.mapErr \e -> error "Could not read the templates: $(Inspect.toStr e)"
        |> try

    if List.isEmpty templates then
        info! "No templates found"
        else

    # If the directory already exists, Dir.create_all! will return an error. This is fine, so we continue anyway.
    _ =
        Dir.create_all! output_dir
        |> Result.onErr! \_ -> Ok {}

    file_path = "$(output_dir)/Pages.roc"
    _ = info! "Compiling templates"
    _ =
        File.write_utf8! (compile templates extension) file_path
        |> Result.mapErr \e -> error "Could not write file: $(Inspect.toStr e)"
    time = Utc.delta_as_millis start (Utc.now! {}) |> Num.toStr
    _ = info! "Generated $(file_path) in $(time)ms"

    roc_check! file_path

roc_check! : Str => Result {} _
roc_check! = \file_path ->
    _ = info! "Running `roc check` on $(file_path)"

    Cmd.new "roc"
    |> Cmd.args ["check", file_path]
    |> Cmd.status!
    |> Result.onErr \CmdStatusErr err ->
        when err is
            ExitCode code -> Err (Exit code "")
            _ -> Err (Exit 1 "")
    |> Result.map \_ -> {}

keep_templates : List Path, Str -> List Str
keep_templates = \paths, extension ->
    paths
    |> List.map Path.display
    |> List.keepIf \str -> Str.endsWith str extension

compile : List { path : Str, template : Str }, Str -> Str
compile = \templates, extension ->
    templates
    |> List.map \{ path, template } ->
        name =
            get_file_name path
            |> Str.replaceLast extension ""
        { name, nodes: Parser.parse template }
    |> CodeGen.generate

get_file_name : Str -> Str
get_file_name = \path ->
    when Str.splitOn path "/" is
        [.., filename] -> filename
        _ -> crash "This is a bug! This case should not happen."

is_valid_function_name : Str -> Bool
is_valid_function_name = \str ->
    bytes = Str.toUtf8 str
    when bytes is
        [first, .. as rest] if 97 <= first && first <= 122 ->
            List.all rest isAlphaNumeric

        _ -> Bool.false

expect is_valid_function_name "fooBar"
expect is_valid_function_name "a"
expect is_valid_function_name "abc123"
expect is_valid_function_name "123four" |> Bool.not
expect is_valid_function_name "snake_case" |> Bool.not
expect is_valid_function_name "punctuation!" |> Bool.not

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

map_try! : List input, (input => Result output error) => Result (List output) error
map_try! = \list, func! ->
    help! = \remaining, output ->
        when remaining is
            [] -> Ok output
            [first, .. as rest] ->
                result = try func! first
                help! rest (List.append output result)
    help! list []
