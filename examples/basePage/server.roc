app [Model, server] { pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.9.0/taU2jQuBf-wB8EJb0hAkrYLYOGacUU5Y9reiHG45IY4.tar.br" }

import pf.Http
import Pages

Model : {}

server = { init: Task.ok {}, respond }

respond = \req, _ ->
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
