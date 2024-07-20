from flask import Flask, redirect, request

app = Flask(__name__)

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def redirect_to_port(path):
    return redirect(f'http://{request.host.split(":")[0]}:5000/{path}', code 302)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
