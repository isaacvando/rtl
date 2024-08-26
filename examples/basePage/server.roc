# TODO replace with builtin Task latest release
app [Model, server] { pf: platform "../../../basic-webserver/platform/main.roc" }

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
