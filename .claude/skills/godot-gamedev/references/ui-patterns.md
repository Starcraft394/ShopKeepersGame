# UI Patterns Reference

Control node best practices and dynamic UI generation for Godot 4.5+.

## Control Node Hierarchy

### Container Types

| Container | Use Case |
|-----------|----------|
| **VBoxContainer** | Vertical lists (menus, item lists) |
| **HBoxContainer** | Horizontal rows (buttons, stats) |
| **GridContainer** | Grid layouts (inventory grids) |
| **MarginContainer** | Add padding around content |
| **ScrollContainer** | Scrollable content areas |
| **PanelContainer** | Visual grouping with background |

### Layout Pattern

```
Window (popup or main)
└── MarginContainer (padding)
    └── VBoxContainer (main layout)
        ├── Label (title)
        ├── HSeparator
        ├── ScrollContainer
        │   └── VBoxContainer (content list)
        │       ├── Item Row 1
        │       ├── Item Row 2
        │       └── ...
        ├── HSeparator
        └── HBoxContainer (buttons)
            ├── Button (action)
            └── Button (close)
```

## Dynamic UI Generation

### Building Lists

```gdscript
func _build_item_list(items: Array) -> void:
    # Clear existing children safely
    for child in _container.get_children():
        child.queue_free()

    # Wait for queue_free to process (optional but safer)
    await get_tree().process_frame

    # Build new UI
    for item in items:
        var row = _create_item_row(item)
        _container.add_child(row)

func _create_item_row(item: Dictionary) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)

    # Name label
    var name_label = Label.new()
    name_label.text = item.display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_label)

    # Quantity label
    var qty_label = Label.new()
    qty_label.text = "x%d" % item.qty
    qty_label.custom_minimum_size.x = 50
    row.add_child(qty_label)

    # Action button
    var button = Button.new()
    button.text = "Use"
    button.pressed.connect(_on_item_use.bind(item.id))
    row.add_child(button)

    return row
```

### Immediate Clear Pattern

```gdscript
# For containers that refresh frequently, avoid queue_free delays
func _clear_children_immediate(container: Control) -> void:
    while container.get_child_count() > 0:
        var child = container.get_child(0)
        container.remove_child(child)
        child.free()  # Immediate, not queued
```

## Signal Wiring

### Button Connections with Data

```gdscript
# Connect with bound parameter
button.pressed.connect(_on_button_pressed.bind(item_id))

func _on_button_pressed(item_id: String) -> void:
    print("Selected: %s" % item_id)
```

### Disconnect Before Reconnect

```gdscript
# Prevent duplicate connections
if button.pressed.is_connected(_on_button_pressed):
    button.pressed.disconnect(_on_button_pressed)
button.pressed.connect(_on_button_pressed.bind(new_data))
```

### Signal Chains

```gdscript
# Child emits event
class_name ItemRow
signal item_selected(item_id: String)

func _on_select_pressed() -> void:
    item_selected.emit(_item_id)

# Parent connects and handles
func _create_item_row(item: Dictionary) -> ItemRow:
    var row = ItemRow.new()
    row.setup(item)
    row.item_selected.connect(_on_item_selected)
    return row

func _on_item_selected(item_id: String) -> void:
    # Handle selection at parent level
    _selected_item = item_id
    _refresh_details_panel()
```

## Theming

### Theme Resource Structure

```
Themes/
└── game_theme.tres
    ├── Button
    │   ├── styles/normal (StyleBoxFlat)
    │   ├── styles/hover (StyleBoxFlat)
    │   ├── styles/pressed (StyleBoxFlat)
    │   └── colors/font_color
    ├── Label
    │   └── colors/font_color
    ├── Panel
    │   └── styles/panel (StyleBoxFlat)
    └── HSeparator
        └── styles/separator (StyleBoxLine)
```

### Applying Themes

```gdscript
# Apply to root control (cascades to children)
func _ready() -> void:
    var theme = preload("res://Themes/game_theme.tres")
    self.theme = theme
```

### Theme Overrides (Sparingly)

```gdscript
# Override specific properties when theme doesn't fit
label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))  # Gold
label.add_theme_font_size_override("font_size", 18)

# Better: Create theme variation in .tres file
```

### Color Conventions

```gdscript
# Standard colors (define as constants or in theme)
const COLOR_GOLD = Color(1, 0.9, 0.5)
const COLOR_SUCCESS = Color(0.5, 1, 0.5)
const COLOR_ERROR = Color(1, 0.5, 0.5)
const COLOR_DISABLED = Color(0.5, 0.5, 0.5)
const COLOR_HEADER = Color(0.9, 0.8, 0.5)
```

## RichTextLabel Patterns

### BBCode for Colored Text

```gdscript
var label = RichTextLabel.new()
label.bbcode_enabled = true
label.fit_content = true
label.scroll_active = false

# Colored text
label.text = "[color=green]+5 Attack[/color]"
label.text = "[color=red]-3 Defense[/color]"

# Bold and italic
label.text = "[b]Important[/b] and [i]emphasis[/i]"

# Combined
label.text = "[color=gold][b]LEGENDARY[/b][/color] Sword"
```

### Dynamic BBCode Building

```gdscript
func _format_stat_change(stat: String, value: int) -> String:
    var color = "green" if value > 0 else "red"
    var sign = "+" if value > 0 else ""
    return "[color=%s]%s%d %s[/color]" % [color, sign, value, stat]

# Usage
var text = _format_stat_change("Attack", 5)  # [color=green]+5 Attack[/color]
```

## Window/Popup Patterns

### Modal Windows

```gdscript
var _popup: Window

func _show_popup(title: String, content: Control) -> void:
    if _popup != null:
        _popup.queue_free()

    _popup = Window.new()
    _popup.title = title
    _popup.size = Vector2(400, 300)
    _popup.transient = true
    _popup.exclusive = true
    _popup.close_requested.connect(_on_popup_close)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    margin.add_child(content)

    _popup.add_child(margin)
    add_child(_popup)
    _popup.popup_centered()

func _on_popup_close() -> void:
    if _popup != null:
        _popup.queue_free()
        _popup = null
```

### Confirmation Dialog

```gdscript
func _show_confirm(message: String, on_confirm: Callable) -> void:
    var dialog = ConfirmationDialog.new()
    dialog.dialog_text = message
    dialog.confirmed.connect(func():
        on_confirm.call()
        dialog.queue_free()
    )
    dialog.canceled.connect(func():
        dialog.queue_free()
    )
    add_child(dialog)
    dialog.popup_centered()
```

## Responsive Sizing

### Size Flags

```gdscript
# Expand to fill available space
control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
control.size_flags_vertical = Control.SIZE_EXPAND_FILL

# Shrink to minimum size
control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

# Fixed minimum size
control.custom_minimum_size = Vector2(100, 50)
```

### Anchors and Margins

```gdscript
# Full screen overlay
overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

# Centered panel
panel.set_anchors_preset(Control.PRESET_CENTER)
panel.custom_minimum_size = Vector2(400, 300)
```

## Performance Tips

### Avoid Frequent Rebuilds

```gdscript
# Bad: Rebuild entire list on every change
func _on_item_changed() -> void:
    _build_entire_list()  # Expensive

# Good: Update only affected row
func _on_item_changed(item_id: String) -> void:
    var row = _find_row_by_id(item_id)
    if row != null:
        row.refresh()
```

### Visibility Over Removal

```gdscript
# For frequently toggled elements, hide instead of remove
row.visible = should_show

# Only use queue_free for permanent removal
```

### Lazy Panel Loading

```gdscript
var _details_panel: Control = null

func _show_details(item_id: String) -> void:
    if _details_panel == null:
        _details_panel = _create_details_panel()
        _container.add_child(_details_panel)
    _details_panel.populate(item_id)
    _details_panel.visible = true
```

## Common Anti-Patterns

❌ **Deep get_node() Paths**
```gdscript
# Bad
get_node("../../Panel/VBox/ScrollContainer/List/Row5/Button")

# Good: Store references or use signals
_list_container.get_children()[5].get_node("Button")
```

❌ **Hardcoded Sizes**
```gdscript
# Bad
button.size = Vector2(100, 30)

# Good: Let containers handle sizing
button.custom_minimum_size = Vector2(100, 0)  # Min width, auto height
```

❌ **Mixing UI and Logic**
```gdscript
# Bad: UI node modifies game state directly
func _on_buy_pressed() -> void:
    GameContext.player_gold -= price
    GameContext.add_item(item_id)
    _refresh()

# Good: Emit signal, let parent/autoload handle logic
func _on_buy_pressed() -> void:
    purchase_requested.emit(item_id)
```

❌ **Orphaned Connections**
```gdscript
# Bad: Button removed but signal still connected
button.queue_free()  # Signal still fires!

# Good: Disconnect or use one-shot
button.pressed.connect(_handler, CONNECT_ONE_SHOT)
# or
button.pressed.disconnect(_handler)
button.queue_free()
```
