app [Model, respond!, init!] { pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.11.0/yWHkcVUt_WydE1VswxKFmKFM5Tlu9uMn6ctPVYaas7I.tar.br" }

import Pages

Model : {}

init! = \{} -> Ok {}

respond! = \req, _ ->
    when Str.splitOn req.uri "/" |> List.dropFirst 1 is
        ["posts", slug] ->
            post =
                List.findFirst posts \p ->
                    p.slug == slug
                |> try
            Pages.blogPost {
                post,
            }
            |> success

        [""] | _ ->
            Pages.home { posts } |> success

posts = [
    {
        title: "How to write a template engine in Roc",
        slug: "template-engine",
        content: [Text "Roc's type inference shines through here. It makes it easy to write a template language with compile time errors while having the same feel as dynamic languages."],
    },
    {
        title: "My story: thinking of blog ideas for this example",
        slug: "my-story",
        content: [Text "What follows is a code block:", Code "[1,2,3] |> List.map \\x -> x * x"],
    },
    {
        title: "The last blog post",
        slug: "fin",
        content: [Text "Here's an image", Image "https://www.roc-lang.org/favicon.svg"],
    },
]

success = \body ->
    Ok {
        status: 200,
        headers: [{ name: "Content-Type", value: "text/html" }],
        body: body |> Str.toUtf8,
    }
