class AccountDeletionJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(user)
    user.destroy!
  end
end
