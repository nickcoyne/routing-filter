require 'test_helper'
require 'test_adapters/rails'

# Create a minimal test engine
module TestStatus
  class Engine < ::Rails::Engine
    isolate_namespace TestStatus
  end

  class StatusController < ActionController::Base
    def index
      render plain: 'OK'
    end
  end
end

TestStatus::Engine.routes.draw do
  root to: 'status#index'
  get '/index', to: 'status#index'
end

class MountedEngineTest < Minitest::Test
  include TestRailsAdapter::RackTestHelper

  def setup
    I18n.locale = nil
    I18n.default_locale = :en
    I18n.available_locales = [:de, :en]

    RoutingFilter::Locale.include_default_locale = true

    # Draw routes with mounted engine
    TestRailsAdapter::Application.routes.draw do
      filter :locale
      mount TestStatus::Engine, at: '/status'
      get '/' => 'tests#index'
    end
  end

  def teardown
    # Restore original routes
    TestRailsAdapter::Application.routes.draw do
      filter :uuid, :pagination, :locale, :extension
      get '/' => 'tests#index'
      get '/foo/:id' => 'tests#show', as: 'foo'
    end
  end

  test 'recognizes routes to mounted engines' do
    # This should recognize the engine mount
    result = TestRailsAdapter::Application.routes.recognize_path('/status', method: :get)
    assert result, 'Should recognize /status route'
  end

  test 'serves requests to mounted engines' do
    get '/status'
    assert_equal 200, last_response.status, "Expected 200 but got #{last_response.status}: #{last_response.body}"
    assert_equal 'OK', last_response.body
  end

  test 'serves requests to mounted engine sub-routes' do
    get '/status/index'
    assert_equal 200, last_response.status, "Expected 200 but got #{last_response.status}: #{last_response.body}"
    assert_equal 'OK', last_response.body
  end

  test 'serves requests to mounted engines with locale prefix' do
    get '/de/status'
    assert_equal 200, last_response.status, "Expected 200 but got #{last_response.status}: #{last_response.body}"
    assert_equal 'OK', last_response.body
  end
end
