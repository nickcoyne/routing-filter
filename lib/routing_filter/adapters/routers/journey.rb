# frozen_string_literal: true

# Prepend the method lookup to intercept find_routes in rails.
#
# This enables us to intercept the incoming route paths before they are
# recognized by the rails router and transformed to a route set and dispatched
# to a controller.
module ActionDispatchJourneyRouterWithFiltering
  def recognize(req, &block)
    path = if req.is_a?(Hash)
             req['PATH_INFO']
           else
             req.path_info
           end

    filter_parameters = {}
    original_path = path.dup

    # Apply the custom user around_recognize filter callbacks
    @routes.filters.run(:around_recognize, path, req) do
      # Yield the filter paramters for adjustment by the user
      filter_parameters
    end

    # Recognize the routes
    super(req) do |match, parameters|
      # Merge in custom parameters that will be visible to the controller
      params = (parameters || {}).merge(filter_parameters)

      # Reset the path before yielding to the controller (prevents breakages in CSRF validation)
      if req.is_a?(Hash)
        req['PATH_INFO'] = original_path
      else
        req.path_info = original_path
      end

      # Yield results are dispatched to the controller
      # Rails 8.1 expects (route, parameters) as separate arguments
      yield(match, params)
    end
  end
end

ActionDispatch::Journey::Router.prepend(ActionDispatchJourneyRouterWithFiltering)
