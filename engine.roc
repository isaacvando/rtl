app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Path,
        pf.File,
        Parser.{ Ir },
        "page.htmr" as template : List U8,
    ]
    provides [main] to pf

main =
    File.writeUtf8 (Path.fromStr "Pages.roc") (compile template)
    |> Task.onErr \e ->
        Stdout.line "Error writing file: $(Inspect.toStr e)"
    |> Task.await \_ -> 
        Stdout.line "Generated Pages.roc"

compile : List U8 -> Str
compile = \temp ->
    Parser.parse temp
    |> generate

generate : Ir -> Str
generate = \ir ->
    body = List.walk ir [] \state, elem ->
        when elem is
            Text t -> List.concat state t
            Interpolation i ->
                List.join [state, ['$', '('], i, [')']]
        
    """
    interface Pages
        exposes [page]
        imports []

    page = \\{ $(getArgsFromIr ir |> Str.joinWith ", ") } ->
        \"""
    $(body |> Str.fromUtf8 |> unwrap |> indent)\"""
        
    """

# TODO: this needs to handle nested fields like foo.bar
getArgsFromIr : Ir -> List Str
getArgsFromIr = \ir -> 
    List.walk ir (Set.empty {}) \args, node -> 
        when node is
            Interpolation i -> 
                str = Str.fromUtf8 i |> unwrap
                Set.union args (getArgsFromStr str)
            Text _ -> args
    |> Set.toList

# TODO: this should only accept identifiers, and should be aware of strings and string interpolations
getArgsFromStr : Str -> Set Str
getArgsFromStr = \str -> 
    Str.split str " "
    |> List.keepIf \s -> 
        isAlphaNumeric s && containsAlpha s
    |> Set.fromList

containsAlpha : Str -> Bool
containsAlpha = \str -> 
    Str.toUtf8 str
    |> List.any \c -> 
        (65 <= c && c<= 90)
        || (97 <= c && c <= 122)

isAlphaNumeric : Str -> Bool
isAlphaNumeric = \str -> 
    Str.toUtf8 str
    |> List.all \c -> 
        (48 <= c && c <= 57)
        || (65 <= c && c<= 90)
        || (97 <= c && c <= 122)

indent = \in ->
    Str.split in "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"


unwrap = \x ->
    when x is
        Err _ -> crash "bad unwrap"
        Ok v -> v
