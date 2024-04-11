interface Explore
    exposes []
    imports []

parse = \str ->
    when Str.toUtf8 str |> parser2 is
        NoMatch -> crash "No match!"
        Match m -> m.val

expect
    result = parse "foobar"
    result == Conditional { x: "foo", y: "bar" }

# parser1 =
#     const (\x -> \y -> Str.concat x y)
#     |> keep (string "foo")
#     |> skip (string "baz")
#     |> keep (string "bar")

parser2 =
    const {
        x: <- keep (string "foo"),
        y: <- keep (string "bar"),
    }
    |> map Conditional

map = \parser, func ->
    \input ->
        when parser input is
            NoMatch -> NoMatch
            Match { input: in, val } ->
                Match { input: in, val: func val }

string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

const = \val ->
    \input -> Match { input, val }

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

# ID : U32
# Parser state := (ID, state)

# initParser : state -> Parser state
# initParser = \advanceF ->
#     @Parser (0, advanceF)

# # incID : Parser (ID -> state) -> Parser state
# incID = \@Parser (currID, advanceF) ->
#     nextID = currID + 1

#     @Parser (nextID, advanceF nextID)

# extractState : Parser state -> state
# extractState = \@Parser (_, finalState) -> finalState

# expect
#     { aliceID, bobID, trudyID } =
#         initParser {
#             aliceID: <- incID,
#             bobID: <- incID,
#             trudyID: <- incID,
#         }
#         |> extractState

#     aliceID == 1 && bobID == 2 && trudyID == 3
