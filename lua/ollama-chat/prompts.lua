local prompts = {}
local response_format = "Respond EXACTLY in this format:\n```$ftype\n<your code>\n```"

function prompts.generate_prompts(model, model_code, user_prompts)
  if model_code == nil then
    model_code = model
  end
  local prompts_table = {

    -- code based prompts
    Ask_about_code = {
      prompt = "$input",
      model = model_code,
    },

    Explain_code = {
      prompt = "Explain this code:\n```$ftype\n$sel\n```",
      model = model_code,
    },

    Modify_code = {
      prompt = "Modify this $ftype code in the following way: $input\n\n"
        .. response_format
        .. "\n\n```$ftype\n$sel```",
      model = model_code,
    },

    Generate_code = {
      prompt = "Generate $ftype code that does the following: $input\n\n"
        .. response_format,
      model = model_code,
    },

    Generate_code_selection_context = {
      prompt = "Generate $ftype code that does the following: $input\n"
        .. "Here's the context of the code: $sel\n"
        .. response_format,
      model = model_code,
    },


    Generate_code_buffer_context = {
      prompt = "Generate $ftype code that does the following: $input\n"
        .. "Here's the context of the whole code: $buf\n"
        .. response_format,
      model = model_code,
    },

    -- text based prompts
    Ask = {
      prompt = "$input",
      model = model,
    },

    Explain_text = {
      prompt = "Explain this text:\n\n$sel",
      model = model,
    },

    Simplify_text = {
      prompt = "Simplify the following text so that it is both easier to read and understand. "
        .. "\n\n$sel",
      model = model,
    },

    Modify_text = {
      prompt = "Modify this text in the following way: $input\n\n$sel",
      model = model,
    },

    About_selection = {
      prompt = "Regarding the following text, $input:\n$sel",
      model = model,
    },

    Prompt_with_selection = {
      prompt = "$sel",
      model = model,
    },
    Synonyms = {
      prompt = "Please suggest a list of synonyms for the word '$sel' as a list. "
        .. "If the word can be a noun or a verb, please provide both. "
        .. "Also if the word can be used in different contexts, please provide "
        .. "synonyms for each context.",
      model = model,
    },
    Define = {
      prompt = "Give the definition of '$sel' as a list. "
        .. "If the word can be a noun, adjective or verb, please provide "
        .. "meanings for all in the form of separate lists. "
        .. "Also if the word can be used in different contexts, please provide "
        .. "definitions for each context and follow them up with examples.",
      model = model,
    },
    Change = {
      prompt = "Change the following text, $input. \n "
        .. "Just output the final text without additional quotes around it:\n"
        .. "$sel",
      model = model,
    },
    Enhance_grammar_spelling = {
      prompt = "Modify the following text to improve grammar and spelling, "
        .. "just output the final text without additional quotes around it:\n$sel",
      model = model,
    },

    Enhance_wording = {
      prompt = [[
          Modify the following text to use better wording, just output
          the final text without additional quotes around it:\n$sel
          ]],
      model = model,
    },

    Rephrase = {
      prompt = "Rephrase the following text so that the message is kept "
        .. "intact but the wording is changed to be more clear, just output "
        .. "the final text without additional quotes around it:\n$sel",
      model = model,
    },

    Make_concise = {
      prompt = "Modify the following text to make it as simple and concise "
        .. "as possible, just output the final text without additional quotes "
        .. "around it:\n$sel",
      model = model,
    },

    Make_list = {
      prompt = "Render the following text as a markdown list:\n$sel",
      model = model,
    },

    Generate_Text = {
      prompt = "Generate text with the following instructions: $input\n\n",
      model = model,
    },

    Generate_text_buffer_context = {
      prompt = "Generate text $input.\nHere's the context of the whole text: $buf",
      model = model,
    },

    Generate_text_selection_context = {
      prompt = "Generate text $input.\nHere's the context: $sel",
      model = model,
    },


    -- chat prompts
    Chat = {
      prompt = "$buf\n",
      action = "chat",
      model = model,
    },

    Chat_Code = {
      prompt = "$buf\n",
      action = "chat",
      model = model_code,
    },

  }
  prompts_table = vim.tbl_deep_extend("force", prompts_table, user_prompts or {})

  return prompts_table
end

return prompts
