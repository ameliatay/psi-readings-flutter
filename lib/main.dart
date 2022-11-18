import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_config/flutter_config.dart';

// Building main application
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required by FlutterConfig
  await FlutterConfig.loadEnvVariables();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Google Maps Demo',
      home: MapSample(),
    );
  }
}

// Creating a class to fetch and store API data
class ApiData {
  final Map regionMetadata;
  final Map readingData;

  ApiData({required this.regionMetadata, required this.readingData});
}

// Creating main widget
class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  // Initialising future variables
  final Set<Marker> markers = {};
  final Map psiReadingData = {};

  // Initialising status variables
  var status = {
    0: "Good",
    51: "Moderate",
    101: "Unhealthy",
    201: "Very Unhealthy",
    301: "Hazardous"
  };

  // Creating Uri to redirect users to more detailed information about PSI readings
  final Uri _psiUrl = Uri.parse('https://www.haze.gov.sg/#2');

  Future<void> _launchUrl() async {
    if (!await launchUrl(_psiUrl)) {
      throw 'Could not launch $_psiUrl';
    }
  }

  // Rendering the Google map
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition singapore = CameraPosition(
    target: LatLng(1.3521, 103.8198),
    zoom: 10.5,
  );

  // Making the API request to fetch data
  Future<String> getRequest() async {
    // Get current date
    var now = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd');
    String formattedDate = formatter.format(now);
    var nationalReadings = "As of ${DateFormat("yMMMMd").format(now)}\n";

    //Get API data
    final queryParameters = {"date": formattedDate};
    final uri =
        Uri.https("api.data.gov.sg", "/v1/environment/psi", queryParameters);
    final response = await http.get(uri);
    var responseData = json.decode(response.body);

    // Parsing response for UI
    var regionMetadata = responseData['region_metadata'];
    var psiReadings = responseData['items'][0]['readings'];

    // Get information for each region
    for (var region in regionMetadata) {
      var regionName = region['name'];

      if (regionName != 'national') {
        // Setting markers
        var lat = region['label_location']['latitude'];
        var lng = region['label_location']['longitude'];
        var psi = psiReadings["psi_twenty_four_hourly"][regionName];

        var regionStatus;

        for (var key in status.keys) {
          if (psi >= key) {
            regionStatus = status[key];
          }
        }

        Marker temp = Marker(
            position: LatLng(lat, lng),
            markerId: MarkerId(regionName),
            infoWindow: InfoWindow(
                title: regionName[0].toUpperCase() + regionName.substring(1),
                snippet:
                    "PSI 24-Hour: ${psiReadings["psi_twenty_four_hourly"][regionName]}\nStatus: $regionStatus"));

        markers.add(temp);
      } else {
        var nationalPsi = psiReadings["psi_twenty_four_hourly"]["national"];
        var nationalStatus;

        for (var key in status.keys) {
          if (nationalPsi >= key) {
            nationalStatus = status[key];
          }
        }

        nationalReadings =
            "${nationalReadings}PSI 24-Hour: $nationalPsi\nStatus: $nationalStatus";
      }
    }
    return nationalReadings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("PSI Reading"), actions: <Widget>[
          IconButton(onPressed: _launchUrl, icon: const Icon(Icons.info))
        ]),
        body: FutureBuilder(
          future: getRequest(),
          builder: (BuildContext ctx, AsyncSnapshot snapshot) {
            if (snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return Stack(children: <Widget>[
                GoogleMap(
                    initialCameraPosition: singapore,
                    myLocationButtonEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    markers: markers),
                Positioned(
                    child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 25.0),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xfff6f6f6),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black45,
                              offset: Offset(0.0, 2.0),
                              blurRadius: 10.0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Singapore's Overall Rating",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(snapshot.data)
                          ],
                        )))
              ]);
            }
          },
        ),
        floatingActionButton: Align(
          alignment: Alignment.bottomRight,
          child: FloatingActionButton.extended(
            onPressed: _goToSingapore,
            label: const Text('Back to Singapore'),
            icon: const Icon(Icons.home),
          ),
        ));
  }

  Future<void> _goToSingapore() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(singapore));
  }
}
