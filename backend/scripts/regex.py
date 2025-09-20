import re
import json
import os

# Define the regex file path
regex_db_path = "./regex.json"
#regex_db_path = "./scripts/regex.json"


# Initial loaded_patterns with example data
loaded_patterns = {
    "nome": {
        "re_format": '^[A-Za-zÀ-ÖØ-öø-ÿ\'-]+$',
        "flag": True,
        "suggestion": "Mario"
    },
    "cognome": {
        "re_format": '^[A-Za-zÀ-ÖØ-öø-ÿ\'-]+$',
        "flag": True,
        "suggestion": "Rossi"
    },
    "username": {
        "re_format": '^[A-Za-z0-9_\\-]{3,16}$',
        "flag": True,
        "suggestion": "user_123"
    },
    "fiscal_code": {
        "re_format": '^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$',
        "flag": True,
        "suggestion": "RSSMRA85M01H501Z"
    },
    "phone_number": {
        "re_format": '^\\+?\\d{10,15}$',
        "flag": True,
        "suggestion": "+391234567890"
    },
    "RFID_number": {
        "re_format": '^\\+?\\d{10,15}$',
        "flag": True,
        "suggestion": "123456789011"
    },
    "mail": {
        "re_format": '^[\\w\\.-]+@[\\w\\.-]+\\.\\w+$',
        "flag": True,
        "suggestion": "example@example.com"
    },
    "birth_date": {
        "re_format": '^\\d{2}/\\d{2}/\\d{4}$',
        "flag": True,
        "suggestion": "01/01/2000"
    },
    "gender": {
        "re_format": '^(male|female|maschio|femmina|other)$',
        "flag": True,
        "suggestion": "male|female|maschio|femmina|other"
    },
    "companyName": {
        "re_format": "^[A-Za-z0-9À-ÖØ-öø-ÿ'\\s-]+$",
        "flag": True,
        "suggestion": "Example Company"
    },
    "VAT_number": {
        "re_format": "^[A-Z0-9]{8,12}$",
        "flag": True,
        "suggestion": "EU12345678"
    },
    "PEC": {
        "re_format": "^[\\w\\.-]+@[\\w\\.-]+\\.\\w+$",
        "flag": True,
        "suggestion": "exampl@pec.com"
    },
    "subscription": {
        "re_format": "^(basic|premium|enterprise)$",
        "flag": True,
        "suggestion": "basic"
    },
    "country": {
        "re_format": "^[A-Za-z\\s]+$",
        "flag": True,
        "suggestion": "Italy"
    }
}

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

def load_patterns():
    global loaded_patterns
    loaded_patterns_temp = read_json_file(regex_db_path)
    if loaded_patterns_temp is not None:
        loaded_patterns = loaded_patterns_temp

def regex_full_check(db_entry):
    global load_patterns
    write_json_file(regex_db_path, loaded_patterns, True)
    load_patterns()
    for key, value in db_entry.items():
        if key in loaded_patterns and loaded_patterns[key]["flag"]:
            pattern = loaded_patterns[key]["re_format"]
            match_test = re.match(pattern, str(value))
            #print(f"Match result for key '{key}': {match_test}")
            if not match_test:
                return False, key, loaded_patterns[key]["suggestion"]
        else:
            pass
            #print(f"No pattern found for key '{key}' or pattern is disabled.")
    return True, "OK", ""


def test():
    test = {
        "nome": "Mario",
        "cognome": "Rossi",
        "eta": 30,
        "gender": "ga"
    }

    write_json_file(regex_db_path, loaded_patterns)
    is_valid = regex_full_check(test)
    print("Is the entry valid?", is_valid)

# test()