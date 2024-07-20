import jwt
import datetime

# Chiave segreta per firmare il token
SECRET_KEY = 'your_secret_key'

# Funzione per generare un token JWT
def generate_jwt_token(payload):
    # Imposta la data di scadenza del token (1 ora)
    expire_time = datetime.datetime.utcnow() + datetime.timedelta(hours=1)
    
    # Aggiunge la data di scadenza al payload
    payload['exp'] = expire_time
    
    # Genera il token JWT utilizzando la chiave segreta
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    
    return token

# Funzione per verificare un token JWT
def verify_jwt_token(token):
    try:
        # Decodifica il token JWT utilizzando la chiave segreta
        decoded_payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return decoded_payload
    except jwt.ExpiredSignatureError:
        # Il token è scaduto
        print("Il token è scaduto.")
        return None
    except jwt.InvalidTokenError:
        # Il token non è valido
        print("Il token non è valido.")
        return None

# Esempio di utilizzo
if __name__ == "__main__":
    # Esempio di generazione di un token
    user_payload = {'username': 'john_doe', 'role': 'admin'}
    jwt_token = generate_jwt_token(user_payload)
    print("Token JWT generato:", jwt_token)

    # Esempio di verifica di un token
    decoded_payload = verify_jwt_token(jwt_token)
    if decoded_payload:
        print("Token JWT verificato. Payload:", decoded_payload)
