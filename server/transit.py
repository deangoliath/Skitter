from google.transit import gtfs_realtime_pb2
from google.protobuf.json_format import MessageToDict
from flask import Flask, jsonify
from datetime import datetime
import pytz 
import requests
import threading
import time

# Variables and Data
host_port = 5000
host_address = "0.0.0.0"

lastFetch = 0
lastFeed = {"VehiclePositions": {"header": {"timestamp": 0}}, "TripUpdates": {}, "ServiceAlerts": {}}
feedRefresh = 30 # lynx live feed updates every 30 seconds

# Define Functions

def get_feed(): # make sure to add a cache for every 30 seconds
  return lastFeed

# Fetch Data Thread
def fetchdata_thread():
  global lastFeed
  global lastFetch
  while True:
    print("Fetching Latest GTFS Data")
    lastFetch = datetime.now(pytz.timezone('America/New_York'))
    feed = gtfs_realtime_pb2.FeedMessage()
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_VehiclePositions.pb')
    feed.ParseFromString(response.content)
    lastFeed["VehiclePositions"] = MessageToDict(feed)
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_TripUpdates.pb')
    feed.ParseFromString(response.content)
    lastFeed["TripUpdates"] = MessageToDict(feed)
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_ServiceAlerts.pb')
    feed.ParseFromString(response.content)
    lastFeed["ServiceAlerts"] = MessageToDict(feed)
    time.sleep(feedRefresh)

def seconds_to_next_timesync():
  if datetime.now().second < 30:
    return 30 - datetime.now().second
  elif datetime.now().second > 30:
    return 30 - (datetime.now().second - 30) # no clue
  else:
    return 0

# Run Server

seconds_left = seconds_to_next_timesync()
print("Syncing to Lynx GTFS Refresh Interval "+str(seconds_left)+" seconds behind")
time.sleep(seconds_left)

app = Flask(__name__)

@app.route('/get_feed/')
def handle_get_feed():
  return jsonify(get_feed())

if __name__ == '__main__':
  fetchdatathread = threading.Thread(target=fetchdata_thread)
  fetchdatathread.start()
  app.run(debug=False, host=host_address, port=host_port)
