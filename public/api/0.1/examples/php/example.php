<?php
// REST API 0.1 examples. Replace the placeholders, then run: php example.php
// See ../../getting-started.md for the happy path, pitfalls, and CSV headers.

$api_key = '!!!your_secret_api_key!!!';
$url = 'http://localhost:3000';

function api($method, $path, $body = null) {
  global $url, $api_key;
  $headers = "Api-Key: $api_key\r\nAccept: application/json\r\nContent-Type: application/json\r\n";
  $opts = array(
    'http' => array(
      'method' => $method,
      'header' => $headers,
      'ignore_errors' => true,
    )
  );
  if ($body !== null) {
    $opts['http']['content'] = json_encode($body);
  }
  $raw = file_get_contents($url.$path, false, stream_context_create($opts));
  return $raw ? json_decode($raw, true) : null;
}

// EXAMPLE 1 — bootstrap: deliverable unit ids and vehicle refs
$units = api('GET', '/api/0.1/deliverable_units.json');
echo 'Deliverable units: '.json_encode($units)."\n";
$vehicles = api('GET', '/api/0.1/vehicles.json');
echo 'Vehicles: '.json_encode($vehicles)."\n";

// EXAMPLE 2 — create one destination with a nested visit (geocoded if lat/lng are omitted)
$created = api('POST', '/api/0.1/destinations.json', array(
  'ref' => 'CLIENT-12',
  'name' => 'Acme',
  'street' => '12 avenue Thiers',
  'postalcode' => '33100',
  'city' => 'Bordeaux',
  'country' => 'France',
  'visits' => array(array(
    'ref' => 'V1',
    'duration' => '00:10:00',
    'time_window_start_1' => '08:00',
    'time_window_end_1' => '12:00',
    'quantities' => array(array('deliverable_unit_id' => 1, 'delivery' => 1.0)),
  )),
));
echo 'Created destination id='.$created['id']."\n";

// EXAMPLE 3 — bulk upsert and create a planning when visits have a vehicle ref
$imported = api('PUT', '/api/0.1/destinations.json', array(
  'planning' => array('name' => 'Monday', 'ref' => 'PLAN-MON'),
  'destinations' => array(array(
    'ref' => 'CLIENT-12',
    'name' => 'Acme',
    'street' => '12 avenue Thiers',
    'postalcode' => '33100',
    'city' => 'Bordeaux',
    'country' => 'France',
    'visits' => array(array(
      'duration' => '00:10:00',
      'time_window_start_1' => '08:00',
      'time_window_end_1' => '12:00',
      'route' => 'VEH-1',
      'active' => true,
    )),
  )),
));
echo 'Imported '.count($imported)." destinations\n";

// EXAMPLE 4 — create a planning (routes and stops are materialized automatically)
$planning = api('POST', '/api/0.1/plannings.json', array(
  'name' => 'Monday',
  'ref' => 'PLAN-MON',
  'date' => '2026-09-14',
));
echo 'Planning id='.$planning['id']."\n";

// EXAMPLE 5 — CSV import (English headers). Switch Accept-Language to fr for French headers.
// $filename = tempnam(sys_get_temp_dir(), 'destinations').'.csv';
// file_put_contents($filename, "reference,name,street,postalcode,city,country,visit duration,open 1,close 1,delivery,vehicle,plan\nCLIENT-12,Acme,12 avenue Thiers,33100,Bordeaux,France,00:10:00,08:00,12:00,1,VEH-1,Monday\n");
// $ch = curl_init($url.'/api/0.1/destinations.json');
// curl_setopt_array($ch, array(
//   CURLOPT_CUSTOMREQUEST => 'PUT',
//   CURLOPT_HTTPHEADER => array("Api-Key: $api_key", 'Accept-Language: en'),
//   CURLOPT_POSTFIELDS => array('file' => new CURLFile($filename, 'text/csv', 'destinations.csv')),
//   CURLOPT_RETURNTRANSFER => true,
// ));
// echo curl_exec($ch);
// curl_close($ch);
