# Template

## Design
- First we parse the template into a list of nodes, each node being unstructured text, a conditional, an interpolation, or a list. 
- We then take that list of nodes and from it generate a normal Roc function which is then called to generate the output. 
    - The function accepts a single argument called `model`. Normally it is be a record, and fields on it are accessed in the template like this: `Hello, {{model.name}}!`, although it could be another type.
- `engine.roc` compiles the template (`page.htmr`) to a function called `page` in `Pages.roc`. `Parser.roc` handles the parsing.


    
    
    
    
    
## Other options considered
- Originally, I wanted the function to take a destructured record (`page = \{name, email} ->`) so that fields could be accessed directly in the template without having to prefix them with `model`. To do this we would have to identify each field being used in the template. This should be a doable, but I don't think it is worth increasing the scope of the chapter to do it.