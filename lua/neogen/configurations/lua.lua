local common_function_extractor = function(node)
    local tree = {
        {
            retrieve = "first",
            node_type = "parameters",
            subtree = {
                { retrieve = "all", node_type = "identifier", extract = true },
                { retrieve = "all", node_type = "spread", extract = true },
            },
        },
        { retrieve = "first", node_type = "return_statement", extract = true },
    }

    local nodes = neogen.utilities.nodes:matching_nodes_from(node, tree)
    local res = neogen.utilities.extractors:extract_from_matched(nodes)

    return {
        parameters = res.identifier,
        vararg = res.spread,
        return_statement = res.return_statement,
    }
end

local extract_from_var = function(node)
    local tree = {
        {
            retrieve = "first",
            node_type = "variable_declarator",
            subtree = {
                { retrieve = "first", node_type = "identifier", extract = true },
                { retrieve = "first", node_type = "field_expression", extract = true },
            },
        },
        {
            position = 2,
            extract = true,
        },
    }
    local nodes = neogen.utilities.nodes:matching_nodes_from(node, tree)
    return nodes
end

return {
    -- Search for these nodes
    parent = {
        func = { "function", "local_function", "local_variable_declaration", "field", "variable_declaration" },
        class = { "local_variable_declaration", "variable_declaration" },
        type = { "local_variable_declaration", "variable_declaration" },
    },

    data = {
        func = {
            -- When the function is inside one of those
            ["local_variable_declaration|field|variable_declaration"] = {
                ["2"] = {
                    match = "function_definition",

                    extract = common_function_extractor,
                },
            },
            -- When the function is in the root tree
            ["function_definition|function|local_function"] = {
                ["0"] = {

                    extract = common_function_extractor,
                },
            },
        },
        class = {
            ["local_variable_declaration|variable_declaration"] = {
                ["0"] = {
                    extract = function(node)
                        local nodes = extract_from_var(node)
                        local res = neogen.utilities.extractors:extract_from_matched(nodes)
                        return {
                            class_name = res.identifier,
                        }
                    end,
                },
            },
        },
        type = {
            ["local_variable_declaration|variable_declaration"] = {
                ["0"] = {
                    extract = function(node)
                        local result = {}
                        result.type = {}

                        local nodes = extract_from_var(node)
                        local res = neogen.utilities.extractors:extract_from_matched(nodes, { type = true })

                        -- We asked the extract_from_var function to find the type node at right assignment.
                        -- We check if it found it, or else will put `any` in the type
                        if res["_"] then
                            vim.list_extend(result.type, res["_"])
                        else
                            if res.identifier or res.field_expression then
                                vim.list_extend(result.type, { "any" })
                            end
                        end
                        return result
                    end,
                },
            },
        },
    },

    -- Custom lua locator that escapes from comments
    locator = require("neogen.locators.lua"),

    -- Use default granulator and generator
    granulator = nil,
    generator = nil,

    template = {
        -- Which annotation convention to use
        annotation_convention = "emmylua",
        emmylua = {
            { nil, "- $1", { type = { "class", "func" } } }, -- add this string only on requested types
            { nil, "- $1", { no_results = true } }, -- Shows only when there's no results from the granulator
            { "parameters", "- @param %s $1|any" },
            { "vararg", "- @vararg $1|any" },
            { "return_statement", "- @return $1|any" },
            { "class_name", "- @class $1|any" },
            { "type", "- @type %s $1" },
        },
    },
}
