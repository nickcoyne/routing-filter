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
    super(req) do |route, parameters|
      # Merge in custom parameters that will be visible to the controller
      params = (parameters || {}).merge(filter_parameters)

      # For anchored routes (regular controller actions), reset the path before
      # yielding to prevent breakages in CSRF validation.
      # For non-anchored routes (mounted engines), we must NOT reset the path here
      # because Rails has already modified path_info to the post-match portion
      # that the engine needs to route internally.
      if route.path.anchored
        if req.is_a?(Hash)
          req['PATH_INFO'] = original_path
        else
          req.path_info = original_path
        end
      end

      # Yield results are dispatched to the controller
      yield(route, params)
    end
  end
end

ActionDispatch::Journey::Router.prepend(ActionDispatchJourneyRouterWithFiltering)
