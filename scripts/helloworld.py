import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gio, GObject

# Task model as a GObject with string property "name"
class Task(GObject.GObject):
    name = GObject.Property(type=str)

    def __init__(self, name):
        super().__init__()
        self.name = name

# Setup for each list item: create a label
def list_item_setup(factory, list_item):
    label = Gtk.Label()
    list_item.set_child(label)

# Bind the task data to the label
def list_item_bind(factory, list_item):
    task = list_item.get_item()
    label = list_item.get_child()
    label.set_text(task.name)

class TodoWindow(Gtk.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("GTK4 To-Do List")
        self.set_default_size(300, 400)

        # Vertical layout
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin=12)
        self.set_child(vbox)

        # Entry for new task input
        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Enter a new task and press Enter")
        self.entry.connect("activate", self.on_task_entered)
        vbox.append(self.entry)

        # ListStore as model for tasks (holding Task objects)
        self.task_store = Gio.ListStore(item_type=Task)

        # Create ListView with factory to display tasks
        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", list_item_setup)
        factory.connect("bind", list_item_bind)

        selection = Gtk.SingleSelection(model=self.task_store)
        self.list_view = Gtk.ListView(factory=factory, model=selection)
        vbox.append(self.list_view)

        # Button to remove selected task
        self.remove_button = Gtk.Button(label="Remove Selected Task")
        self.remove_button.connect("clicked", self.on_remove_clicked)
        vbox.append(self.remove_button)

    def on_task_entered(self, entry):
        text = entry.get_text().strip()
        if text:
            self.task_store.append(Task(text))
            entry.set_text("")

    def on_remove_clicked(self, button):
        selection = self.list_view.get_model().get_selection()
        selected_index = selection.get_selected()
        if selected_index >= 0:
            self.task_store.remove(selected_index)

class TodoApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.example.Gtk4Todo")

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = TodoWindow(application=self)
        win.present()

app = TodoApp()
app.run(None)

