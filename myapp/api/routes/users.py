from flask import Blueprint, jsonify, request, current_app

user_bp = Blueprint("users", __name__)


@user_bp.route("/")
def list_users():
    current_app.logger.info("GET /api/users")
    return jsonify({"users": []})


@user_bp.route("/<int:user_id>")
def get_user(user_id):
    current_app.logger.info(f"GET /api/users/{user_id}")
    return jsonify({"id": user_id})


@user_bp.route("/", methods=["POST"])
def create_user():
    current_app.logger.info("POST /api/users")
    data = request.get_json(silent=True) or {}
    return jsonify({"status": "created", "data": data}), 201
