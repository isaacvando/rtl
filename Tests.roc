interface Tests
    exposes []
    imports [Parser.{ parse }]

expect
    result = parse "foo"
    result == { nodes: [Text "foo"], args: [] }

expect
    result = parse "<p>{{name}}</p>"
    result == { nodes: [Text "<p>", Interpolation "name", Text "</p>"], args: ["name"] }
