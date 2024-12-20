module [generate]

import Parser exposing [Node]

generate : List { name : Str, nodes : List Node } -> Str
generate = \templates ->

    functions =
        List.map templates renderTemplate
        |> Str.joinWith "\n\n"

    names =
        templates
        |> List.map \template -> "    $(template.name),"
        |> Str.joinWith "\n"

    imports =
        templates
        |> List.walk (Set.empty {}) \acc, template -> Set.union acc (moduleImports template)
        |> Set.toList
        |> List.map \moduleImport -> "import $(moduleImport)"
        |> Str.joinWith "\n"

    # If we included escapeHtml in every module, templates without interpolations would
    # trigger a warning when running roc check for escapeHtml not being used.
    requiresEscapeHtml = List.any templates \{ nodes } ->
        containsInterpolation nodes

    """
    ## Generated by RTL https://github.com/isaacvando/rtl
    module [
    $(names)
        ]

    $(imports)

    $(functions)
    $(if requiresEscapeHtml then escapeHtml else "")
    """

moduleImports = \template ->
    template.nodes
    |> List.walk (Set.empty {}) \acc, n ->
        when n is
            ModuleImport m -> Set.insert acc m
            _ -> acc

containsInterpolation : List Node -> Bool
containsInterpolation = \nodes ->
    List.any nodes \node ->
        when node is
            Interpolation _ -> Bool.true
            Conditional { trueBranch, falseBranch } ->
                containsInterpolation trueBranch || containsInterpolation falseBranch

            Sequence { body } -> containsInterpolation body
            WhenIs { cases } ->
                List.any cases \case ->
                    containsInterpolation case.branch

            Text _ | RawInterpolation _ | ModuleImport _ -> Bool.false

escapeHtml =
    """

    escapeHtml : Str -> Str
    escapeHtml = \\input ->
        input
        |> Str.replaceEach "&" "&amp;"
        |> Str.replaceEach "<" "&lt;"
        |> Str.replaceEach ">" "&gt;"
        |> Str.replaceEach "\\"" "&quot;"
        |> Str.replaceEach "'" "&#39;"
    """

RenderNode : [
    Text Str,
    Conditional { condition : Str, trueBranch : List RenderNode, falseBranch : List RenderNode },
    Sequence { item : Str, list : Str, body : List RenderNode },
    WhenIs { expression : Str, cases : List { pattern : Str, branch : List RenderNode } },
]

renderTemplate : { name : Str, nodes : List Node } -> Str
renderTemplate = \{ name, nodes } ->
    body =
        condense nodes
        |> renderNodes

    # We check if the model was used in the template so that we can ignore the parameter
    # if it was not used to prevent an unused field warning from showing up.
    """
    $(name) = \\$(if isModelUsedInList nodes then "" else "_")model ->
    $(body)
    """

renderNodes : List RenderNode -> Str
renderNodes = \nodes ->
    when List.map nodes toStr is
        [] -> "\"\"" |> indent
        [elem] -> elem
        blocks ->
            list = blocks |> Str.joinWith ",\n"
            """
            [
            $(list)
            ]
            |> Str.joinWith ""
            """
            |> indent

toStr = \node ->
    block =
        when node is
            Text t ->
                """
                \"""
                $(t)
                \"""
                """

            Conditional { condition, trueBranch, falseBranch } ->
                """
                if $(condition) then
                $(renderNodes trueBranch)
                else
                $(renderNodes falseBranch)
                """

            Sequence { item, list, body } ->
                """
                List.map $(list) \\$(item) ->
                $(renderNodes body)
                |> Str.joinWith ""
                """

            WhenIs { expression, cases } ->
                branches =
                    List.map cases \{ pattern, branch } ->
                        """
                        $(pattern) ->
                        $(renderNodes branch)
                        """
                    |> Str.joinWith "\n"
                    |> indent
                """
                when $(expression) is
                $(branches)

                """
    indent block

condense : List Node -> List RenderNode
condense = \nodes ->
    List.map nodes \node ->
        when node is
            RawInterpolation i -> Text "\$($(i))"
            Interpolation i -> Text "\$($(i) |> escapeHtml)"
            Text t ->
                # Escape Roc string interpolations from the template
                escaped = Str.replaceEach t "$" "\\$"
                Text escaped

            Sequence { item, list, body } -> Sequence { item, list, body: condense body }
            ModuleImport _ -> Text ""
            Conditional { condition, trueBranch, falseBranch } ->
                Conditional {
                    condition,
                    trueBranch: condense trueBranch,
                    falseBranch: condense falseBranch,
                }

            WhenIs { expression, cases } ->
                WhenIs {
                    expression,
                    cases: List.map cases \{ pattern, branch } ->
                        { pattern, branch: condense branch },
                }
    |> List.walk [] \state, elem ->
        when (state, elem) is
            ([.. as rest, Text x], Text y) ->
                combined = Str.concat x y |> Text
                rest |> List.append combined

            _ -> List.append state elem

isModelUsedInList = \nodes ->
    List.any nodes isModelUsedInNode

# We can't determine with full certainty if the model was used without parsing the Roc code that
# is used on the template, which we don't do. This is a heuristic that just checks if any of the spots
# that could reference the model contain "model". So a string literal that contains "model" could create
# a false positive, but this isn't a big deal.
isModelUsedInNode = \node ->
    containsModel = \str ->
        Str.contains str "model"
    when node is
        Interpolation i | RawInterpolation i -> containsModel i
        Conditional { condition, trueBranch, falseBranch } ->
            containsModel condition || isModelUsedInList trueBranch || isModelUsedInList falseBranch

        Sequence { list, body } -> containsModel list || isModelUsedInList body
        WhenIs { expression, cases } ->
            containsModel expression
            || List.any cases \case ->
                isModelUsedInList case.branch

        Text _ | ModuleImport _ -> Bool.false

indent : Str -> Str
indent = \input ->
    Str.splitOn input "\n"
    |> List.map \str ->
        Str.concat "    " str
    |> Str.joinWith "\n"
