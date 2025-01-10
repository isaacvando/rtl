app [Model, respond!, init!] { pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.11.0/yWHkcVUt_WydE1VswxKFmKFM5Tlu9uMn6ctPVYaas7I.tar.br" }

import Pages

Model : {}

init! = \{} -> Ok {}

respond! = \req, _ ->
    when Str.splitOn req.uri "/" |> List.dropFirst 1 is
        ["first"] ->
            Pages.base {
                content: Pages.first {
                    foo: "very nice string",
                },
            }
            |> success

        ["second"] | _ ->
            Pages.base {
                content: Pages.second {
                    bar: 100,
                },
            }
            |> success

success = \body ->
    Ok {
        status: 200,
        headers: [{ name: "Content-Type", value: "text/html" }],
        body: body |> Str.toUtf8,
    }
