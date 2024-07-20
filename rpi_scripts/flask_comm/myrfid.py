import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522
from time import sleep

import multiprocessing
import time

led_green = 40
led_red = 37

def init():
	GPIO.setwarnings(False)   
	GPIO.setmode(GPIO.BOARD)
	GPIO.setup(led_green,GPIO.OUT)
	GPIO.output(led_green, GPIO.LOW)
	GPIO.setup(led_red,GPIO.OUT)
	GPIO.output(led_red, GPIO.LOW)
	reader = SimpleMFRC522()

def read_card():
    global id_r
    global read_r
    id, read_t = reader.read()
    read_t = read_t.strip()
    return id, read_t
    
def write_card( write_t ):
    id, read_t = reader.write( write_t )
    
def check_t ( text ):
    id, read_t = read_card()
    return text == read_t
    
def blink_green():
    GPIO.output(led_green, GPIO.HIGH)
    sleep(1)
    GPIO.output(led_red, GPIO.LOW)
    
def blink_red():
    GPIO.output(led_green, GPIO.HIGH)
    sleep(1)
    GPIO.output(led_red, GPIO.LOW) 
    
def init_close():
	GPIO.cleanup()
	
def open_door():
	GPIO.output(led_green, GPIO.HIGH)
	GPIO.output(led_red,   GPIO.LOW)
	sleep(1)
	GPIO.output(led_red, GPIO.HIGH)
	GPIO.output(led_green, GPIO.LOW)
	
def wrong_door():
	blink_red()

def error_door():
	GPIO.output(led_green, GPIO.HIGH)
	GPIO.output(led_red,   GPIO.HIGH)
	sleep(1)
	GPIO.output(led_red,   GPIO.LOW)
	GPIO.output(led_green, GPIO.LOW)
	sleep(1)

def test():
	while True:
		write_card( "exodia" )
		print( check_t( "ciaone" ) )
		print( check_t( "exodia" ) )
		print( read_card() )
		sleep(5)
		GPIO.cleanup()

def execute_with_timeout(func, timeout=1):
    # Utilizziamo multiprocessing.Process per eseguire la funzione con un timeout
    p = multiprocessing.Process(target=func)
    p.start()
    p.join(timeout)  # Attendiamo per un massimo di `timeout` secondi

    if p.is_alive():
        p.terminate()  # Se il processo è ancora attivo dopo il timeout, lo terminiamo
        return False
    else:
        return True

# Esempio di utilizzo
def test_function():
    time.sleep(0.5)  # Simuliamo una funzione che impiega 0.5 secondi
    
def main_func(timeout):
    execute_with_timeout(read_card, timeout)  # Output: True

if (__name__ == '__main__'):
    # execute_with_timeout(read_card)  # Output: True
    pass