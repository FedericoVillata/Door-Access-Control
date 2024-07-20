from flask import Flask, request, jsonify
import random
import string

app = Flask(__name__)

def generate_random_string(length=10):
    letters = string.ascii_letters
    return ''.join(random.choice(letters) for i in range(length))

@app.route('/api/data', methods=['POST'])
def get_data():
    number = request.json.get('number', 0)
    random_bool = (number % 2 == 0)  # True se il numero è pari, False se dispari
    random_string = generate_random_string()

    data = {
        'title': random_string,
        'body': 'This is a test message from the Flask server.',
        'random_bool': random_bool,
        'random_string': random_string
    }
    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)

