--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 13.11 (Debian 13.11-0+deb11u1)

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
    print_planning_annotating boolean,
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
    advanced_options text,
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
    optimization_minimal_time double precision
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
    progress character varying(255)
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
    geocoder_version character varying
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
-- Name: destinations_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destinations_tags (
    destination_id integer NOT NULL,
    tag_id integer NOT NULL
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
-- Name: plannings_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plannings_tags (
    planning_id integer NOT NULL,
    tag_id integer NOT NULL
);


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
    sms_api_key character varying,
    sms_api_secret character varying,
    authorized_fleet_administration boolean DEFAULT false,
    external_callback_url character varying,
    external_callback_url_name character varying,
    enable_external_callback boolean
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
    force_start boolean
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
    type character varying DEFAULT 'StopDestination'::character varying NOT NULL,
    drive_time integer,
    visit_id integer,
    status character varying,
    eta timestamp without time zone,
    "time" integer,
    no_path boolean,
    out_of_work_time boolean,
    out_of_max_distance boolean,
    unmanageable_capacity boolean,
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
    geocoder_version character varying
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
-- Name: tags_vehicle_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags_vehicle_usages (
    vehicle_usage_id integer,
    tag_id integer
);


--
-- Name: tags_vehicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags_vehicles (
    vehicle_id integer,
    tag_id integer
);


--
-- Name: tags_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags_visits (
    visit_id integer NOT NULL,
    tag_id integer NOT NULL
);


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
    locale character varying
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
    max_distance integer
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
    work_time integer
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
    custom_attributes jsonb DEFAULT '{}'::jsonb NOT NULL
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
    priority integer
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
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


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
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


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

CREATE INDEX fk__plannings_tags_planning_id ON public.plannings_tags USING btree (planning_id);


--
-- Name: fk__plannings_tags_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__plannings_tags_tag_id ON public.plannings_tags USING btree (tag_id);


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
-- Name: index_destinations_tags_on_destination_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_destinations_tags_on_destination_id ON public.destinations_tags USING btree (destination_id);


--
-- Name: index_destinations_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_destinations_tags_on_tag_id ON public.destinations_tags USING btree (tag_id);


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
-- Name: index_routes_on_vehicle_usage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routes_on_vehicle_usage_id ON public.routes USING btree (vehicle_usage_id);


--
-- Name: index_stops_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stops_on_visit_id ON public.stops USING btree (visit_id);


--
-- Name: index_tags_on_customer_id_and_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_customer_id_and_ref ON public.tags USING btree (customer_id, ref);


--
-- Name: index_tags_visits_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_visits_on_tag_id ON public.tags_visits USING btree (tag_id);


--
-- Name: index_tags_visits_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_visits_on_visit_id ON public.tags_visits USING btree (visit_id);


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
-- Name: plannings_tags fk_plannings_tags_planning_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings_tags
    ADD CONSTRAINT fk_plannings_tags_planning_id FOREIGN KEY (planning_id) REFERENCES public.plannings(id) ON DELETE CASCADE;


--
-- Name: plannings_tags fk_plannings_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plannings_tags
    ADD CONSTRAINT fk_plannings_tags_tag_id FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: products fk_products_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_products_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


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
-- Name: tags_visits fk_rails_921d431096; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags_visits
    ADD CONSTRAINT fk_rails_921d431096 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


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
-- Name: tags_visits fk_rails_d5309e7b50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags_visits
    ADD CONSTRAINT fk_rails_d5309e7b50 FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE CASCADE;


--
-- Name: destinations_tags fk_rails_d7d57d2bd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destinations_tags
    ADD CONSTRAINT fk_rails_d7d57d2bd1 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: vehicle_usage_sets fk_rails_d7ffafb662; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_usage_sets
    ADD CONSTRAINT fk_rails_d7ffafb662 FOREIGN KEY (store_stop_id) REFERENCES public.stores(id);


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
-- Name: destinations_tags fk_rails_fde8fb742c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destinations_tags
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

INSERT INTO schema_migrations (version) VALUES ('20130807195925');

INSERT INTO schema_migrations (version) VALUES ('20130807195929');

INSERT INTO schema_migrations (version) VALUES ('20130807195934');

INSERT INTO schema_migrations (version) VALUES ('20130807195940');

INSERT INTO schema_migrations (version) VALUES ('20130807195946');

INSERT INTO schema_migrations (version) VALUES ('20130807195950');

INSERT INTO schema_migrations (version) VALUES ('20130807195955');

INSERT INTO schema_migrations (version) VALUES ('20130807200001');

INSERT INTO schema_migrations (version) VALUES ('20130807200016');

INSERT INTO schema_migrations (version) VALUES ('20130807200021');

INSERT INTO schema_migrations (version) VALUES ('20130807200039');

INSERT INTO schema_migrations (version) VALUES ('20130807211354');

INSERT INTO schema_migrations (version) VALUES ('20130808183130');

INSERT INTO schema_migrations (version) VALUES ('20130808210830');

INSERT INTO schema_migrations (version) VALUES ('20130820202344');

INSERT INTO schema_migrations (version) VALUES ('20130825123959');

INSERT INTO schema_migrations (version) VALUES ('20130930201835');

INSERT INTO schema_migrations (version) VALUES ('20130930201836');

INSERT INTO schema_migrations (version) VALUES ('20131012124400');

INSERT INTO schema_migrations (version) VALUES ('20131015182755');

INSERT INTO schema_migrations (version) VALUES ('20131222105022');

INSERT INTO schema_migrations (version) VALUES ('20131222174504');

INSERT INTO schema_migrations (version) VALUES ('20131227135405');

INSERT INTO schema_migrations (version) VALUES ('20131228174827');

INSERT INTO schema_migrations (version) VALUES ('20140103161315');

INSERT INTO schema_migrations (version) VALUES ('20140207112148');

INSERT INTO schema_migrations (version) VALUES ('20140315155331');

INSERT INTO schema_migrations (version) VALUES ('20140601115136');

INSERT INTO schema_migrations (version) VALUES ('20140717114641');

INSERT INTO schema_migrations (version) VALUES ('20140721160736');

INSERT INTO schema_migrations (version) VALUES ('20140816112958');

INSERT INTO schema_migrations (version) VALUES ('20140816113900');

INSERT INTO schema_migrations (version) VALUES ('20140820163401');

INSERT INTO schema_migrations (version) VALUES ('20140821142548');

INSERT INTO schema_migrations (version) VALUES ('20140826131538');

INSERT INTO schema_migrations (version) VALUES ('20140903151616');

INSERT INTO schema_migrations (version) VALUES ('20140911144221');

INSERT INTO schema_migrations (version) VALUES ('20140917145632');

INSERT INTO schema_migrations (version) VALUES ('20140919125039');

INSERT INTO schema_migrations (version) VALUES ('20140926130501');

INSERT INTO schema_migrations (version) VALUES ('20140930130558');

INSERT INTO schema_migrations (version) VALUES ('20141002125341');

INSERT INTO schema_migrations (version) VALUES ('20141006140959');

INSERT INTO schema_migrations (version) VALUES ('20141014092855');

INSERT INTO schema_migrations (version) VALUES ('20141015093756');

INSERT INTO schema_migrations (version) VALUES ('20141021085750');

INSERT INTO schema_migrations (version) VALUES ('20141028150022');

INSERT INTO schema_migrations (version) VALUES ('20141028165002');

INSERT INTO schema_migrations (version) VALUES ('20141210144628');

INSERT INTO schema_migrations (version) VALUES ('20141210144629');

INSERT INTO schema_migrations (version) VALUES ('20141216163507');

INSERT INTO schema_migrations (version) VALUES ('20150108103218');

INSERT INTO schema_migrations (version) VALUES ('20150109130251');

INSERT INTO schema_migrations (version) VALUES ('20150121150634');

INSERT INTO schema_migrations (version) VALUES ('20150209173255');

INSERT INTO schema_migrations (version) VALUES ('20150216164130');

INSERT INTO schema_migrations (version) VALUES ('20150225160957');

INSERT INTO schema_migrations (version) VALUES ('20150226142752');

INSERT INTO schema_migrations (version) VALUES ('20150226143646');

INSERT INTO schema_migrations (version) VALUES ('20150309125918');

INSERT INTO schema_migrations (version) VALUES ('20150318172400');

INSERT INTO schema_migrations (version) VALUES ('20150328151059');

INSERT INTO schema_migrations (version) VALUES ('20150411114213');

INSERT INTO schema_migrations (version) VALUES ('20150411191047');

INSERT INTO schema_migrations (version) VALUES ('20150413102143');

INSERT INTO schema_migrations (version) VALUES ('20150414091637');

INSERT INTO schema_migrations (version) VALUES ('20150430120526');

INSERT INTO schema_migrations (version) VALUES ('20150505123132');

INSERT INTO schema_migrations (version) VALUES ('20150505145002');

INSERT INTO schema_migrations (version) VALUES ('20150630115249');

INSERT INTO schema_migrations (version) VALUES ('20150708163226');

INSERT INTO schema_migrations (version) VALUES ('20150710144116');

INSERT INTO schema_migrations (version) VALUES ('20150715120003');

INSERT INTO schema_migrations (version) VALUES ('20150722083814');

INSERT INTO schema_migrations (version) VALUES ('20150724091415');

INSERT INTO schema_migrations (version) VALUES ('20150803134100');

INSERT INTO schema_migrations (version) VALUES ('20150806133149');

INSERT INTO schema_migrations (version) VALUES ('20150812162637');

INSERT INTO schema_migrations (version) VALUES ('20150813154143');

INSERT INTO schema_migrations (version) VALUES ('20150814084849');

INSERT INTO schema_migrations (version) VALUES ('20150814165916');

INSERT INTO schema_migrations (version) VALUES ('20150818110546');

INSERT INTO schema_migrations (version) VALUES ('20150821152256');

INSERT INTO schema_migrations (version) VALUES ('20150827161221');

INSERT INTO schema_migrations (version) VALUES ('20150917130606');

INSERT INTO schema_migrations (version) VALUES ('20150924095144');

INSERT INTO schema_migrations (version) VALUES ('20150924152721');

INSERT INTO schema_migrations (version) VALUES ('20151001124324');

INSERT INTO schema_migrations (version) VALUES ('20151009165039');

INSERT INTO schema_migrations (version) VALUES ('20151012140724');

INSERT INTO schema_migrations (version) VALUES ('20151013142817');

INSERT INTO schema_migrations (version) VALUES ('20151013142818');

INSERT INTO schema_migrations (version) VALUES ('20151014131247');

INSERT INTO schema_migrations (version) VALUES ('20151021141140');

INSERT INTO schema_migrations (version) VALUES ('20151026165111');

INSERT INTO schema_migrations (version) VALUES ('20151027103159');

INSERT INTO schema_migrations (version) VALUES ('20151102113505');

INSERT INTO schema_migrations (version) VALUES ('20151102142302');

INSERT INTO schema_migrations (version) VALUES ('20151110095624');

INSERT INTO schema_migrations (version) VALUES ('20151118172552');

INSERT INTO schema_migrations (version) VALUES ('20151118172553');

INSERT INTO schema_migrations (version) VALUES ('20151118172554');

INSERT INTO schema_migrations (version) VALUES ('20151123104347');

INSERT INTO schema_migrations (version) VALUES ('20151127174934');

INSERT INTO schema_migrations (version) VALUES ('20151203174336');

INSERT INTO schema_migrations (version) VALUES ('20151207111057');

INSERT INTO schema_migrations (version) VALUES ('20151210121421');

INSERT INTO schema_migrations (version) VALUES ('20151211140402');

INSERT INTO schema_migrations (version) VALUES ('20151215150205');

INSERT INTO schema_migrations (version) VALUES ('20160105154207');

INSERT INTO schema_migrations (version) VALUES ('20160108154328');

INSERT INTO schema_migrations (version) VALUES ('20160111102326');

INSERT INTO schema_migrations (version) VALUES ('20160125093540');

INSERT INTO schema_migrations (version) VALUES ('20160128105941');

INSERT INTO schema_migrations (version) VALUES ('20160128170155');

INSERT INTO schema_migrations (version) VALUES ('20160129081114');

INSERT INTO schema_migrations (version) VALUES ('20160129160000');

INSERT INTO schema_migrations (version) VALUES ('20160201165009');

INSERT INTO schema_migrations (version) VALUES ('20160201165010');

INSERT INTO schema_migrations (version) VALUES ('20160208083631');

INSERT INTO schema_migrations (version) VALUES ('20160224095842');

INSERT INTO schema_migrations (version) VALUES ('20160225160902');

INSERT INTO schema_migrations (version) VALUES ('20160229111113');

INSERT INTO schema_migrations (version) VALUES ('20160229132719');

INSERT INTO schema_migrations (version) VALUES ('20160301113027');

INSERT INTO schema_migrations (version) VALUES ('20160302112451');

INSERT INTO schema_migrations (version) VALUES ('20160309170226');

INSERT INTO schema_migrations (version) VALUES ('20160310093440');

INSERT INTO schema_migrations (version) VALUES ('20160311104210');

INSERT INTO schema_migrations (version) VALUES ('20160314100318');

INSERT INTO schema_migrations (version) VALUES ('20160315102718');

INSERT INTO schema_migrations (version) VALUES ('20160317114628');

INSERT INTO schema_migrations (version) VALUES ('20160325113705');

INSERT INTO schema_migrations (version) VALUES ('20160401092143');

INSERT INTO schema_migrations (version) VALUES ('20160406140606');

INSERT INTO schema_migrations (version) VALUES ('20160413130004');

INSERT INTO schema_migrations (version) VALUES ('20160414093809');

INSERT INTO schema_migrations (version) VALUES ('20160414142500');

INSERT INTO schema_migrations (version) VALUES ('20160415094723');

INSERT INTO schema_migrations (version) VALUES ('20160509132447');

INSERT INTO schema_migrations (version) VALUES ('20160530145107');

INSERT INTO schema_migrations (version) VALUES ('20160617091911');

INSERT INTO schema_migrations (version) VALUES ('20160704124035');

INSERT INTO schema_migrations (version) VALUES ('20160708085953');

INSERT INTO schema_migrations (version) VALUES ('20160712133500');

INSERT INTO schema_migrations (version) VALUES ('20160720144957');

INSERT INTO schema_migrations (version) VALUES ('20160722133109');

INSERT INTO schema_migrations (version) VALUES ('20160804104220');

INSERT INTO schema_migrations (version) VALUES ('20160818101635');

INSERT INTO schema_migrations (version) VALUES ('20160906133935');

INSERT INTO schema_migrations (version) VALUES ('20160914104336');

INSERT INTO schema_migrations (version) VALUES ('20161004085743');

INSERT INTO schema_migrations (version) VALUES ('20161006133646');

INSERT INTO schema_migrations (version) VALUES ('20161115121703');

INSERT INTO schema_migrations (version) VALUES ('20161123163102');

INSERT INTO schema_migrations (version) VALUES ('20161123163103');

INSERT INTO schema_migrations (version) VALUES ('20161205165722');

INSERT INTO schema_migrations (version) VALUES ('20161208141114');

INSERT INTO schema_migrations (version) VALUES ('20161208155944');

INSERT INTO schema_migrations (version) VALUES ('20161220100839');

INSERT INTO schema_migrations (version) VALUES ('20170106110428');

INSERT INTO schema_migrations (version) VALUES ('20170111085136');

INSERT INTO schema_migrations (version) VALUES ('20170131131403');

INSERT INTO schema_migrations (version) VALUES ('20170215102225');

INSERT INTO schema_migrations (version) VALUES ('20170215113103');

INSERT INTO schema_migrations (version) VALUES ('20170220092059');

INSERT INTO schema_migrations (version) VALUES ('20170222165913');

INSERT INTO schema_migrations (version) VALUES ('20170223120120');

INSERT INTO schema_migrations (version) VALUES ('20170224144324');

INSERT INTO schema_migrations (version) VALUES ('20170227095939');

INSERT INTO schema_migrations (version) VALUES ('20170310101048');

INSERT INTO schema_migrations (version) VALUES ('20170314132235');

INSERT INTO schema_migrations (version) VALUES ('20170315164359');

INSERT INTO schema_migrations (version) VALUES ('20170316085311');

INSERT INTO schema_migrations (version) VALUES ('20170316092228');

INSERT INTO schema_migrations (version) VALUES ('20170316092501');

INSERT INTO schema_migrations (version) VALUES ('20170316164808');

INSERT INTO schema_migrations (version) VALUES ('20170316164815');

INSERT INTO schema_migrations (version) VALUES ('20170329132713');

INSERT INTO schema_migrations (version) VALUES ('20170406093321');

INSERT INTO schema_migrations (version) VALUES ('20170406095830');

INSERT INTO schema_migrations (version) VALUES ('20170406095839');

INSERT INTO schema_migrations (version) VALUES ('20170419132236');

INSERT INTO schema_migrations (version) VALUES ('20170419132237');

INSERT INTO schema_migrations (version) VALUES ('20170424151804');

INSERT INTO schema_migrations (version) VALUES ('20170424152112');

INSERT INTO schema_migrations (version) VALUES ('20170427142658');

INSERT INTO schema_migrations (version) VALUES ('20170516093304');

INSERT INTO schema_migrations (version) VALUES ('20170516093305');

INSERT INTO schema_migrations (version) VALUES ('20170516093306');

INSERT INTO schema_migrations (version) VALUES ('20170516093307');

INSERT INTO schema_migrations (version) VALUES ('20170522155742');

INSERT INTO schema_migrations (version) VALUES ('20170522155743');

INSERT INTO schema_migrations (version) VALUES ('20170523094750');

INSERT INTO schema_migrations (version) VALUES ('20170531132552');

INSERT INTO schema_migrations (version) VALUES ('20170613152549');

INSERT INTO schema_migrations (version) VALUES ('20170614151617');

INSERT INTO schema_migrations (version) VALUES ('20170615092505');

INSERT INTO schema_migrations (version) VALUES ('20170630083809');

INSERT INTO schema_migrations (version) VALUES ('20170901101949');

INSERT INTO schema_migrations (version) VALUES ('20170907120124');

INSERT INTO schema_migrations (version) VALUES ('20170912095236');

INSERT INTO schema_migrations (version) VALUES ('20170925081651');

INSERT INTO schema_migrations (version) VALUES ('20171030141539');

INSERT INTO schema_migrations (version) VALUES ('20171106100323');

INSERT INTO schema_migrations (version) VALUES ('20171106110030');

INSERT INTO schema_migrations (version) VALUES ('20171116151624');

INSERT INTO schema_migrations (version) VALUES ('20171120111400');

INSERT INTO schema_migrations (version) VALUES ('20171120151239');

INSERT INTO schema_migrations (version) VALUES ('20171120151247');

INSERT INTO schema_migrations (version) VALUES ('20171122115125');

INSERT INTO schema_migrations (version) VALUES ('20171123160420');

INSERT INTO schema_migrations (version) VALUES ('20171123160424');

INSERT INTO schema_migrations (version) VALUES ('20171127100417');

INSERT INTO schema_migrations (version) VALUES ('20171127101118');

INSERT INTO schema_migrations (version) VALUES ('20171129104645');

INSERT INTO schema_migrations (version) VALUES ('20171203134836');

INSERT INTO schema_migrations (version) VALUES ('20171211101451');

INSERT INTO schema_migrations (version) VALUES ('20180103153701');

INSERT INTO schema_migrations (version) VALUES ('20180123141615');

INSERT INTO schema_migrations (version) VALUES ('20180219090520');

INSERT INTO schema_migrations (version) VALUES ('20180223101253');

INSERT INTO schema_migrations (version) VALUES ('20180226094910');

INSERT INTO schema_migrations (version) VALUES ('20180302113103');

INSERT INTO schema_migrations (version) VALUES ('20180306105541');

INSERT INTO schema_migrations (version) VALUES ('20180306111703');

INSERT INTO schema_migrations (version) VALUES ('20180306134209');

INSERT INTO schema_migrations (version) VALUES ('20180316104056');

INSERT INTO schema_migrations (version) VALUES ('20180420075039');

INSERT INTO schema_migrations (version) VALUES ('20180531123821');

INSERT INTO schema_migrations (version) VALUES ('20180621101958');

INSERT INTO schema_migrations (version) VALUES ('20180628141723');

INSERT INTO schema_migrations (version) VALUES ('20180628142222');

INSERT INTO schema_migrations (version) VALUES ('20180629081835');

INSERT INTO schema_migrations (version) VALUES ('20181220135439');

INSERT INTO schema_migrations (version) VALUES ('20181227141833');

INSERT INTO schema_migrations (version) VALUES ('20190107081835');

INSERT INTO schema_migrations (version) VALUES ('20190315184420');

INSERT INTO schema_migrations (version) VALUES ('20190417121926');

INSERT INTO schema_migrations (version) VALUES ('20230506091330');

INSERT INTO schema_migrations (version) VALUES ('20230506091331');

INSERT INTO schema_migrations (version) VALUES ('20230506091332');

INSERT INTO schema_migrations (version) VALUES ('20230506091333');

INSERT INTO schema_migrations (version) VALUES ('20231214143522');

