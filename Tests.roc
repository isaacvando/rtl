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
    result == [Conditional { condition: "x > y", body: [Text "foo"] }]

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
                Conditional { condition: "Bool.false", body: [Text "bar"] },
            ],
        },
    ]

expect
    result = parse
        """
        foo
        bar
        {{model.baz}}
        foo
        """
    result == [Text "foo\nbar\n", Interpolation "model.baz", Text "\nfoo"]

expect
    result = parse
        """
        <p>
            {|if foo |}
            bar
            {|endif|}
        </p>
        """
    result
    == [
        Text "<p>\n    ",
        Conditional { condition: "foo", body: [Text "bar\n    "] },
        Text "</p>",
    ]

expect
    result = parse
        """
        <div>{|if model.username == "isaac" |}Hello{|endif|}</div>
        """
    result
    ==
    [
        Text "<div>",
        Conditional { condition: "model.username == \"isaac\"", body: [Text "Hello"] },
        Text "</div>",
    ]
