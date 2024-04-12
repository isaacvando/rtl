interface Explore
    exposes []
    imports []

parse = \str, parser ->
    when Str.toUtf8 str |> parser is
        NoMatch -> crash "No match!"
        Match m -> m.val

expect
    result = "foobar" |> parse parser2
    result == Conditional { x: "foo", y: "bar" }

expect
    result = "foofoo" |> parse parser3
    result == { x: ["foo", "foo"] }

Parser a : List U8 -> [Match { input : List U8, val : a }, NoMatch]
ApParser val state : Parser (val -> state) -> Parser state

# parser1 =
#     const (\x -> \y -> Str.concat x y)
#     |> keep (string "foo")
#     |> skip (string "baz")
#     |> keep (string "bar")

parser2 =
    const {
        x: <- string "foo" |> keep,
        y: <- string "bar" |> keep,
    }
    |> map Conditional

parser3 =
    const {
        x: <- many (string "foo") |> keep,
    }

map = \parser, func ->
    \input ->
        when parser input is
            NoMatch -> NoMatch
            Match { input: in, val } ->
                Match { input: in, val: func val }

many : Parser a -> Parser (List a)
# many = \parser ->

string : Str -> Parser Str
string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

const = \val ->
    \input -> Match { input, val }

keep : Parser a -> (Parser (a -> b) -> Parser b)
keep = \valParser -> \funParser ->
        \input ->
            when funParser input is
                NoMatch -> NoMatch
                Match { val: funVal, input: rest } ->
                    when valParser rest is
                        NoMatch -> NoMatch
                        Match { val, input: rest2 } ->
                            Match { val: funVal val, input: rest2 }

skip = \skipParser -> \funParser ->
        \input ->
            when funParser input is
                NoMatch -> NoMatch
                Match { val: funVal, input: rest } ->
                    when skipParser rest is
                        NoMatch -> NoMatch
                        Match { val: _, input: rest2 } -> Match { val: funVal, input: rest2 }
