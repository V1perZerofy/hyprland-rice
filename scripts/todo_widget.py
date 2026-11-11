#!/usr/bin/env python3
import gi
import json
import os
from html import escape

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, Gdk


TODO_FILE = os.path.expanduser("~/.local/share/todo_list.json")
WAL_FILE = os.path.expanduser("~/.cache/wal/colors.json")


def load_wal_colors():
    """Load pywal colors from ~/.cache/wal/colors.json"""
    default = {
        "background": "#1e1e2e",
        "foreground": "#cdd6f4",
        "accent": "#89b4fa",
    }
    if os.path.exists(WAL_FILE):
        try:
            with open(WAL_FILE) as f:
                data = json.load(f)
                colors = data.get("colors", {})
                return {
                    "background": colors.get("color0", default["background"]),
                    "foreground": colors.get("color7", default["foreground"]),
                    "accent": colors.get("color2", default["accent"]),
                }
        except Exception:
            pass
    return default


class TodoApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="com.hypr.todo", flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.todos = []
        self.colors = load_wal_colors()

    def do_activate(self):
        self.win = Adw.ApplicationWindow(application=self)
        self.win.set_title("To-Do")
        self.win.set_default_size(320, 420)
        self.win.set_decorated(False)
        self.win.set_resizable(True)
        self.win.set_modal(False)
        self.win.set_hide_on_close(True)

        self.setup_css()

        # Create layout
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin_top=10, margin_bottom=10, margin_start=10, margin_end=10)
        self.win.set_content(vbox)

        # Input field
        self.entry = Gtk.Entry(placeholder_text="Add a new task…")
        self.entry.connect("activate", self.add_task)
        vbox.append(self.entry)

        # Scrolled List
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        vbox.append(scrolled)

        self.listbox = Gtk.ListBox()
        scrolled.set_child(self.listbox)

        # Load todos
        self.todos = self.load_todos()
        self.populate_list()

        # ESC to close
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self.on_key_pressed)
        self.win.add_controller(controller)

        self.win.present()

    def setup_css(self):
        css = f"""
        window {{
            background-color: {self.colors['background']};
            border-radius: 14px;
            color: {self.colors['foreground']};
        }}
        entry {{
            background-color: shade({self.colors['background']}, 1.2);
            color: {self.colors['foreground']};
            border-radius: 8px;
            padding: 6px;
        }}
        listbox, scrolledwindow {{
            background-color: {self.colors['background']};
        }}
        listbox > row {{
            background-color: {self.colors['background']};
            border-radius: 6px;
            padding: 4px;
        }}
        button {{
            background-color: transparent;
            color: {self.colors['accent']};
            border: none;
            font-weight: bold;
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def on_key_pressed(self, controller, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.quit()

    def load_todos(self):
        if not os.path.exists(TODO_FILE):
            return []
        with open(TODO_FILE, "r") as f:
            return json.load(f)

    def save_todos(self):
        os.makedirs(os.path.dirname(TODO_FILE), exist_ok=True)
        with open(TODO_FILE, "w") as f:
            json.dump(self.todos, f, indent=2)

    def populate_list(self):
        for row in self.listbox.get_children():
            self.listbox.remove(row)
        for i, todo in enumerate(self.todos):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            check = Gtk.CheckButton()
            check.set_active(todo["done"])
            check.connect("toggled", self.toggle_task, i)

            text = escape(todo["text"])
            label = Gtk.Label(xalign=0)
            label.set_use_markup(True)
            if todo["done"]:
                label.set_markup(f"<span foreground='{self.colors['foreground']}'><s>{text}</s></span>")
            else:
                label.set_markup(f"<span foreground='{self.colors['foreground']}'>{text}</span>")

            del_btn = Gtk.Button.new_with_label("×")
            del_btn.connect("clicked", self.delete_task, i)

            row.append(check)
            row.append(label)
            row.append(del_btn)
            self.listbox.append(row)
        self.listbox.show()

    def add_task(self, entry):
        text = entry.get_text().strip()
        if text:
            self.todos.append({"text": text, "done": False})
            self.save_todos()
            self.populate_list()
            entry.set_text("")

    def toggle_task(self, check, index):
        self.todos[index]["done"] = check.get_active()
        self.save_todos()
        self.populate_list()

    def delete_task(self, button, index):
        del self.todos[index]
        self.save_todos()
        self.populate_list()


if __name__ == "__main__":
    app = TodoApp()
    app.run()

