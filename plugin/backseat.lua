-- Automatically executed on startup
if vim.g.loaded_backseat then
    return
end
vim.g.loaded_backseat = true

require("backseat").setup()
local fewshot = require("backseat.fewshot")

local model = "gpt-4" -- gpt-3.5-turbo

local function print(msg)
    _G.print("Backseat > " .. msg)
end

local function getAPIKey()
    local api_key = vim.g.openai_api_key
    if api_key == nil then
        print("No API key found. Please set g:openai_api_key")
        return nil
    end
    return api_key
end

local function gpt_request(dataJSON)
    local api_key = getAPIKey()
    if api_key == nil then
        return nil
    end
    local curlRequest = string.format(
        "curl -s https://api.openai.com/v1/chat/completions -H \"Content-Type: application/json\" -H \"Authorization: Bearer " ..
        api_key .. "\" -d '" .. dataJSON .. "'"
    )
    -- print(curlRequest)

    local response = vim.fn.system(curlRequest)
    local success, responseTable = pcall(vim.json.decode, response)

    if success == false or responseTable == nil then
        print("Bad or no response: " .. response)
        return nil
    end

    if responseTable.error ~= nil then
        print("OpenAI Error: " .. responseTable.error.message)
        return nil
    end

    -- print(response)
    return responseTable
end

local function parseResponse(response)
    print("AI Says: " .. response.choices[1].message.content)
end

-- Set up the API key
-- vim.api.nvim_create_user_command("BackseatAuthKey", function(opt)
--     -- local bufnr = tonumber(opt.args)
--     -- require("ccc.highlighter"):enable(bufnr)
-- end, { nargs = "?" })

-- Use the underlying chat API to ask a question about the current buffer's code
vim.api.nvim_create_user_command("BackseatAsk", function(opts)
    local response = gpt_request(vim.json.encode(
        {
            model = model,
            messages = { {
                role = "user",
                content = opts.args
            } },
        }
    ))

    if response == nil then
        return nil
    end
    print("AI Says: " .. response.choices[1].message.content)
end, {})

-- Send the current buffer to the AI for readability feedback
vim.api.nvim_create_user_command("Backseat", function()
    -- print("Backseat setup: " .. vim.inspect(vim.g.loaded_backseat))

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local text = table.concat(lines, "\n")

    local requestTable = {
        model = model,
        messages = fewshot.messages
    }

    -- Add the current buffer to the request
    table.insert(requestTable.messages, {
        role = "user",
        content = text
    })

    local requestJSON = vim.json.encode(requestTable)

    local responseTable = gpt_request(requestJSON)
    if responseTable == nil then
        return nil
    end

    -- local response = vim.fn.json_decode([[
    -- {
    --   "id": "chatcmpl-<id>",
    --   "object": "chat.completion",
    --   "created": 1680192412,
    --   "model": "gpt-3.5-turbo-0301",
    --   "usage": {
    --     "prompt_tokens": 10,
    --     "completion_tokens": 9,
    --     "total_tokens": 19
    --   },
    --   "choices": [
    --     {
    --       "message": {
    --         "role": "assistant",
    --         "content": "Hello! How can I assist you today?"
    --       },
    --       "finish_reason": "stop",
    --       "index": 0
    --     }
    --   ]
    -- }]])

    parseResponse(responseTable)

    -- require("backseat.main"):run()
end, {})
