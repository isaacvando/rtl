app "server"
    packages { pf: "https://github.com/roc-lang/basic-webserver/releases/download/0.3.0/gJOTXTeR3CD4zCbRqK7olo4edxQvW5u3xGL-8SSxDcY.tar.br" }
    imports [
        pf.Task.{ Task },
        pf.Http.{ Request, Response },
        Pages,
        "favicon.svg" as favicon : List U8,
    ]
    provides [main] to pf

main : Request -> Task Response []
main = \req ->
    when Str.split req.url "/" is
        _ ->
            body =
                Pages.page {
                    name: "<p href=\"foo\">hello</p>",
                    username: "isaacvando",
                    names: ["Ashley", "Tony", "another one!!", "fooname"],
                }
                |> Str.concat (Pages.hello 123)
                |> Str.toUtf8
            Task.ok { status: 200, headers: [Http.header "Content-Type" "text/html"], body }
