import logging

def setup_logger(log_file=None):
    # Definizione del logger
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)  # Impostazione livello di log (DEBUG, INFO, WARNING, ERROR, CRITICAL)

    # Formatter per formattare i messaggi di log
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

    # Handler per gestire l'output dei log su console
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # Se specificato, aggiungi anche un handler per salvare i log su file
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

def log(message):
    logging.debug(message)

def main():
    # Esempio di utilizzo della funzione di log
    setup_logger("my_log_file.log")  # Imposta il logger per scrivere su un file di log

    # Esempi di log
    logging.debug("Questo è un messaggio di debug")
    logging.info("Questo è un messaggio informativo")
    logging.warning("Questo è un avviso")
    logging.error("Questo è un errore")
    logging.critical("Questo è un errore critico")
    

if __name__ == "__main__":
    main()
