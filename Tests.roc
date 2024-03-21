interface Tests
    exposes []
    imports [Parser.{ parse }]

expect
    result = parse "foo"
    result == [Text "foo"]

expect
    result = parse "<p>{{name}}</p>"
    result == [Text "<p>", Interpolation "name", Text "</p>"]

expect
    result = parse "{{foo}bar}}"
    result == [Interpolation "foo}bar"]

expect
    result = parse "{{func arg1 arg2 |> func2 arg2}}"
    result == [Interpolation "func arg1 arg2 |> func2 arg2"]

expect
    result = parse "{|if x > y |}foo{|endif|}"
    result == [Conditional { condition: "x > y", body: [Text "foo"] }]

expect
    result = parse
        """
        {|if x > y |}
        foo
        {|endif|}
        """
    result == [Conditional { condition: "x > y", body: [Text "\nfoo\n"] }]

expect
    result = parse
        """
        {|if model.someField |}
        {|if Bool.false |}
        bar
        {|endif|}
        {|endif|}
        """
    result
    == [
        Conditional {
            condition: "model.someField",
            body: [
                Text "\n",
                Conditional { condition: "Bool.false", body: [Text "\nbar\n"] },
                Text "\n",
            ],
        },
    ]
