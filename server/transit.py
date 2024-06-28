from google.transit import gtfs_realtime_pb2
from google.protobuf.json_format import MessageToDict
from flask import Flask, jsonify
from datetime import datetime, timedelta
import pytz 
import requests
import threading
import time

# Variables and Data
lastfetch = 0
lastfeed = {"VehiclePositions": {"header": {"timestamp": 0}}, "TripUpdates": {}, "ServiceAlerts": {}}
feed_refresh = 30 # lynx live feed updates every 30 seconds

# Define Functions

def get_feed(): # make sure to add a cache for every 30 seconds
  return lastfeed

# Fetch Data Thread
def fetchdata_thread():
  global lastfeed
  global lastfetch
  while True:
    print("Fetching Latest GTFS Data")
    lastfetch = datetime.now(pytz.timezone('America/New_York'))
    feed = gtfs_realtime_pb2.FeedMessage()
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_VehiclePositions.pb')
    feed.ParseFromString(response.content)
    lastfeed["VehiclePositions"] = MessageToDict(feed)
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_TripUpdates.pb')
    feed.ParseFromString(response.content)
    lastfeed["TripUpdates"] = MessageToDict(feed)
    response = requests.get('http://gtfsrt.golynx.com/gtfsrt/GTFS_ServiceAlerts.pb')
    feed.ParseFromString(response.content)
    lastfeed["ServiceAlerts"] = MessageToDict(feed)
    time.sleep(feed_refresh)

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
  app.run(debug=False)
