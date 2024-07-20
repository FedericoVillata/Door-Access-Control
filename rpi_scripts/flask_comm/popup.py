import tkinter as tk
from tkinter import messagebox
import signal
import sys

def show_popup(data, time):
    # Creare la finestra principale
    global root
    root = tk.Tk()
    root.withdraw()  # Nascondere la finestra principale

    # Creare la finestra pop-up
    popup = tk.Toplevel()
    popup.title("Dati della risposta")
    popup.overrideredirect(True)  # Rimuovere i bordi della finestra

    # Cambiare il colore di sfondo della finestra pop-up in base al valore di status
    bg_color = data["color"]
    popup.configure(bg=bg_color)

    # Centrare la finestra pop-up
    window_width = 400
    window_height = 200
    screen_width = popup.winfo_screenwidth()
    screen_height = popup.winfo_screenheight()
    position_top = int(screen_height / 2 - window_height / 2)
    position_right = int(screen_width / 2 - window_width / 2)
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
    title_label = tk.Label(popup, text=f"Username: {data.get('username', 'N/A')}", bg=bg_color)
    title_label.pack(pady=10)

    body_label = tk.Label(popup, text=f"Message: {data.get('message', 'N/A')}", bg=bg_color)
    body_label.pack(pady=10)


    # Countdown
    countdown_label = tk.Label(popup, text="", bg=bg_color)
    countdown_label.pack(pady=10)
    countdown_seconds = time

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

def test():
    # Dizionario da visualizzare nel popup
    # data = {'message': 'Check-in successful', 'status': True, 'username': 'fede'}
    data = {'message': 'Check-in successful', 'status': False, 'username': 'fede', "color" : "yellow"}

    # Chiamare la funzione show_popup con il dizionario fornito
    show_popup(data, 3)
