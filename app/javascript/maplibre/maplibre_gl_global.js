// Copyright © Cartoway
// MapLibre is loaded from the v2 layout CDN script (window.maplibregl).
// @teritorio/maplibre-gl-teritorio-cluster imports the bare specifier "maplibre-gl";
// this module hands it the same instance the map was created with.

const maplibregl = typeof window !== 'undefined' ? window.maplibregl : null

export default maplibregl
