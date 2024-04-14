app "server"
    packages { pf: "https://github.com/roc-lang/basic-webserver/releases/download/0.3.0/gJOTXTeR3CD4zCbRqK7olo4edxQvW5u3xGL-8SSxDcY.tar.br" }
    imports [
        pf.Task.{ Task },
        pf.Http.{ Request, Response },
        Pages,
    ]
    provides [main] to pf

main = \req ->
    when Str.split req.url "/" |> List.dropFirst 1 is
        ["first"] ->
            Pages.base {
                content: Pages.first {
                    foo: "very nice string",
                },
            }
            |> success

        ["second"] ->
            Pages.base {
                content: Pages.second {
                    bar: 100,
                },
            }
            |> success

        _ -> notFound

notFound = Task.ok {
    status: 404,
    headers: [],
    body: [],
}

success = \body ->
    Task.ok {
        status: 200,
        headers: [Http.header "Content-Type" "text/html"],
        body: body |> Str.toUtf8,
    }
