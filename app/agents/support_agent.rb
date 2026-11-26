class SupportAgent < ApplicationAgent
  MAX_TOOL_ROUNDS = 3

  instructions { SupportContext.instructions }

  tools { [ CreateSupportTicketTool.new(chat) ] }
  tool_options rounds: MAX_TOOL_ROUNDS
end
