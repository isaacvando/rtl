app "server"
    packages { pf: "https://github.com/roc-lang/basic-webserver/releases/download/0.3.0/gJOTXTeR3CD4zCbRqK7olo4edxQvW5u3xGL-8SSxDcY.tar.br" }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
        pf.Http.{ Request, Response },
        pf.Utc,
        Pages,
    ]
    provides [main] to pf

main : Request -> Task Response []
main = \req ->
    body = Pages.page |> Str.toUtf8
    Task.ok { status: 200, headers: [], body}
