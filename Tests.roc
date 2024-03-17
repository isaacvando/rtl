interface Tests
    imports [Parser.parse]
    exposes []

expect 
    result = parse "foo"
    result.nodes = [Text ]