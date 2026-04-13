from flask import Blueprint, jsonify, request, current_app

user_bp = Blueprint("users", __name__)

# ── Dummy data ────────────────────────────────────────────────
USERS = [
    {"id": 1, "name": "Alice Johnson",  "email": "alice@example.com",  "role": "admin"},
    {"id": 2, "name": "Bob Smith",      "email": "bob@example.com",    "role": "user"},
    {"id": 3, "name": "Carol Williams", "email": "carol@example.com",  "role": "user"},
    {"id": 4, "name": "David Brown",    "email": "david@example.com",  "role": "editor"},
    {"id": 5, "name": "Eve Davis",      "email": "eve@example.com",    "role": "user"},
]


@user_bp.route("/")
def list_users():
    current_app.logger.info("GET /api/users")
    return jsonify({"users": USERS})


@user_bp.route("/<int:user_id>")
def get_user(user_id):
    current_app.logger.info(f"GET /api/users/{user_id}")
    user = next((u for u in USERS if u["id"] == user_id), None)
    if user is None:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user)


@user_bp.route("/", methods=["POST"])
def create_user():
    current_app.logger.info("POST /api/users")
    data = request.get_json(silent=True) or {}
    new_id = max(u["id"] for u in USERS) + 1 if USERS else 1
    new_user = {"id": new_id, "name": data.get("name", ""), "email": data.get("email", ""), "role": data.get("role", "user")}
    USERS.append(new_user)
    return jsonify({"status": "created", "data": new_user}), 201
