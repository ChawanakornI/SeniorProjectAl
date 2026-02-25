#!/usr/bin/env python3
"""Admin script to manage users in users.json"""
"to run this script, run python admin_user_manager.py"


import json
from pathlib import Path
from getpass import getpass
import bcrypt
import os


USERS_FILE = Path(__file__).parent / "users.json"


# ANSI Color codes
class Colors:
    """ANSI color codes for terminal output."""
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"

    # Text colors
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"

    # Bright colors
    BRIGHT_BLACK = "\033[90m"
    BRIGHT_RED = "\033[91m"
    BRIGHT_GREEN = "\033[92m"
    BRIGHT_YELLOW = "\033[93m"
    BRIGHT_BLUE = "\033[94m"
    BRIGHT_MAGENTA = "\033[95m"
    BRIGHT_CYAN = "\033[96m"
    BRIGHT_WHITE = "\033[97m"


def clear_screen():
    """Clear the terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')


def print_banner():
    """Print a colorful banner."""
    banner = f"""
{Colors.BRIGHT_CYAN}
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              {Colors.BRIGHT_WHITE}🔐  USER MANAGEMENT ADMIN TOOL  🔐{Colors.BRIGHT_CYAN}              ║
║                                                              ║
║                {Colors.DIM}Healthcare System User Manager{Colors.RESET}{Colors.BRIGHT_CYAN}                ║
╚══════════════════════════════════════════════════════════════╝{Colors.RESET}
"""
    print(banner)


def print_section_header(title, icon=""):
    """Print a styled section header."""
    print(f"\n{Colors.BRIGHT_YELLOW}┌{'─' * 60}┐{Colors.RESET}")
    print(f"{Colors.BRIGHT_YELLOW}│{Colors.RESET} {Colors.BOLD}{Colors.BRIGHT_WHITE}{icon} {title}{Colors.RESET}")
    print(f"{Colors.BRIGHT_YELLOW}└{'─' * 60}┘{Colors.RESET}\n")


def print_success(message):
    """Print a success message."""
    print(f"{Colors.BRIGHT_GREEN}✓ {message}{Colors.RESET}")


def print_error(message):
    """Print an error message."""
    print(f"{Colors.BRIGHT_RED}✗ {message}{Colors.RESET}")


def print_info(message):
    """Print an info message."""
    print(f"{Colors.BRIGHT_CYAN}ℹ {message}{Colors.RESET}")


def print_warning(message):
    """Print a warning message."""
    print(f"{Colors.BRIGHT_YELLOW}⚠ {message}{Colors.RESET}")


def load_users():
    """Load users from JSON file."""
    if not USERS_FILE.exists():
        return {}
    try:
        with open(USERS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def save_users(users):
    """Save users to JSON file."""
    with open(USERS_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, indent=2, ensure_ascii=False)
    print_success(f"Users saved to {Colors.DIM}{USERS_FILE}{Colors.RESET}")


def hash_password(password):
    """Hash a password using bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def generate_next_user_id(users):
    """Generate next user ID in format user00X."""
    if not users:
        return "user001"

    existing_ids = [
        int(uid.replace("user", ""))
        for uid in users.keys()
        if uid.startswith("user") and uid[4:].isdigit()
    ]

    if not existing_ids:
        return "user001"

    next_num = max(existing_ids) + 1
    return f"user{next_num:03d}"


def add_user():
    """Add a new user."""
    print_section_header("Add New User", "➕")

    users = load_users()

    # User ID input
    print(f"{Colors.CYAN}User ID{Colors.RESET}")
    user_id = input(f"{Colors.DIM}Enter user ID (press Enter to auto-generate): {Colors.RESET}").strip()
    if not user_id:
        user_id = generate_next_user_id(users)
        print_info(f"Auto-generated ID: {Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}")

    if user_id in users:
        print_error(f"User ID '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}' already exists!")
        return

    # First name input
    print(f"\n{Colors.CYAN}First Name{Colors.RESET}")
    first_name = input(f"{Colors.DIM}Enter first name: {Colors.RESET}").strip()
    if not first_name:
        print_error("First name cannot be empty!")
        return

    # Last name input
    print(f"\n{Colors.CYAN}Last Name{Colors.RESET}")
    last_name = input(f"{Colors.DIM}Enter last name: {Colors.RESET}").strip()
    if not last_name:
        print_error("Last name cannot be empty!")
        return
    # Role selection
    print(f"\n{Colors.CYAN}Role{Colors.RESET}")
    print(f"  {Colors.BRIGHT_GREEN}1.{Colors.RESET} GP (General Practitioner)")
    print(f"  {Colors.BRIGHT_BLUE}2.{Colors.RESET} Doctor")
    print(f"  {Colors.BRIGHT_MAGENTA}3.{Colors.RESET} Admin")
    role_choice = input(f"{Colors.DIM}Enter choice (1, 2, or 3): {Colors.RESET}").strip()

    if role_choice == "1":
        role = "gp"
        role_display = f"{Colors.BRIGHT_GREEN}GP{Colors.RESET}"
    elif role_choice == "2":
        role = "doctor"
        role_display = f"{Colors.BRIGHT_BLUE}Doctor{Colors.RESET}"
    elif role_choice == "3":
        role = "admin"
        role_display = f"{Colors.BRIGHT_MAGENTA}Admin{Colors.RESET}"
    else:
        print_error("Invalid role choice!")
        return

    # Password input
    print(f"\n{Colors.CYAN}Password{Colors.RESET}")
    password = getpass(f"{Colors.DIM}Enter password: {Colors.RESET}")
    if not password:
        print_error("Password cannot be empty!")
        return

    confirm_password = getpass(f"{Colors.DIM}Confirm password: {Colors.RESET}")
    if password != confirm_password:
        print_error("Passwords do not match!")
        return

    password_hash = hash_password(password)

    users[user_id] = {
        "password_hash": password_hash,
        "first_name": first_name,
        "last_name": last_name,
        "role": role
    }

    save_users(users)

    # Success summary
    print(f"\n{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")
    print_success(f"User '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}' added successfully!")
    print(f"{Colors.DIM}  Name:{Colors.RESET} {first_name} {last_name}")
    print(f"{Colors.DIM}  Role:{Colors.RESET} {role_display}")
    print(f"{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")


def list_users():
    """List all users."""
    users = load_users()

    if not users:
        print_section_header("User List", "📋")
        print_warning("No users found in the system.")
        return

    print_section_header(f"User List ({len(users)} total)", "📋")

    # Table header
    print(f"{Colors.BOLD}{Colors.BRIGHT_WHITE}{'User ID':<12} {'Name':<30} {'Role':<15}{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLACK}{'─' * 12} {'─' * 30} {'─' * 15}{Colors.RESET}")

    # Table rows
    for user_id, user_data in sorted(users.items()):
        name = f"{user_data['first_name']} {user_data['last_name']}"
        role = user_data['role']

        # Color code the role
        if role == "gp":
            role_colored = f"{Colors.BRIGHT_GREEN}GP{Colors.RESET}"
        elif role == "doctor":
            role_colored = f"{Colors.BRIGHT_BLUE}Doctor{Colors.RESET}"
        elif role == "admin":
            role_colored = f"{Colors.BRIGHT_MAGENTA}Admin{Colors.RESET}"
        else:
            role_colored = role

        # Print row with user ID highlighted
        print(f"{Colors.BRIGHT_CYAN}{user_id:<12}{Colors.RESET} {name:<30} {role_colored}")

    print(f"{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")


def delete_user():
    """Delete a user."""
    print_section_header("Delete User", "🗑️")

    users = load_users()

    if not users:
        print_warning("No users to delete.")
        return

    print(f"{Colors.CYAN}User ID{Colors.RESET}")
    user_id = input(f"{Colors.DIM}Enter user ID to delete: {Colors.RESET}").strip()

    if user_id not in users:
        print_error(f"User ID '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}' not found!")
        return

    user_data = users[user_id]

    # Show user details
    print(f"\n{Colors.BRIGHT_RED}┌{'─' * 60}┐{Colors.RESET}")
    print(f"{Colors.BRIGHT_RED}│{Colors.RESET} {Colors.BOLD}User to be deleted:{Colors.RESET}")
    print(f"{Colors.BRIGHT_RED}│{Colors.RESET}")
    print(f"{Colors.BRIGHT_RED}│{Colors.RESET}   {Colors.DIM}ID:{Colors.RESET}   {Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}")
    print(f"{Colors.BRIGHT_RED}│{Colors.RESET}   {Colors.DIM}Name:{Colors.RESET} {user_data['first_name']} {user_data['last_name']}")
    print(f"{Colors.BRIGHT_RED}│{Colors.RESET}   {Colors.DIM}Role:{Colors.RESET} {user_data['role'].upper()}")
    print(f"{Colors.BRIGHT_RED}└{'─' * 60}┘{Colors.RESET}")

    print(f"\n{Colors.BRIGHT_RED}⚠️  WARNING: This action cannot be undone!{Colors.RESET}")
    confirm = input(f"\n{Colors.BOLD}Type 'yes' to confirm deletion: {Colors.RESET}").strip().lower()

    if confirm == "yes":
        del users[user_id]
        save_users(users)
        print(f"\n{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")
        print_success(f"User '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}' deleted successfully!")
        print(f"{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")
    else:
        print_info("Deletion cancelled.")


def change_password():
    """Change user password."""
    print_section_header("Change Password", "🔑")

    users = load_users()

    if not users:
        print_warning("No users found.")
        return

    print(f"{Colors.CYAN}User ID{Colors.RESET}")
    user_id = input(f"{Colors.DIM}Enter user ID: {Colors.RESET}").strip()

    if user_id not in users:
        print_error(f"User ID '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}' not found!")
        return

    user_data = users[user_id]

    # Display user info
    print(f"\n{Colors.BRIGHT_BLUE}┌{'─' * 60}┐{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}│{Colors.RESET} {Colors.BOLD}Changing password for:{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}│{Colors.RESET}   {user_data['first_name']} {user_data['last_name']} {Colors.DIM}({user_id}){Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}└{'─' * 60}┘{Colors.RESET}")

    print(f"\n{Colors.CYAN}New Password{Colors.RESET}")
    new_password = getpass(f"{Colors.DIM}Enter new password: {Colors.RESET}")
    if not new_password:
        print_error("Password cannot be empty!")
        return

    confirm_password = getpass(f"{Colors.DIM}Confirm new password: {Colors.RESET}")
    if new_password != confirm_password:
        print_error("Passwords do not match!")
        return

    users[user_id]["password_hash"] = hash_password(new_password)
    save_users(users)

    print(f"\n{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")
    print_success(f"Password changed successfully for '{Colors.BRIGHT_WHITE}{user_id}{Colors.RESET}'!")
    print(f"{Colors.BRIGHT_GREEN}{'─' * 60}{Colors.RESET}")


def main():
    """Main menu loop."""
    clear_screen()
    print_banner()

    while True:
        # Main menu
        print(f"\n{Colors.BRIGHT_MAGENTA}┌{'─' * 60}┐{Colors.RESET}")
        print(f"{Colors.BRIGHT_MAGENTA}│{Colors.RESET} {Colors.BOLD}{Colors.BRIGHT_WHITE}Main Menu{Colors.RESET}")
        print(f"{Colors.BRIGHT_MAGENTA}└{'─' * 60}┘{Colors.RESET}")

        print(f"\n  {Colors.BRIGHT_CYAN}1.{Colors.RESET} ➕  Add new user")
        print(f"  {Colors.BRIGHT_CYAN}2.{Colors.RESET} 📋  List all users")
        print(f"  {Colors.BRIGHT_CYAN}3.{Colors.RESET} 🗑️   Delete user")
        print(f"  {Colors.BRIGHT_CYAN}4.{Colors.RESET} 🔑  Change password")
        print(f"  {Colors.BRIGHT_RED}5.{Colors.RESET} 🚪  Exit")

        print(f"\n{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
        choice = input(f"{Colors.BOLD}Enter choice (1-5): {Colors.RESET}").strip()

        if choice == "1":
            add_user()
        elif choice == "2":
            list_users()
        elif choice == "3":
            delete_user()
        elif choice == "4":
            change_password()
        elif choice == "5":
            print(f"\n{Colors.BRIGHT_CYAN}╔{'═' * 60}╗{Colors.RESET}")
            print(f"{Colors.BRIGHT_CYAN}║{Colors.RESET}       {Colors.BRIGHT_WHITE}Thank you for using the User Management Tool!{Colors.RESET}       {Colors.BRIGHT_CYAN}║{Colors.RESET}")
            print(f"{Colors.BRIGHT_CYAN}╚{'═' * 60}╝{Colors.RESET}\n")
            break
        else:
            print_error("Invalid choice. Please enter 1-5.")

        # Pause before showing menu again
        input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.BRIGHT_YELLOW}Operation cancelled by user.{Colors.RESET}")
        print(f"{Colors.DIM}Goodbye!{Colors.RESET}\n")
