## Generated by RTL https://github.com/isaacvando/rtl
module [
    template,
    ]

import Math

template = \model ->
    [
        """
        <!DOCTYPE html>
        <html lang="en">
        
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Document Title</title>
            <link rel="stylesheet" href="styles.css">
        </head>
        <body>
            <h1>Page Title</h1>
            <ol>
            
        """,
        List.map model.items \item ->
            """
            
                <li>$(item |> escapeHtml)</li>
                
            """
        |> Str.joinWith "",
        """
        
            </ol>
        
            
        """,
        if model.condition then
            """
            
                True
                
            """
        else
            """
            
                False
                
            """,
        """
        
        
            
        """,
        if !model.condition || Bool.false then
            """
            
                $(Inspect.toStr model.condition |> escapeHtml)
                
            """
        else
            "",
        """
        
        
            <p>Module calculation: $(Math.add 123 345 |> Num.toStr |> escapeHtml)</p>
        
            
        """,
        when model.animal is
            Dog "fido" ->
                """
                 Hello Fido
                    
                """
            Cat {name: "Gob", age} ->
                """
                 Hello Gob, Age: $(Num.toStr age |> escapeHtml)
                    
                """
            _ ->
                """
                 Sorry, don't know that animal
                    
                """
        ,
        """
        
        
            $("<p>Raw interpolation test</p>")
        </body>
        </html>
        
        """
    ]
    |> Str.joinWith ""

escapeHtml : Str -> Str
escapeHtml = \input ->
    input
    |> Str.replaceEach "&" "&amp;"
    |> Str.replaceEach "<" "&lt;"
    |> Str.replaceEach ">" "&gt;"
    |> Str.replaceEach "\"" "&quot;"
    |> Str.replaceEach "'" "&#39;"