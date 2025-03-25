SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: custom_attributes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_attributes (
    id integer NOT NULL,
    name character varying,
    object_type integer DEFAULT 0 NOT NULL,
    object_class integer DEFAULT 0 NOT NULL,
    default_value character varying,
    description text,
    customer_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: custom_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_attributes_id_seq OWNED BY public.custom_attributes.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    end_subscription date,
    job_destination_geocoding_id integer,
    job_optimizer_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    name character varying(255),
    router_id integer NOT NULL,
    print_planning_annotating boolean DEFAULT true,
    print_header text,
    enable_orders boolean DEFAULT false NOT NULL,
    test boolean DEFAULT false NOT NULL,
    optimization_cluster_size integer,
    optimization_time double precision,
    optimization_stop_soft_upper_bound double precision,
    profile_id integer NOT NULL,
    speed_multiplier double precision DEFAULT 1.0 NOT NULL,
    default_country character varying NOT NULL,
    job_store_geocoding_id integer,
    reseller_id integer NOT NULL,
    print_stop_time boolean DEFAULT true NOT NULL,
    ref character varying,
    enable_references boolean DEFAULT true,
    enable_multi_visits boolean DEFAULT false NOT NULL,
    router_dimension integer DEFAULT 0 NOT NULL,
    advanced_options jsonb DEFAULT '{}'::jsonb NOT NULL,
    print_map boolean DEFAULT false NOT NULL,
    external_callback_url character varying,
    external_callback_name character varying,
    enable_external_callback boolean DEFAULT false NOT NULL,
    description character varying,
    enable_global_optimization boolean DEFAULT false NOT NULL,
    optimization_vehicle_soft_upper_bound double precision,
    enable_vehicle_position boolean DEFAULT true NOT NULL,
    enable_stop_status boolean DEFAULT false NOT NULL,
    router_options jsonb DEFAULT '{}'::jsonb NOT NULL,
    optimization_cost_waiting_time double precision,
    visit_duration integer,
    with_state boolean DEFAULT false,
    devices jsonb DEFAULT '{}'::jsonb NOT NULL,
    optimization_force_start boolean DEFAULT false NOT NULL,
    optimization_max_split_size integer,
    max_plannings integer,
    max_zonings integer,
    max_destinations integer,
    max_vehicle_usage_sets integer,
    enable_sms boolean DEFAULT false NOT NULL,
    sms_template character varying,
    print_barcode character varying,
    sms_concat boolean DEFAULT false NOT NULL,
    sms_from_customer_name boolean DEFAULT false NOT NULL,
    optimization_minimal_time double precision,
    history_cron_hour integer,
    sms_driver_template character varying,
    enable_optimization_soft_upper_bound boolean,
    stop_max_upper_bound integer DEFAULT 0,
    vehicle_max_upper_bound integer DEFAULT 0,
    planning_date_offset integer DEFAULT 1
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying(255),
    queue character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    progress jsonb
);


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


--
-- Name: deliverable_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deliverable_units (
    id integer NOT NULL,
    customer_id integer,
    label character varying,
    default_quantity double precision,
    default_capacity double precision,
    optimization_overload_multiplier double precision,
    ref character varying,
    icon character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: deliverable_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deliverable_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deliverable_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deliverable_units_id_seq OWNED BY public.deliverable_units.id;


--
-- Name: destinations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destinations (
    id integer NOT NULL,
    name character varying(255),
    street character varying(255),
    postalcode character varying(255),
    city character varying(255),
    lat double precision,
    lng double precision,
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    detail text,
    comment text,
    geocoding_accuracy double precision,
    country character varying,
    geocoding_level integer,
    phone_number character varying,
    ref character varying,
    state character varying,
    geocoded_at timestamp without time zone,
    geocoder_version character varying,
    geocoding_result jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: destinations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.destinations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: destinations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.destinations_id_seq OWNED BY public.destinations.id;


--
-- Name: history_stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.history_stops (
    schema_version character varying NOT NULL,
    date timestamp without time zone NOT NULL,
    reseller_id integer NOT NULL,
    customer_id integer NOT NULL,
    vehicle_usage_id integer,
    vehicle_id integer,
    router_mode character varying,
    planning_id integer NOT NULL,
    route_id integer NOT NULL,
    vehicle_usage jsonb,
    vehicle jsonb,
    planning jsonb,
    route jsonb,
    stops jsonb,
    stops_count integer,
    stops_active_count integer
);


--
-- Name: layers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.layers (
    id integer NOT NULL,
    name character varying NOT NULL,
    url character varying NOT NULL,
    attribution character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    urlssl character varying NOT NULL,
    source character varying NOT NULL,
    "overlay" boolean DEFAULT false,
    print boolean DEFAULT false NOT NULL,
    name_locale public.hstore DEFAULT ''::public.hstore NOT NULL
);


--
-- Name: layers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: layers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.layers_id_seq OWNED BY public.layers.id;


--
-- Name: layers_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.layers_profiles (
    profile_id integer,
    layer_id integer
);


--
-- Name: messaging_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messaging_logs (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    service character varying NOT NULL,
    recipient character varying,
    content text,
    message_id character varying,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: messaging_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messaging_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messaging_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messaging_logs_id_seq OWNED BY public.messaging_logs.id;


--
-- Name: order_arrays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_arrays (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    base_date date NOT NULL,
    length integer NOT NULL,
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: order_arrays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_arrays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_arrays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_arrays_id_seq OWNED BY public.order_arrays.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    shift integer NOT NULL,
    order_array_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    visit_id integer NOT NULL
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: orders_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders_products (
    order_id integer NOT NULL,
    product_id integer NOT NULL
);


--
-- Name: plannings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plannings (
    id integer NOT NULL,
    name character varying(255),
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    zoning_outdated boolean,
    order_array_id integer,
    ref character varying,
    date date,
    vehicle_usage_set_id integer NOT NULL,
    tag_operation integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true,
    begin_date date,
    end_date date
);


--
-- Name: plannings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plannings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plannings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plannings_id_seq OWNED BY public.plannings.id;


--
-- Name: plannings_zonings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plannings_zonings (
    planning_id integer,
    zoning_id integer
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    code character varying(255) NOT NULL,
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.profiles_id_seq OWNED BY public.profiles.id;


--
-- Name: profiles_routers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_routers (
    profile_id integer,
    router_id integer
);


--
-- Name: relation_fragments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relation_fragments (
    relation_id integer NOT NULL,
    visit_id integer NOT NULL,
    index integer
);


--
-- Name: resellers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resellers (
    id integer NOT NULL,
    host character varying NOT NULL,
    name character varying NOT NULL,
    welcome_url character varying,
    help_url character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    logo_large character varying,
    logo_small character varying,
    favicon character varying,
    contact_url character varying,
    website_url character varying,
    url_protocol character varying DEFAULT 'http'::character varying,
    facebook_url character varying,
    twitter_url character varying,
    linkedin_url character varying,
    subscription_url character varying,
    application_name character varying,
    audience_url character varying,
    behavior_url character varying,
    customer_audience_url character varying,
    customer_behavior_url character varying,
    authorized_fleet_administration boolean DEFAULT false,
    customer_dashboard_url character varying,
    messagings jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: resellers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resellers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resellers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resellers_id_seq OWNED BY public.resellers.id;


--
-- Name: routers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routers (
    id integer NOT NULL,
    name character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    type character varying(255) DEFAULT 'RouterOsrm'::character varying NOT NULL,
    mode character varying NOT NULL,
    name_locale public.hstore DEFAULT ''::public.hstore NOT NULL,
    options jsonb DEFAULT '{}'::jsonb NOT NULL,
    url character varying
);


--
-- Name: routers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.routers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: routers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.routers_id_seq OWNED BY public.routers.id;


--
-- Name: routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routes (
    id integer NOT NULL,
    distance double precision,
    emission double precision,
    planning_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    hidden boolean,
    locked boolean,
    outdated boolean,
    stop_out_of_drive_time boolean,
    stop_distance double precision,
    ref character varying(255),
    color character varying,
    vehicle_usage_id integer,
    stop_drive_time integer,
    last_sent_at timestamp without time zone,
    optimized_at timestamp without time zone,
    last_sent_to character varying,
    start integer,
    "end" integer,
    geojson_tracks text[],
    geojson_points text[],
    stop_no_path boolean,
    quantities public.hstore,
    lock_version integer DEFAULT 0 NOT NULL,
    visits_duration integer,
    wait_time integer,
    drive_time integer,
    stop_out_of_work_time boolean,
    stop_out_of_max_distance boolean,
    departure_eta time without time zone,
    departure_status character varying,
    arrival_eta time without time zone,
    arrival_status character varying,
    force_start boolean,
    out_of_max_ride_distance boolean,
    out_of_max_ride_duration boolean,
    cost_distance double precision,
    cost_fixed double precision,
    cost_time double precision,
    revenue double precision
);


--
-- Name: routes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.routes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: routes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.routes_id_seq OWNED BY public.routes.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stops (
    id integer NOT NULL,
    index integer NOT NULL,
    active boolean,
    distance double precision,
    route_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    out_of_window boolean,
    out_of_capacity boolean,
    out_of_drive_time boolean,
    wait_time integer,
    lock_version integer DEFAULT 0 NOT NULL,
    type character varying DEFAULT 'StopVisit'::character varying NOT NULL,
    drive_time integer,
    visit_id integer,
    status character varying,
    eta timestamp without time zone,
    "time" integer,
    no_path boolean,
    out_of_work_time boolean,
    out_of_max_distance boolean,
    unmanageable_capacity boolean,
    out_of_force_position boolean DEFAULT false,
    out_of_relation boolean DEFAULT false,
    out_of_max_ride_distance boolean,
    out_of_max_ride_duration boolean,
    status_updated_at timestamp without time zone,
    custom_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT check_visit_id CHECK ((((type)::text <> 'StopVisit'::text) OR (visit_id IS NOT NULL)))
);


--
-- Name: stops_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stops_id_seq OWNED BY public.stops.id;


--
-- Name: stops_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stops_relations (
    id integer NOT NULL,
    relation_type integer DEFAULT 0 NOT NULL,
    customer_id integer,
    current_id integer,
    successor_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: stops_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stops_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stops_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stops_relations_id_seq OWNED BY public.stops_relations.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id integer NOT NULL,
    name character varying(255),
    street character varying(255),
    postalcode character varying(255),
    city character varying(255),
    lat double precision,
    lng double precision,
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    country character varying,
    ref character varying,
    geocoding_accuracy double precision,
    geocoding_level integer,
    color character varying,
    icon character varying,
    icon_size character varying,
    state character varying,
    geocoded_at timestamp without time zone,
    geocoder_version character varying,
    geocoding_result jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: stores_vehicules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores_vehicules (
    store_id integer NOT NULL,
    vehicle_id integer NOT NULL
);


--
-- Name: tag_destinations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_destinations (
    destination_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.129478'::timestamp without time zone,
    updated_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.129478'::timestamp without time zone,
    id bigint NOT NULL
);


--
-- Name: tag_destinations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_destinations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_destinations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_destinations_id_seq OWNED BY public.tag_destinations.id;


--
-- Name: tag_plannings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_plannings (
    planning_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.151915'::timestamp without time zone,
    updated_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.151915'::timestamp without time zone,
    id bigint NOT NULL
);


--
-- Name: tag_plannings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_plannings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_plannings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_plannings_id_seq OWNED BY public.tag_plannings.id;


--
-- Name: tag_vehicle_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_vehicle_usages (
    vehicle_usage_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp(6) without time zone DEFAULT '2024-07-19 16:51:06.059601'::timestamp without time zone NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT '2024-07-19 16:51:06.059601'::timestamp without time zone NOT NULL,
    id bigint NOT NULL
);


--
-- Name: tag_vehicle_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_vehicle_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_vehicle_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_vehicle_usages_id_seq OWNED BY public.tag_vehicle_usages.id;


--
-- Name: tag_vehicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_vehicles (
    vehicle_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp(6) without time zone DEFAULT '2024-07-19 16:51:06.047754'::timestamp without time zone NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT '2024-07-19 16:51:06.047754'::timestamp without time zone NOT NULL,
    id bigint NOT NULL
);


--
-- Name: tag_vehicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_vehicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_vehicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_vehicles_id_seq OWNED BY public.tag_vehicles.id;


--
-- Name: tag_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_visits (
    visit_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.173027'::timestamp without time zone,
    updated_at timestamp without time zone DEFAULT '2024-03-20 14:17:36.173027'::timestamp without time zone,
    id bigint NOT NULL
);


--
-- Name: tag_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_visits_id_seq OWNED BY public.tag_visits.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    label character varying(255),
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    color character varying(255),
    icon character varying(255),
    ref character varying,
    icon_size character varying
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    customer_id integer,
    layer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    api_key character varying(255) NOT NULL,
    reseller_id integer,
    url_click2call character varying,
    ref character varying,
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    time_zone character varying DEFAULT 'UTC'::character varying NOT NULL,
    prefered_unit character varying DEFAULT 'km'::character varying,
    locale character varying,
    prefered_currency integer DEFAULT 0,
    export_settings jsonb DEFAULT '{}'::jsonb
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: vehicle_usage_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_usage_sets (
    id integer NOT NULL,
    customer_id integer NOT NULL,
    name character varying NOT NULL,
    store_start_id integer,
    store_stop_id integer,
    store_rest_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    time_window_start integer NOT NULL,
    time_window_end integer NOT NULL,
    rest_start integer,
    rest_stop integer,
    rest_duration integer,
    service_time_start integer,
    service_time_end integer,
    work_time integer,
    max_distance integer,
    max_ride_duration integer,
    max_ride_distance integer,
    cost_distance double precision,
    cost_fixed double precision,
    cost_time double precision
);


--
-- Name: vehicle_usage_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicle_usage_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicle_usage_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicle_usage_sets_id_seq OWNED BY public.vehicle_usage_sets.id;


--
-- Name: vehicle_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_usages (
    id integer NOT NULL,
    vehicle_usage_set_id integer NOT NULL,
    vehicle_id integer NOT NULL,
    store_start_id integer,
    store_stop_id integer,
    store_rest_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    active boolean DEFAULT true,
    time_window_start integer,
    time_window_end integer,
    rest_start integer,
    rest_stop integer,
    rest_duration integer,
    service_time_start integer,
    service_time_end integer,
    work_time integer,
    cost_distance double precision,
    cost_fixed double precision,
    cost_time double precision
);


--
-- Name: vehicle_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicle_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicle_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicle_usages_id_seq OWNED BY public.vehicle_usages.id;


--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicles (
    id integer NOT NULL,
    name character varying(255),
    emission double precision,
    consumption double precision,
    color character varying NOT NULL,
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    router_id integer,
    speed_multiplier double precision,
    ref character varying,
    contact_email character varying,
    fuel_type character varying,
    router_dimension integer,
    capacities public.hstore,
    router_options jsonb DEFAULT '{}'::jsonb NOT NULL,
    devices jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_distance integer,
    phone_number character varying,
    custom_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_ride_duration integer,
    max_ride_distance integer,
    driver_token character varying
);


--
-- Name: vehicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicles_id_seq OWNED BY public.vehicles.id;


--
-- Name: visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visits (
    id integer NOT NULL,
    ref character varying,
    destination_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    quantities public.hstore,
    time_window_start_1 integer,
    time_window_end_1 integer,
    duration integer,
    time_window_start_2 integer,
    time_window_end_2 integer,
    quantities_operations public.hstore,
    priority integer,
    force_position integer DEFAULT 0,
    custom_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    revenue double precision
);


--
-- Name: visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visits_id_seq OWNED BY public.visits.id;


--
-- Name: zones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zones (
    id integer NOT NULL,
    polygon text,
    zoning_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    vehicle_id integer,
    name character varying,
    speed_multiplier double precision DEFAULT 1.0 NOT NULL
);


--
-- Name: zones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zones_id_seq OWNED BY public.zones.id;


--
-- Name: zonings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zonings (
    id integer NOT NULL,
    name character varying(255),
    customer_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: zonings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zonings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zonings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zonings_id_seq OWNED BY public.zonings.id;


--
-- Name: custom_attributes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_attributes ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);


--
-- Name: deliverable_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliverable_units ALTER COLUMN id SET DEFAULT nextval('public.deliverable_units_id_seq'::regclass);


--
-- Name: destinations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destinations ALTER COLUMN id SET DEFAULT nextval('public.destinations_id_seq'::regclass);


--
-- Name: layers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layers ALTER COLUMN id SET DEFAULT nextval('public.layers_id_seq'::regclass);


--
-- Name: messaging_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messaging_logs ALTER COLUMN id SET DEFAULT nextval('public.messaging_logs_id_seq'::regclass);


--
-- Name: order_arrays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_arrays ALTER COLUMN id SET DEFAULT nextval('public.order_arrays_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: plannings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings ALTER COLUMN id SET DEFAULT nextval('public.plannings_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles ALTER COLUMN id SET DEFAULT nextval('public.profiles_id_seq'::regclass);


--
-- Name: resellers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resellers ALTER COLUMN id SET DEFAULT nextval('public.resellers_id_seq'::regclass);


--
-- Name: routers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routers ALTER COLUMN id SET DEFAULT nextval('public.routers_id_seq'::regclass);


--
-- Name: routes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes ALTER COLUMN id SET DEFAULT nextval('public.routes_id_seq'::regclass);


--
-- Name: stops id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops ALTER COLUMN id SET DEFAULT nextval('public.stops_id_seq'::regclass);


--
-- Name: stops_relations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops_relations ALTER COLUMN id SET DEFAULT nextval('public.stops_relations_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: tag_destinations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_destinations ALTER COLUMN id SET DEFAULT nextval('public.tag_destinations_id_seq'::regclass);


--
-- Name: tag_plannings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_plannings ALTER COLUMN id SET DEFAULT nextval('public.tag_plannings_id_seq'::regclass);


--
-- Name: tag_vehicle_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_vehicle_usages ALTER COLUMN id SET DEFAULT nextval('public.tag_vehicle_usages_id_seq'::regclass);


--
-- Name: tag_vehicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_vehicles ALTER COLUMN id SET DEFAULT nextval('public.tag_vehicles_id_seq'::regclass);


--
-- Name: tag_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_visits ALTER COLUMN id SET DEFAULT nextval('public.tag_visits_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: vehicle_usage_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets ALTER COLUMN id SET DEFAULT nextval('public.vehicle_usage_sets_id_seq'::regclass);


--
-- Name: vehicle_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages ALTER COLUMN id SET DEFAULT nextval('public.vehicle_usages_id_seq'::regclass);


--
-- Name: vehicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles ALTER COLUMN id SET DEFAULT nextval('public.vehicles_id_seq'::regclass);


--
-- Name: visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits ALTER COLUMN id SET DEFAULT nextval('public.visits_id_seq'::regclass);


--
-- Name: zones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zones ALTER COLUMN id SET DEFAULT nextval('public.zones_id_seq'::regclass);


--
-- Name: zonings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonings ALTER COLUMN id SET DEFAULT nextval('public.zonings_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: custom_attributes custom_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_attributes
    ADD CONSTRAINT custom_attributes_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deliverable_units deliverable_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliverable_units
    ADD CONSTRAINT deliverable_units_pkey PRIMARY KEY (id);


--
-- Name: destinations destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destinations
    ADD CONSTRAINT destinations_pkey PRIMARY KEY (id);


--
-- Name: layers layers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layers
    ADD CONSTRAINT layers_pkey PRIMARY KEY (id);


--
-- Name: messaging_logs messaging_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messaging_logs
    ADD CONSTRAINT messaging_logs_pkey PRIMARY KEY (id);


--
-- Name: order_arrays order_arrays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_arrays
    ADD CONSTRAINT order_arrays_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: plannings plannings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings
    ADD CONSTRAINT plannings_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: resellers resellers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resellers
    ADD CONSTRAINT resellers_pkey PRIMARY KEY (id);


--
-- Name: routers routers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routers
    ADD CONSTRAINT routers_pkey PRIMARY KEY (id);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (id);


--
-- Name: stops stops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT stops_pkey PRIMARY KEY (id);


--
-- Name: stops_relations stops_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops_relations
    ADD CONSTRAINT stops_relations_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: tag_destinations tag_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_destinations
    ADD CONSTRAINT tag_destinations_pkey PRIMARY KEY (id);


--
-- Name: tag_plannings tag_plannings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_plannings
    ADD CONSTRAINT tag_plannings_pkey PRIMARY KEY (id);


--
-- Name: tag_vehicle_usages tag_vehicle_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_vehicle_usages
    ADD CONSTRAINT tag_vehicle_usages_pkey PRIMARY KEY (id);


--
-- Name: tag_vehicles tag_vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_vehicles
    ADD CONSTRAINT tag_vehicles_pkey PRIMARY KEY (id);


--
-- Name: tag_visits tag_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_visits
    ADD CONSTRAINT tag_visits_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vehicle_usage_sets vehicle_usage_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT vehicle_usage_sets_pkey PRIMARY KEY (id);


--
-- Name: vehicle_usages vehicle_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT vehicle_usages_pkey PRIMARY KEY (id);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (id);


--
-- Name: visits visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_pkey PRIMARY KEY (id);


--
-- Name: zones zones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zones
    ADD CONSTRAINT zones_pkey PRIMARY KEY (id);


--
-- Name: zonings zonings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonings
    ADD CONSTRAINT zonings_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);


--
-- Name: fk__destinations_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__destinations_customer_id ON public.destinations USING btree (customer_id);


--
-- Name: fk__order_arrays_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__order_arrays_customer_id ON public.order_arrays USING btree (customer_id);


--
-- Name: fk__orders_order_array_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__orders_order_array_id ON public.orders USING btree (order_array_id);


--
-- Name: fk__orders_products_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__orders_products_order_id ON public.orders_products USING btree (order_id);


--
-- Name: fk__orders_products_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__orders_products_product_id ON public.orders_products USING btree (product_id);


--
-- Name: fk__plannings_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__plannings_customer_id ON public.plannings USING btree (customer_id);


--
-- Name: fk__plannings_order_array_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__plannings_order_array_id ON public.plannings USING btree (order_array_id);


--
-- Name: fk__plannings_tags_planning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__plannings_tags_planning_id ON public.tag_plannings USING btree (planning_id);


--
-- Name: fk__plannings_tags_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__plannings_tags_tag_id ON public.tag_plannings USING btree (tag_id);


--
-- Name: fk__products_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__products_customer_id ON public.products USING btree (customer_id);


--
-- Name: fk__routes_planning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__routes_planning_id ON public.routes USING btree (planning_id);


--
-- Name: fk__stops_route_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__stops_route_id ON public.stops USING btree (route_id);


--
-- Name: fk__stores_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__stores_customer_id ON public.stores USING btree (customer_id);


--
-- Name: fk__stores_vehicules_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__stores_vehicules_store_id ON public.stores_vehicules USING btree (store_id);


--
-- Name: fk__stores_vehicules_vehicle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__stores_vehicules_vehicle_id ON public.stores_vehicules USING btree (vehicle_id);


--
-- Name: fk__tags_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__tags_customer_id ON public.tags USING btree (customer_id);


--
-- Name: fk__users_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__users_customer_id ON public.users USING btree (customer_id);


--
-- Name: fk__users_layer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__users_layer_id ON public.users USING btree (layer_id);


--
-- Name: fk__vehicles_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__vehicles_customer_id ON public.vehicles USING btree (customer_id);


--
-- Name: fk__vehicles_router_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__vehicles_router_id ON public.vehicles USING btree (router_id);


--
-- Name: fk__zones_vehicle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__zones_vehicle_id ON public.zones USING btree (vehicle_id);


--
-- Name: fk__zones_zoning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__zones_zoning_id ON public.zones USING btree (zoning_id);


--
-- Name: fk__zonings_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__zonings_customer_id ON public.zonings USING btree (customer_id);


--
-- Name: index_custom_attributes_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_custom_attributes_on_customer_id ON public.custom_attributes USING btree (customer_id);


--
-- Name: index_customers_on_job_destination_geocoding_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_job_destination_geocoding_id ON public.customers USING btree (job_destination_geocoding_id);


--
-- Name: index_customers_on_job_optimizer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_job_optimizer_id ON public.customers USING btree (job_optimizer_id);


--
-- Name: index_customers_on_job_store_geocoding_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_job_store_geocoding_id ON public.customers USING btree (job_store_geocoding_id);


--
-- Name: index_deliverable_units_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliverable_units_on_customer_id ON public.deliverable_units USING btree (customer_id);


--
-- Name: index_deliverable_units_on_customer_id_and_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deliverable_units_on_customer_id_and_ref ON public.deliverable_units USING btree (customer_id, ref);


--
-- Name: index_messaging_logs_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messaging_logs_on_customer_id ON public.messaging_logs USING btree (customer_id);


--
-- Name: index_messaging_logs_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messaging_logs_on_message_id ON public.messaging_logs USING btree (message_id);


--
-- Name: index_orders_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_visit_id ON public.orders USING btree (visit_id);


--
-- Name: index_plannings_on_vehicle_usage_set_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plannings_on_vehicle_usage_set_id ON public.plannings USING btree (vehicle_usage_set_id);


--
-- Name: index_plannings_zonings_on_planning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plannings_zonings_on_planning_id ON public.plannings_zonings USING btree (planning_id);


--
-- Name: index_plannings_zonings_on_zoning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plannings_zonings_on_zoning_id ON public.plannings_zonings USING btree (zoning_id);


--
-- Name: index_relation_fragments_on_relation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_relation_fragments_on_relation_id ON public.relation_fragments USING btree (relation_id);


--
-- Name: index_relation_fragments_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_relation_fragments_on_visit_id ON public.relation_fragments USING btree (visit_id);


--
-- Name: index_relations_customer_current_successord_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_relations_customer_current_successord_id ON public.stops_relations USING btree (customer_id, current_id, successor_id);


--
-- Name: index_routes_on_vehicle_usage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routes_on_vehicle_usage_id ON public.routes USING btree (vehicle_usage_id);


--
-- Name: index_stops_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stops_on_visit_id ON public.stops USING btree (visit_id);


--
-- Name: index_tag_destinations_on_destination_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_destinations_on_destination_id ON public.tag_destinations USING btree (destination_id);


--
-- Name: index_tag_destinations_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_destinations_on_tag_id ON public.tag_destinations USING btree (tag_id);


--
-- Name: index_tag_destinations_on_tag_id_and_destination_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_destinations_on_tag_id_and_destination_id ON public.tag_destinations USING btree (tag_id, destination_id);


--
-- Name: index_tag_plannings_on_tag_id_and_planning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_plannings_on_tag_id_and_planning_id ON public.tag_plannings USING btree (tag_id, planning_id);


--
-- Name: index_tag_vehicle_usages_on_tag_id_and_vehicle_usage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_vehicle_usages_on_tag_id_and_vehicle_usage_id ON public.tag_vehicle_usages USING btree (tag_id, vehicle_usage_id);


--
-- Name: index_tag_vehicles_on_tag_id_and_vehicle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_vehicles_on_tag_id_and_vehicle_id ON public.tag_vehicles USING btree (tag_id, vehicle_id);


--
-- Name: index_tag_visits_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_visits_on_tag_id ON public.tag_visits USING btree (tag_id);


--
-- Name: index_tag_visits_on_tag_id_and_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_visits_on_tag_id_and_visit_id ON public.tag_visits USING btree (tag_id, visit_id);


--
-- Name: index_tag_visits_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_visits_on_visit_id ON public.tag_visits USING btree (visit_id);


--
-- Name: index_tags_on_customer_id_and_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_customer_id_and_ref ON public.tags USING btree (customer_id, ref);


--
-- Name: index_users_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_api_key ON public.users USING btree (api_key);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_vehicle_usage_sets_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usage_sets_on_customer_id ON public.vehicle_usage_sets USING btree (customer_id);


--
-- Name: index_vehicle_usage_sets_on_store_rest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usage_sets_on_store_rest_id ON public.vehicle_usage_sets USING btree (store_rest_id);


--
-- Name: index_vehicle_usage_sets_on_store_start_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usage_sets_on_store_start_id ON public.vehicle_usage_sets USING btree (store_start_id);


--
-- Name: index_vehicle_usage_sets_on_store_stop_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usage_sets_on_store_stop_id ON public.vehicle_usage_sets USING btree (store_stop_id);


--
-- Name: index_vehicle_usages_on_store_rest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usages_on_store_rest_id ON public.vehicle_usages USING btree (store_rest_id);


--
-- Name: index_vehicle_usages_on_store_start_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usages_on_store_start_id ON public.vehicle_usages USING btree (store_start_id);


--
-- Name: index_vehicle_usages_on_store_stop_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usages_on_store_stop_id ON public.vehicle_usages USING btree (store_stop_id);


--
-- Name: index_vehicle_usages_on_vehicle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usages_on_vehicle_id ON public.vehicle_usages USING btree (vehicle_id);


--
-- Name: index_vehicle_usages_on_vehicle_usage_set_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vehicle_usages_on_vehicle_usage_set_id ON public.vehicle_usages USING btree (vehicle_usage_set_id);


--
-- Name: index_visits_on_destination_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visits_on_destination_id ON public.visits USING btree (destination_id);


--
-- Name: index_visits_on_destination_id_and_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visits_on_destination_id_and_ref ON public.visits USING btree (destination_id, ref);


--
-- Name: stops_idx_customer_id_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stops_idx_customer_id_date ON public.history_stops USING btree (customer_id, date);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- Name: destinations fk_destinations_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destinations
    ADD CONSTRAINT fk_destinations_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: order_arrays fk_order_arrays_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_arrays
    ADD CONSTRAINT fk_order_arrays_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: orders fk_orders_order_array_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_order_array_id FOREIGN KEY (order_array_id) REFERENCES public.order_arrays(id) ON DELETE CASCADE;


--
-- Name: orders_products fk_orders_products_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders_products
    ADD CONSTRAINT fk_orders_products_order_id FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: orders_products fk_orders_products_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders_products
    ADD CONSTRAINT fk_orders_products_product_id FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: plannings fk_plannings_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings
    ADD CONSTRAINT fk_plannings_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plannings fk_plannings_order_array_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings
    ADD CONSTRAINT fk_plannings_order_array_id FOREIGN KEY (order_array_id) REFERENCES public.order_arrays(id);


--
-- Name: products fk_products_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_products_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: tag_plannings fk_rails_02f534284a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_plannings
    ADD CONSTRAINT fk_rails_02f534284a FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: messaging_logs fk_rails_0ba90c3e53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messaging_logs
    ADD CONSTRAINT fk_rails_0ba90c3e53 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: vehicle_usage_sets fk_rails_16cc08e76b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT fk_rails_16cc08e76b FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: vehicle_usage_sets fk_rails_19ac2e0237; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT fk_rails_19ac2e0237 FOREIGN KEY (store_start_id) REFERENCES public.stores(id);


--
-- Name: layers_profiles fk_rails_1f597e3fbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layers_profiles
    ADD CONSTRAINT fk_rails_1f597e3fbf FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- Name: vehicle_usages fk_rails_2494c76b6d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT fk_rails_2494c76b6d FOREIGN KEY (vehicle_usage_set_id) REFERENCES public.vehicle_usage_sets(id);


--
-- Name: tag_plannings fk_rails_2a380b8abf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_plannings
    ADD CONSTRAINT fk_rails_2a380b8abf FOREIGN KEY (planning_id) REFERENCES public.plannings(id) ON DELETE CASCADE;


--
-- Name: layers_profiles fk_rails_2d0f95c20f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layers_profiles
    ADD CONSTRAINT fk_rails_2d0f95c20f FOREIGN KEY (layer_id) REFERENCES public.layers(id);


--
-- Name: vehicle_usages fk_rails_31b67ddbf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT fk_rails_31b67ddbf0 FOREIGN KEY (store_stop_id) REFERENCES public.stores(id);


--
-- Name: stops_relations fk_rails_334c3fda73; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops_relations
    ADD CONSTRAINT fk_rails_334c3fda73 FOREIGN KEY (current_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: profiles_routers fk_rails_35ea0987c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_routers
    ADD CONSTRAINT fk_rails_35ea0987c7 FOREIGN KEY (router_id) REFERENCES public.routers(id);


--
-- Name: deliverable_units fk_rails_39e8ec541b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliverable_units
    ADD CONSTRAINT fk_rails_39e8ec541b FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: customers fk_rails_5095b21bc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_5095b21bc2 FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- Name: routes fk_rails_5699cfb483; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT fk_rails_5699cfb483 FOREIGN KEY (vehicle_usage_id) REFERENCES public.vehicle_usages(id);


--
-- Name: visits fk_rails_5966cbef79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT fk_rails_5966cbef79 FOREIGN KEY (destination_id) REFERENCES public.destinations(id) ON DELETE CASCADE;


--
-- Name: orders fk_rails_596f74dea1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_596f74dea1 FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: users fk_rails_598cb67a2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_598cb67a2e FOREIGN KEY (reseller_id) REFERENCES public.resellers(id);


--
-- Name: stops_relations fk_rails_61598bbbd9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops_relations
    ADD CONSTRAINT fk_rails_61598bbbd9 FOREIGN KEY (successor_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: stops fk_rails_6652f557f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT fk_rails_6652f557f6 FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: vehicle_usages fk_rails_6b54d8ec86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT fk_rails_6b54d8ec86 FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- Name: vehicle_usage_sets fk_rails_7067840dd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT fk_rails_7067840dd6 FOREIGN KEY (store_rest_id) REFERENCES public.stores(id);


--
-- Name: vehicle_usages fk_rails_75896d65fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT fk_rails_75896d65fc FOREIGN KEY (store_rest_id) REFERENCES public.stores(id);


--
-- Name: plannings_zonings fk_rails_87008b08a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings_zonings
    ADD CONSTRAINT fk_rails_87008b08a3 FOREIGN KEY (planning_id) REFERENCES public.plannings(id) ON DELETE CASCADE;


--
-- Name: tag_visits fk_rails_b0e5132e91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_visits
    ADD CONSTRAINT fk_rails_b0e5132e91 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: customers fk_rails_b3c8f2f3d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_b3c8f2f3d5 FOREIGN KEY (reseller_id) REFERENCES public.resellers(id);


--
-- Name: plannings_zonings fk_rails_c4685d96c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings_zonings
    ADD CONSTRAINT fk_rails_c4685d96c0 FOREIGN KEY (zoning_id) REFERENCES public.zonings(id) ON DELETE CASCADE;


--
-- Name: vehicle_usages fk_rails_cdf3e8f319; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usages
    ADD CONSTRAINT fk_rails_cdf3e8f319 FOREIGN KEY (store_start_id) REFERENCES public.stores(id);


--
-- Name: tag_visits fk_rails_d5309e7b50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_visits
    ADD CONSTRAINT fk_rails_d5309e7b50 FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: vehicle_usage_sets fk_rails_d7ffafb662; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT fk_rails_d7ffafb662 FOREIGN KEY (store_stop_id) REFERENCES public.stores(id);


--
-- Name: tag_destinations fk_rails_dda13ef84d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_destinations
    ADD CONSTRAINT fk_rails_dda13ef84d FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: customers fk_rails_e3b080944e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_e3b080944e FOREIGN KEY (router_id) REFERENCES public.routers(id);


--
-- Name: plannings fk_rails_f0e748b80c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings
    ADD CONSTRAINT fk_rails_f0e748b80c FOREIGN KEY (vehicle_usage_set_id) REFERENCES public.vehicle_usage_sets(id);


--
-- Name: tag_destinations fk_rails_fde8fb742c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_destinations
    ADD CONSTRAINT fk_rails_fde8fb742c FOREIGN KEY (destination_id) REFERENCES public.destinations(id) ON DELETE CASCADE;


--
-- Name: profiles_routers fk_rails_fe7ed969d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_routers
    ADD CONSTRAINT fk_rails_fe7ed969d2 FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- Name: routes fk_routes_planning_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT fk_routes_planning_id FOREIGN KEY (planning_id) REFERENCES public.plannings(id) ON DELETE CASCADE;


--
-- Name: history_stops fk_stops_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_stops
    ADD CONSTRAINT fk_stops_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: stops fk_stops_route_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT fk_stops_route_id FOREIGN KEY (route_id) REFERENCES public.routes(id) ON DELETE CASCADE;


--
-- Name: stores fk_stores_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT fk_stores_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: stores_vehicules fk_stores_vehicules_store_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores_vehicules
    ADD CONSTRAINT fk_stores_vehicules_store_id FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: stores_vehicules fk_stores_vehicules_vehicle_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores_vehicules
    ADD CONSTRAINT fk_stores_vehicules_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE CASCADE;


--
-- Name: tags fk_tags_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT fk_tags_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: users fk_users_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: users fk_users_layer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_layer_id FOREIGN KEY (layer_id) REFERENCES public.layers(id);


--
-- Name: vehicles fk_vehicles_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: vehicles fk_vehicles_router_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicles_router_id FOREIGN KEY (router_id) REFERENCES public.routers(id);


--
-- Name: zones fk_zones_vehicle_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zones
    ADD CONSTRAINT fk_zones_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- Name: zones fk_zones_zoning_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zones
    ADD CONSTRAINT fk_zones_zoning_id FOREIGN KEY (zoning_id) REFERENCES public.zonings(id) ON DELETE CASCADE;


--
-- Name: zonings fk_zonings_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonings
    ADD CONSTRAINT fk_zonings_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20130807195925'),
('20130807195929'),
('20130807195934'),
('20130807195940'),
('20130807195946'),
('20130807195950'),
('20130807195955'),
('20130807200001'),
('20130807200016'),
('20130807200021'),
('20130807200039'),
('20130807211354'),
('20130808183130'),
('20130808210830'),
('20130820202344'),
('20130825123959'),
('20130930201835'),
('20130930201836'),
('20131012124400'),
('20131015182755'),
('20131222105022'),
('20131222174504'),
('20131227135405'),
('20131228174827'),
('20140103161315'),
('20140207112148'),
('20140315155331'),
('20140601115136'),
('20140717114641'),
('20140721160736'),
('20140816112958'),
('20140816113900'),
('20140820163401'),
('20140821142548'),
('20140826131538'),
('20140903151616'),
('20140911144221'),
('20140917145632'),
('20140919125039'),
('20140926130501'),
('20140930130558'),
('20141002125341'),
('20141006140959'),
('20141014092855'),
('20141015093756'),
('20141021085750'),
('20141028150022'),
('20141028165002'),
('20141210144628'),
('20141210144629'),
('20141216163507'),
('20150108103218'),
('20150109130251'),
('20150121150634'),
('20150209173255'),
('20150216164130'),
('20150225160957'),
('20150226142752'),
('20150226143646'),
('20150309125918'),
('20150318172400'),
('20150328151059'),
('20150411114213'),
('20150411191047'),
('20150413102143'),
('20150414091637'),
('20150430120526'),
('20150505123132'),
('20150505145002'),
('20150630115249'),
('20150708163226'),
('20150710144116'),
('20150715120003'),
('20150722083814'),
('20150724091415'),
('20150803134100'),
('20150806133149'),
('20150812162637'),
('20150813154143'),
('20150814084849'),
('20150814165916'),
('20150818110546'),
('20150821152256'),
('20150827161221'),
('20150917130606'),
('20150924095144'),
('20150924152721'),
('20151001124324'),
('20151009165039'),
('20151012140724'),
('20151013142817'),
('20151013142818'),
('20151014131247'),
('20151021141140'),
('20151026165111'),
('20151027103159'),
('20151102113505'),
('20151102142302'),
('20151110095624'),
('20151118172552'),
('20151118172553'),
('20151118172554'),
('20151123104347'),
('20151127174934'),
('20151203174336'),
('20151207111057'),
('20151210121421'),
('20151211140402'),
('20151215150205'),
('20160105154207'),
('20160108154328'),
('20160111102326'),
('20160125093540'),
('20160128105941'),
('20160128170155'),
('20160129081114'),
('20160129160000'),
('20160201165009'),
('20160201165010'),
('20160208083631'),
('20160224095842'),
('20160225160902'),
('20160229111113'),
('20160229132719'),
('20160301113027'),
('20160302112451'),
('20160309170226'),
('20160310093440'),
('20160311104210'),
('20160314100318'),
('20160315102718'),
('20160317114628'),
('20160325113705'),
('20160401092143'),
('20160406140606'),
('20160413130004'),
('20160414093809'),
('20160414142500'),
('20160415094723'),
('20160509132447'),
('20160530145107'),
('20160617091911'),
('20160704124035'),
('20160708085953'),
('20160712133500'),
('20160720144957'),
('20160722133109'),
('20160804104220'),
('20160818101635'),
('20160906133935'),
('20160914104336'),
('20161004085743'),
('20161006133646'),
('20161115121703'),
('20161123163102'),
('20161123163103'),
('20161205165722'),
('20161208141114'),
('20161208155944'),
('20161220100839'),
('20170106110428'),
('20170111085136'),
('20170131131403'),
('20170215102225'),
('20170215113103'),
('20170220092059'),
('20170222165913'),
('20170223120120'),
('20170224144324'),
('20170227095939'),
('20170310101048'),
('20170314132235'),
('20170315164359'),
('20170316085311'),
('20170316092228'),
('20170316092501'),
('20170316164808'),
('20170316164815'),
('20170329132713'),
('20170406093321'),
('20170406095830'),
('20170406095839'),
('20170419132236'),
('20170419132237'),
('20170424151804'),
('20170424152112'),
('20170427142658'),
('20170516093304'),
('20170516093305'),
('20170516093306'),
('20170516093307'),
('20170522155742'),
('20170522155743'),
('20170523094750'),
('20170531132552'),
('20170613152549'),
('20170614151617'),
('20170615092505'),
('20170630083809'),
('20170901101949'),
('20170907120124'),
('20170912095236'),
('20170925081651'),
('20171030141539'),
('20171106100323'),
('20171106110030'),
('20171116151624'),
('20171120111400'),
('20171120151239'),
('20171120151247'),
('20171122115125'),
('20171123160420'),
('20171123160424'),
('20171127100417'),
('20171127101118'),
('20171129104645'),
('20171203134836'),
('20171211101451'),
('20180103153701'),
('20180123141615'),
('20180219090520'),
('20180223101253'),
('20180226094910'),
('20180302113103'),
('20180306105541'),
('20180306111703'),
('20180306134209'),
('20180316104056'),
('20180420075039'),
('20180531123821'),
('20180621101958'),
('20180628141723'),
('20180628142222'),
('20180629081835'),
('20181220135439'),
('20181227141833'),
('20190107081835'),
('20190315184420'),
('20190417121926'),
('20230506091330'),
('20230506091331'),
('20230506091332'),
('20230506091333'),
('20231214143522'),
('20240103084216'),
('20240115094756'),
('20240122131606'),
('20240124083101'),
('20240202082922'),
('20240208095803'),
('20240212161312'),
('20240215103513'),
('20240219091818'),
('20240311183150'),
('20240415072208'),
('20240504152464'),
('20240504152465'),
('20240504152466'),
('20240618115347'),
('20240624091527'),
('20240627142001'),
('20240704115843'),
('20240719162433'),
('20240814065613'),
('20241024064440'),
('20241227140855'),
('20250128131504'),
('20250203114002'),
('20250217092158'),
('20250219113043'),
('20250221144341'),
('20250307133104'),
('20250310095030'),
('20250314130549'),
('20250321085637'),
('20250325123806');


