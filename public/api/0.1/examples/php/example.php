<?php
$api_key = '!!!your_secret_api_key!!!';
$url = 'http://localhost:3000'

// EXAMPLE 1
// get the destinations list from api_key user's customer
$destinations_str = file_get_contents($url.'/api/0.1/destinations.json?api_key='.$api_key);
$destinations = json_decode($destinations_str);
print_r($destinations);

// EXAMPLE 2
// post a new destination in json (will be automatically geocoded if lat/lng are missing)
$destinations_str = "
[{
  \"ref\": \"my_ref\",
  \"name\": \"new client\",
  \"street\": \"12 avenue Thiers\",
  \"postalcode\": \"33100\",
  \"city\": \"Bordeaux\",
  \"country\": \"France\",
  \"detail\": \"2ème étage\",
  \"tag_ids\": [],
  \"visits\": [
    {
      \"time_window_start_1\": \"08:00\",
      \"time_window_end_1\": \"12:00\",
      \"time_window_start_2\": \"14:00\",
      \"time_window_end_2\": \"18:00\",
      \"\": \"00:10:00\"
    }
  ]
}]
";
$options = array(
  'http' => array(
    'header'  => "Content-Type: application/json\r\n" .
                 "Accept: application/json\r\n",
    'method'  => 'PUT',
    'content' => "{\"destinations\": $destinations_str}"
  )
);
$context  = stream_context_create($options);
$result = file_get_contents($url.'/api/0.1/destinations.json?api_key='.$api_key, false, $context);
print_r($result);

// EXAMPLE 3
// same and create a planning at same time
$destinations_str_with_route = "
[{
  \"ref\": \"my_ref\",
  \"name\": \"new client\",
  \"street\": \"12 avenue Thiers\",
  \"postalcode\": \"33100\",
  \"city\": \"Bordeaux\",
  \"country\": \"France\",
  \"detail\": \"2ème étage\",
  \"tag_ids\": [],
  \"visits\": [
    {
      \"quantities\": [{\"deliverable_unit_id\": !!!one_of_your_deliverable_unit_id!!!, \"quantity\": 1.0}],
      \"time_window_start_1\": \"08:00\",
      \"time_window_end_1\": \"12:00\",
      \"time_window_start_2\": \"14:00\",
      \"time_window_end_2\": \"18:00\",
      \"\": \"00:10:00\",
      \"route\": \"string\",
      \"active\": true
    }
  ]
}]
";
$options = array(
  'http' => array(
    'header'  => "Content-Type: application/json\r\n" .
                 "Accept: application/json\r\n",
    'method'  => 'PUT',
    'content' => "{
      \"destinations\": $destinations_str_with_route,
      \"planning\": {\"name\": \"my plan\"}
    }" // note the "route" key defines the targeted route if you have already this info for each visit in created plan
  )
);
$context  = stream_context_create($options);
$result = file_get_contents($url.'/api/0.1/destinations.json?api_key='.$api_key, false, $context);
print_r($result);

// EXAMPLE 4
// import destinations and create a new planning by uploading csv using cURL
$ch = curl_init($url.'/api/0.1/destinations.json?api_key='.$api_key);
curl_setopt($ch, CURLOPT_HTTPHEADER, array('Accept-Language:fr-FR')); // Send Accept-Language:en headers when parsing files with header columns in english
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT'); // note the PUT here
$filename = tempnam(sys_get_temp_dir(), 'destinations.csv');
$fh = fopen($filename, 'w');
fwrite($fh,
"référence,nom,voie,complément,code postal,ville,lat,lng,tournée,catégories,livré\n
z,BF,87 RUE DES FLEURS,,13010,Marseille,43.28,5.39,1,tag1,\"oui\"");
fclose($fh);
curl_setopt($ch, CURLOPT_POSTFIELDS, array('file' => ('@'.$filename)));
$result = curl_exec($ch);
curl_close($ch);
?>
