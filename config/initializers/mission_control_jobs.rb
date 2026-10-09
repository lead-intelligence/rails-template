MissionControl::Jobs.base_controller_class = "MissionControlJobsBaseController"
MissionControl::Jobs.http_basic_auth_enabled = false

Rails.application.config.to_prepare { I18n.eager_load! }
