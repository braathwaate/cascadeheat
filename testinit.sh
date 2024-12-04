#!/bin/bash
# initialize the controller
curl -d "fn=open&dev=/dev/ttyACM0&usb=false" -X POST http://localhost:8091/devpost.html

