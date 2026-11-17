class SupportAgent < ApplicationAgent
  instructions { SupportContext.instructions }

  tools { [ CreateSupportTicketTool.new(chat) ] }
end
