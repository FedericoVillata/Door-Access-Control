#libs
from rfid import *
import time
import requests
import threading
import subprocess
from buttonz import create_floating_button
from flask import Flask, request
app = Flask(__name__)

#configuration
rdif.init()												#init module
url_post = "http://127.0.0.1:8080"						#defining post destination

#routes
@app.route('/', methods=['POST'])
def receive_json():
    data = request.get_json()							#get of the json
    print(data)  										# print json
    if 'open_door' in data:
		print ('open door')
		open_door.rfid()
    if 'wrond_door' in data:
		print('wrong door')
		wrong_door.rfid()
    if 'error_door' in data:
		print('error door')
		error_door.rfid()
    return 'JSON ricevuto correttamente'				# print ok if json received

#def post function
def post_function():
	while True:
		identifier, text = rfid.read_card()				#prints the id, text readed by the reader
		#identifier, text = 123, "ciao"					#object created for testing
		obj = {'key-id': identifier, 'key-txt': text}	#creating json
		x = requests.post(url_post, json = obj)			#posting + getting response
		print(x.text)	
		time.sleep(1)

def start_flask():
	app.run()											#for testing
	#app.run(host= "0.0.0.0", port=5000)				#for real using
	
def buttonz_keyboard():
	create_floating_button()

def main():
	#main programme

	#threading for get function
	t_flask = threading.Thread(target=start_flask)
	t_flask.start()
	
	#threading for post function
	t_post = threading.Thread(target=post_function)
	t_post.start()
	t_post.join(timeout=1)  # wait for 1 second for t1 to finish
	
	#thread buttonz 4 matchbox-keyboard
	#t_post = threading.Thread(target=buttonz_keyboard)
	#t_post.start()
	
	# Launch the shell script
	
    
if __name__ == "__main__":
    main()

