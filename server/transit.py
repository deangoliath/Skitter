from google.transit import gtfs_realtime_pb2
from google.protobuf.json_format import MessageToDict
from flask import Flask, jsonify
from datetime import datetime
import pytz
import requests
import threading
import time
import zipfile
import os

# Variables and Data
host_port = 5000
host_address = "0.0.0.0"

lastFetch = 0
lastFeed = {
    "VehiclePositions": {"header": {"timestamp": 0}},
    "TripUpdates": {},
    "ServiceAlerts": {},
}
feedRefresh = 30  # lynx live feed updates every 30 seconds

# Define Functions


def get_feed():
    return lastFeed


def get_routes():  # should use memory or file operations? can overload server attack with too many file operation requests?
    routes_dict = {}
    with open("transit_server_data/transit_data/lynx/routes.txt", "r") as file:
        header = file.readline().strip().split(",")
        for line in file:
            route_data = line.strip().split(",")
            route_dict = dict(zip(header, route_data))
            route_id = route_data[0]
            routes_dict[route_id] = route_dict
    return routes_dict

def get_trips():
    return {}

def get_stops():
    return {}
    
def get_fare_rules():
    return {}
    
def get_fare_attributes():
    return {}

def get_stops():
    return {}

def get_stop_times():
    return {}
    
def get_calendar_dates():
    return {}

def get_calendar():
    return {}

def get_agency():
    return {}

def get_feed_info():
    return {}
    
def get_shapes():
    return {}

# Fetch Data Thread
def fetchdata_thread():
    if not os.path.exists("transit_server_data/transit_data/lynx"):
            os.makedirs("transit_server_data/transit_data/lynx")
    response = requests.get("http://gtfsrt.golynx.com/gtfsrt/google_transit.zip")
    with open('transit_server_data/transit_data.zip', 'wb') as f:
        f.write(response.content)
    with zipfile.ZipFile("transit_server_data/transit_data.zip", 'r') as zip_ref:
        zip_ref.extractall("transit_server_data/transit_data/lynx")
    try:
        os.remove("transit_server_data/transit_data.zip")
    except FileNotFoundError:
        print("Tried to delete file. File not found.")
    print("Transit Data Updated")
    global lastFeed
    global lastFetch
    while True:
        print("Fetching Latest GTFS Data")
        lastFetch = datetime.now(pytz.timezone("America/New_York"))
        feed = gtfs_realtime_pb2.FeedMessage()
        response = requests.get(
            "http://gtfsrt.golynx.com/gtfsrt/GTFS_VehiclePositions.pb"
        )
        feed.ParseFromString(response.content)
        lastFeed["VehiclePositions"] = MessageToDict(feed)
        response = requests.get("http://gtfsrt.golynx.com/gtfsrt/GTFS_TripUpdates.pb")
        feed.ParseFromString(response.content)
        lastFeed["TripUpdates"] = MessageToDict(feed)
        response = requests.get("http://gtfsrt.golynx.com/gtfsrt/GTFS_ServiceAlerts.pb")
        feed.ParseFromString(response.content)
        lastFeed["ServiceAlerts"] = MessageToDict(feed)
        time.sleep(feedRefresh)


def seconds_to_next_timesync():
    if datetime.now().second < 30:
        return 30 - datetime.now().second
    elif datetime.now().second > 30:
        return 30 - (datetime.now().second - 30)  # no clue
    else:
        return 0


# Run Server

seconds_left = seconds_to_next_timesync()
print("Syncing to Lynx GTFS Refresh Interval " + str(seconds_left) + " seconds behind")
time.sleep(seconds_left)

app = Flask(__name__)


@app.route("/")
def handle_index():
    return jsonify({"message": "Hello! This is a simple transit data relay server! Please do not abuse!", "source": "https://codeberg.org/JumpingPants/OpenLynx", "routes": ["/get_feed/", "/get_routes/"]})


@app.route("/get_feed/")
def handle_get_feed():
    return jsonify(get_feed())


@app.route("/get_routes/")
def handle_get_routes():
    return jsonify(get_routes())


@app.route("/get_trips/")
def handle_get_trips():
    return jsonify(get_trips())


@app.route("/get_stops/")
def handle_get_stops():
    return jsonify(get_stops())


@app.route("/get_fare_rules/")
def handle_get_fare_rules():
    return jsonify(get_fare_rules())


@app.route("/get_fare_attributes/")
def handle_get_fare_attributes():
    return jsonify(get_fare_attributes())


@app.route("/get_stop_times/")
def handle_stop_times():
    return jsonify(get_stop_times())


@app.route("/get_calendar_dates/")
def handle_get_calendar_dates():
    return jsonify(get_calendar_dates())


@app.route("/get_calendar/")
def handle_get_calendar():
    return jsonify(get_calendar())


@app.route("/get_agency/")
def handle_get_agency():
    return jsonify(get_agency())


@app.route("/get_feed_info/")
def handle_get_feed_info():
    return jsonify(get_feed_info())


@app.route("/get_shapes/")
def handle_get_shapes():
    return jsonify(get_shapes())


@app.route("/get_services/")
def handle_get_services():
    return jsonify(
        [
            {
                "name": "lynx",
                "city": "orlando",
                "state": "florida",
                "website": "golynx.com",
                "data": "gtfsrt.golynx.com",
            }
        ]
    )


if __name__ == "__main__":
    fetchdatathread = threading.Thread(target=fetchdata_thread)
    fetchdatathread.start()
    app.run(debug=False, host=host_address, port=host_port)

