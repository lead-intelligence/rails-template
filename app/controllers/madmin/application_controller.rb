module Madmin
  class ApplicationController < Madmin::BaseController
    include SuperadminAuthentication
  end
end
