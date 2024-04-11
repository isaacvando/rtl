interface Explore
    exposes []
    imports []

parse = \str ->
    when Str.toUtf8 str |> parser is
        NoMatch -> crash "No match!"
        Match m -> m.val

expect
    result = parse "foobazbar"
    result == "foobar"

parser =
    const (\x -> \y -> Str.concat x y)
    |> keep (string "foo")
    |> skip (string "baz")
    |> keep (string "bar")

parser2 =
    const {
        x: <- keep (string "foo"),
        y: <- keep (string "bar"),
    }
    |> extract

extract = \parser ->
    \input ->
        when parser input is
            NoMatch -> NoMatch
            Match { input: in, val: { x, y } } -> Match { input: in, val: Str.concat x y }

string = \str ->
    \input ->
        bytes = Str.toUtf8 str
        if List.startsWith input bytes then
            Match { input: List.dropFirst input (List.len bytes), val: str }
        else
            NoMatch

const = \val ->
    \input -> Match { input, val }

keep = \funParser, valParser ->
    \input ->
        when funParser input is
            NoMatch -> NoMatch
            Match { val: funVal, input: rest } ->
                when valParser rest is
                    NoMatch -> NoMatch
                    Match { val, input: rest2 } ->
                        Match { val: funVal val, input: rest2 }

skip = \funParser, skipParser ->
    \input ->
        when funParser input is
            NoMatch -> NoMatch
            Match { val: funVal, input: rest } ->
                when skipParser rest is
                    NoMatch -> NoMatch
                    Match { val: _, input: rest2 } -> Match { val: funVal, input: rest2 }

ID : U32

IDCount state := (ID, state)

initIDCount : state -> IDCount state
initIDCount = \advanceF ->
    @IDCount (0, advanceF)

incID : IDCount (ID -> state) -> IDCount state
incID = \@IDCount (currID, advanceF) ->
    nextID = currID + 1

    @IDCount (nextID, advanceF nextID)

extractState : IDCount state -> state
extractState = \@IDCount (_, finalState) -> finalState

expect
    { aliceID, bobID, trudyID } =
        initIDCount {
            aliceID: <- incID,
            bobID: <- incID,
            trudyID: <- incID,
        }
        |> extractState

    aliceID == 1 && bobID == 2 && trudyID == 3
