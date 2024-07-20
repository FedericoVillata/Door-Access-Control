import requests
import tkinter as tk
from tkinter import messagebox
import signal
import sys
import os
import json
import string
import random

debug = True

#id_path = "./flask_comm/term_id.json"
id_path = "./term_id.json"

id_info = { "Company" : "google", "room" : "ufficio" }

def write_json_file(file_path, content, force=False):
    """
    Scrive un dizionario come contenuto in un file JSON. Se il file esiste già, non lo sovrascrive
    a meno che non venga passato il flag `force` come True.

    :param file_path: Il percorso del file dove scrivere il contenuto.
    :param content: Il dizionario da scrivere nel file.
    :param force: Booleano che indica se sovrascrivere il file esistente.
    """
    if not force and os.path.exists(file_path):
        #print(f"Il file {file_path} esiste già. Utilizzare il flag 'force' per sovrascriverlo.")
        return
    
    try:
        with open(file_path, 'w', encoding='utf-8') as file:
            json.dump(content, file, ensure_ascii=False, indent=4)
        print(f"Contenuto JSON scritto con successo nel file {file_path}.")
    except TypeError as e:
        print(f"Errore durante la conversione del contenuto in JSON: {e}")
    except IOError as e:
        print(f"Errore durante la scrittura del file {file_path}: {e}")
        
def read_json_file(file_path):
    """
    Legge il contenuto di un file JSON e lo restituisce come dizionario.

    :param file_path: Il percorso del file da leggere.
    :return: Il contenuto del file come dizionario.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = json.load(file)
        return content
    except FileNotFoundError:
        print(f"Errore: Il file {file_path} non esiste.")
        return None
    except json.JSONDecodeError as e:
        print(f"Errore durante la decodifica del file JSON {file_path}: {e}")
        return None
    except IOError as e:
        print(f"Errore durante la lettura del file {file_path}: {e}")
        return None
        

def fetch_data():
    url = 'http://127.0.0.1:5000/api/data'  # URL del server Flask
    #number_to_send = 42  # Sostituisci con il numero che vuoi inviare
    data_ = read_json_file(id_path)
    number_to_send = int(input())
    data_.update({'number': number_to_send })
    query = data_
    response = requests.post(url, json=query)

    if response.status_code == 200:
        data = response.json()
        show_popup(data)
    else:
        show_error(response.status_code)

def show_popup(data):
    # Creare la finestra principale
    global root
    root = tk.Tk()
    root.withdraw()  # Nascondere la finestra principale

    # Creare la finestra pop-up
    popup = tk.Toplevel()
    popup.title("Dati della risposta")
    popup.overrideredirect(True)  # Rimuovere i bordi della finestra

    # Cambiare il colore di sfondo della finestra pop-up in base al valore di random_bool
    bg_color = 'green' if data['random_bool'] else 'red'
    popup.configure(bg=bg_color)

    # Centrare la finestra pop-up
    window_width = 400
    window_height = 200
    screen_width = popup.winfo_screenwidth()
    screen_height = popup.winfo_screenheight()
    position_top = int(screen_height/2 - window_height/2)
    position_right = int(screen_width/2 - window_width/2)
    popup.geometry(f'{window_width}x{window_height}+{position_right}+{position_top}')

    # Funzioni per il trascinamento della finestra
    def start_move(event):
        popup.x = event.x
        popup.y = event.y

    def do_move(event):
        delta_x = event.x - popup.x
        delta_y = event.y - popup.y
        x = popup.winfo_x() + delta_x
        y = popup.winfo_y() + delta_y
        popup.geometry(f'+{x}+{y}')

    # Associare le funzioni agli eventi del mouse
    popup.bind('<Button-1>', start_move)
    popup.bind('<B1-Motion>', do_move)

    # Visualizzare alcuni campi del response
    title_label = tk.Label(popup, text=f"Title: {data['title']}", bg=bg_color)
    title_label.pack(pady=10)

    body_label = tk.Label(popup, text=f"Body: {data['body']}", bg=bg_color)
    body_label.pack(pady=10)

    # Visualizzare la stringa generata
    random_string_label = tk.Label(popup, text=f"Random String: {data['random_string']}", bg=bg_color)
    random_string_label.pack(pady=10)

    # Countdown
    countdown_label = tk.Label(popup, text="", bg=bg_color)
    countdown_label.pack(pady=10)
    countdown_seconds = 2

    def update_countdown(seconds):
        if seconds > 0:
            countdown_label.config(text=f"Chiudo in {seconds} secondi...")
            popup.after(1000, update_countdown, seconds - 1)
        else:
            root.quit()

    update_countdown(countdown_seconds)

    # Aggiungere il gestore di segnale per SIGINT (Ctrl+C)
    signal.signal(signal.SIGINT, signal_handler)

    popup.mainloop()

def show_error(status_code):
    root = tk.Tk()
    root.withdraw()
    messagebox.showerror("Errore", f"Errore nella richiesta: {status_code}")
    root.destroy()

def signal_handler(sig, frame):
    print("Interruzione rilevata! Chiudendo...")
    root.quit()
    sys.exit(0)
    
def generate_random_string(length=10):
    letters = string.ascii_letters
    return ''.join(random.choice(letters) for i in range(length))

if __name__ == '__main__':
    """ MAIN func """
    write_json_file( id_path, id_info, force=True)
    read_json_file(id_path)
    fetch_data()


