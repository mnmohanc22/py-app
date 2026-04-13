# app.py
# Run with: python3 app.py
# No wsgi.py, no gunicorn, no .env needed

from flask import Flask, jsonify, request

app = Flask(__name__)

# ── Routes ────────────────────────────────────────────────────

@app.route('/')
def home():
    return jsonify({'message': 'hello from flask', 'status': 'ok'})

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

@app.route('/greet/<name>')
def greet(name):
    return jsonify({'greeting': f'hello {name}!'})

@app.route('/add', methods=['POST'])
def add():
    data = request.get_json()
    a = data.get('a', 0)
    b = data.get('b', 0)
    return jsonify({'result': a + b})

# # ── Entry point ───────────────────────────────────────────────

# if __name__ == '__main__':
#     app.run(
#         host='0.0.0.0',
#         port=5001,
#         debug=True     # auto-reload on code change
#     )