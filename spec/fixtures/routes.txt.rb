Rails.application.routes.draw do
  constraints -> { Rails.application.config.non_production } do
    namespace :foo do
      resource :bar
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end
  constraints -> { Rails.application.config.non_production } do
    namespace :bar do
      resource :baz
    end
  end

  namespace :admin do
    resource :session

  match "/out_of_office(*path)", via: :all, to: redirect { |_params, req|
    uri = URI(req.path.gsub("out_of_office", "in_office"))
    uri.query = req.query_string.presence
    uri.to_s
  }
end
