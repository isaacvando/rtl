interface Tests
    exposes []
    imports [Parser.{ parse }]

expect
    result = parse "foo"
    result == { nodes: [Text "foo"], args: Set.fromList [] }

expect
    result = parse "<p>{{name}}</p>"
    result == { nodes: [Text "<p>", Interpolation "name", Text "</p>"], args: Set.fromList ["name"] }

expect
    result = parse "{{foo}bar}}"
    result.nodes == [Interpolation "foo}bar"]

expect
    result = parse "{{func arg1 arg2 |> func2 arg2}}"
    result.nodes
    == [Interpolation "func arg1 arg2 |> func2 arg2"]
    && result.args
    == Set.fromList ["func", "arg1", "arg2", "func2"]

expect
    result = parse "{|if x > y |}foo{|endif|}"
    result.nodes
    == [Conditional { condition: "x > y", body: "foo" }]
    && result.args
    == Set.fromList ["x", "y", "foo"]
