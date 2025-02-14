Planner::Application.config.geocoder = Planner::Application.config.geocode_geocoder unless Planner::Application.config.geocoder
Planner::Application.config.router = Planner::Application.config.router_wrapper unless Planner::Application.config.router
Planner::Application.config.optimizer = Planner::Application.config.optimize unless Planner::Application.config.optimizer
