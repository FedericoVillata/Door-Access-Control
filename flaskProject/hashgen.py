
import hashlib

def generate_md5(input_string):
    # Create an md5 hash object
    md5_hash = hashlib.md5()
    
    # Update the hash object with the bytes of the input string
    md5_hash.update(input_string.encode('utf-8'))
    
    # Get the hexadecimal representation of the hash
    return md5_hash.hexdigest()

# Example usage
if __name__ == "__main__":
    password = "fede"
    hashed_password = generate_md5(password)
    print(f"passworddd : {hashed_password}")  # Prints the MD5 hash of the password