#!/usr/bin/env python3
"""
Sidewalk Kings - scene (.tscn) generator.

Godot scenes are plain text. Generating them here keeps node paths, collision layers and
script bindings consistent, and makes it obvious where each scene's structure is defined.

Run from the project root:  python tools/gen_scenes.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", newline="\n") as f:
        f.write(text.strip() + "\n")
    print("  " + path)

# Collision layer bit values (see project.godot layer_names)
L_PLAYER_HURT = 1
L_ENEMY_HURT = 2
L_PLAYER_HIT = 4
L_ENEMY_HIT = 8
L_PICKUP = 16
L_INTERACT = 32
L_SENSOR = 64
L_DOOR = 128
L_WORLD = 1          # solid props
L_PLAYER_BODY = 256
L_ENEMY_BODY = 512

SCENES = {}

# ---------------------------------------------------------------- Player
SCENES["actors/player/Player.tscn"] = f'''
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://actors/player/Player.gd" id="1"]
[ext_resource type="Script" path="res://combat/CombatController.gd" id="2"]
[ext_resource type="Script" path="res://combat/Hitbox.gd" id="3"]
[ext_resource type="Script" path="res://combat/Hurtbox.gd" id="4"]
[ext_resource type="SpriteFrames" path="res://assets/art/characters/kip_frames.tres" id="5"]
[ext_resource type="Texture2D" path="res://assets/art/fx/shadow.png" id="6"]

[sub_resource type="RectangleShape2D" id="HurtShape"]
size = Vector2(13, 12)

[node name="Player" type="CharacterBody2D"]
collision_layer = {L_PLAYER_BODY}
collision_mask = {L_WORLD}
motion_mode = 1
script = ExtResource("1")
max_hp = 100
move_speed = 118.0
run_speed = 190.0
body_radius = 7.0

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("HurtShape")

[node name="Shadow" type="Sprite2D" parent="."]
texture = ExtResource("6")
position = Vector2(0, 1)

[node name="Visual" type="Node2D" parent="."]

[node name="Sprite" type="AnimatedSprite2D" parent="Visual"]
sprite_frames = ExtResource("5")
animation = &"idle"
autoplay = "idle"
position = Vector2(0, -29)
offset = Vector2(0, 0)
centered = true

[node name="GrabPoint" type="Marker2D" parent="Visual"]
position = Vector2(16, -18)

[node name="WeaponSlot" type="Node2D" parent="Visual"]
position = Vector2(9, -22)

[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("actor_path")]
collision_layer = {L_PLAYER_HURT}
collision_mask = 0
monitorable = true
monitoring = false
script = ExtResource("4")
actor_path = NodePath("..")

[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("HurtShape")

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = {L_PLAYER_HIT}
collision_mask = {L_ENEMY_HURT}
monitorable = false
monitoring = false
script = ExtResource("3")

[node name="Combat" type="Node" parent="."]
script = ExtResource("2")
'''

# ---------------------------------------------------------------- Enemy
def enemy_scene(script_path, root_name, extra=""):
    return f'''
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="{script_path}" id="1"]
[ext_resource type="Script" path="res://combat/CombatController.gd" id="2"]
[ext_resource type="Script" path="res://combat/Hitbox.gd" id="3"]
[ext_resource type="Script" path="res://combat/Hurtbox.gd" id="4"]
[ext_resource type="Script" path="res://actors/enemies/HealthBar.gd" id="5"]
[ext_resource type="Texture2D" path="res://assets/art/fx/shadow.png" id="6"]
[ext_resource type="Texture2D" path="res://assets/art/fx/alert.png" id="7"]

[sub_resource type="RectangleShape2D" id="HurtShape"]
size = Vector2(13, 12)

[node name="{root_name}" type="CharacterBody2D"]
collision_layer = {L_ENEMY_BODY}
collision_mask = {L_WORLD}
motion_mode = 1
script = ExtResource("1")
{extra}
[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("HurtShape")

[node name="Shadow" type="Sprite2D" parent="."]
texture = ExtResource("6")
position = Vector2(0, 1)

[node name="Visual" type="Node2D" parent="."]

[node name="Sprite" type="AnimatedSprite2D" parent="Visual"]
position = Vector2(0, -29)
centered = true

[node name="HealthBar" type="Node2D" parent="Visual"]
position = Vector2(0, -58)
script = ExtResource("5")

[node name="Alert" type="Sprite2D" parent="Visual"]
texture = ExtResource("7")
position = Vector2(8, -66)
visible = false

[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("actor_path")]
collision_layer = {L_ENEMY_HURT}
collision_mask = 0
monitorable = true
monitoring = false
script = ExtResource("4")
actor_path = NodePath("..")

[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("HurtShape")

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = {L_ENEMY_HIT}
collision_mask = {L_PLAYER_HURT}
monitorable = false
monitoring = false
script = ExtResource("3")

[node name="Combat" type="Node" parent="."]
script = ExtResource("2")
'''

SCENES["actors/enemies/Enemy.tscn"] = enemy_scene("res://actors/enemies/EnemyBase.gd", "Enemy")
SCENES["actors/bosses/Boss.tscn"] = enemy_scene("res://actors/bosses/Boss.gd", "Boss",
    'boss_id = "big_starch"\nphase2_threshold = 0.5\n')

# The HealthBar node lives under Visual, but EnemyBase reads $HealthBar / $Alert.
# Fix the onready paths by keeping them at the root instead.
for key in ("actors/enemies/Enemy.tscn", "actors/bosses/Boss.tscn"):
    SCENES[key] = (SCENES[key]
        .replace('[node name="HealthBar" type="Node2D" parent="Visual"]', '[node name="HealthBar" type="Node2D" parent="."]')
        .replace('[node name="Alert" type="Sprite2D" parent="Visual"]', '[node name="Alert" type="Sprite2D" parent="."]'))

# ---------------------------------------------------------------- Weapon / projectile
SCENES["weapons/Weapon.tscn"] = '''
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://weapons/WeaponBase.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/fx/shadow.png" id="2"]

[node name="Weapon" type="Node2D"]
script = ExtResource("1")
weapon_id = "bat"

[node name="Shadow" type="Sprite2D" parent="."]
texture = ExtResource("2")
scale = Vector2(0.6, 0.6)
modulate = Color(1, 1, 1, 0.4)

[node name="Sprite" type="Sprite2D" parent="."]
position = Vector2(0, -4)
'''

SCENES["weapons/Projectile.tscn"] = '''
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://weapons/Projectile.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/fx/shadow.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/art/weapons/bottle.png" id="3"]

[node name="Projectile" type="Node2D"]
script = ExtResource("1")

[node name="Shadow" type="Sprite2D" parent="."]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)
modulate = Color(1, 1, 1, 0.35)

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("3")
position = Vector2(0, -26)
'''

# ---------------------------------------------------------------- Pickups
def pickup_scene(script, name, tex):
    return f'''
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="{script}" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/fx/shadow.png" id="2"]
[ext_resource type="Texture2D" path="{tex}" id="3"]

[node name="{name}" type="Node2D"]
script = ExtResource("1")

[node name="Shadow" type="Sprite2D" parent="."]
texture = ExtResource("2")
scale = Vector2(0.55, 0.55)
modulate = Color(1, 1, 1, 0.4)

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("3")
position = Vector2(0, -4)
'''

SCENES["world/props/MoneyPickup.tscn"] = pickup_scene("res://world/props/MoneyPickup.gd", "MoneyPickup", "res://assets/art/ui/items/coin_small.png")
SCENES["world/props/ItemPickup.tscn"] = pickup_scene("res://world/props/ItemPickup.gd", "ItemPickup", "res://assets/art/ui/items/burger.png")

# ---------------------------------------------------------------- Prop
SCENES["world/props/Prop.tscn"] = f'''
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://world/props/Prop.gd" id="1"]
[ext_resource type="Script" path="res://combat/Hurtbox.gd" id="2"]

[sub_resource type="RectangleShape2D" id="PropShape"]
size = Vector2(18, 22)

[node name="Prop" type="Node2D"]
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]

[node name="Body" type="StaticBody2D" parent="."]
collision_layer = 1
collision_mask = 0

[node name="Shape" type="CollisionShape2D" parent="Body"]
shape = SubResource("PropShape")

[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("actor_path")]
collision_layer = {L_ENEMY_HURT}
collision_mask = 0
monitorable = true
monitoring = false
position = Vector2(0, -10)
script = ExtResource("2")
actor_path = NodePath("..")

[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("PropShape")
'''

# ---------------------------------------------------------------- NPC
SCENES["world/NPC.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://world/NPC.gd" id="1"]

[node name="NPC" type="Node2D"]
script = ExtResource("1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)
centered = true

[node name="Prompt" type="Node2D" parent="."]
position = Vector2(0, -60)
visible = false
'''

# ---------------------------------------------------------------- Door
SCENES["world/doors/Door.tscn"] = f'''
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://world/doors/Door.gd" id="1"]

[sub_resource type="RectangleShape2D" id="DoorShape"]
size = Vector2(18, 34)

[node name="Door" type="Node2D"]
script = ExtResource("1")

[node name="Area" type="Area2D" parent="."]
collision_layer = {L_DOOR}
collision_mask = 1
monitoring = true

[node name="Shape" type="CollisionShape2D" parent="Area"]
shape = SubResource("DoorShape")
position = Vector2(0, -12)

[node name="Prompt" type="Node2D" parent="."]
position = Vector2(0, -46)
visible = false
'''

# ---------------------------------------------------------------- Area
SCENES["world/Area.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://world/Area.gd" id="1"]

[node name="Area" type="Node2D"]
script = ExtResource("1")

[node name="Parallax" type="Node2D" parent="."]

[node name="Ground" type="Node2D" parent="."]

[node name="Actors" type="Node2D" parent="."]
y_sort_enabled = true

[node name="Front" type="Node2D" parent="."]
z_index = 30

[node name="Triggers" type="Node2D" parent="."]
'''

# ---------------------------------------------------------------- Touch controls
def touch_button(name, action, tex):
    return f'''
[node name="{name}" type="TextureRect" parent="Buttons"]
texture = ExtResource("{tex}")
expand_mode = 1
stretch_mode = 5
modulate = Color(1, 1, 1, 0.78)
metadata/action = "{action}"
'''

SCENES["ui/mobile/TouchControls.tscn"] = '''
[gd_scene load_steps=11 format=3]

[ext_resource type="Script" path="res://ui/mobile/TouchControls.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/ui/joy_base.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/art/ui/joy_knob.png" id="3"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_light.png" id="4"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_heavy.png" id="5"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_jump.png" id="6"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_grab.png" id="7"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_special.png" id="8"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_pause.png" id="9"]
[ext_resource type="Texture2D" path="res://assets/art/ui/btn_guard.png" id="10"]

[node name="TouchControls" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="Stick" type="Control" parent="."]
mouse_filter = 2

[node name="Base" type="TextureRect" parent="Stick"]
texture = ExtResource("2")
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
modulate = Color(1, 1, 1, 0.7)

[node name="Knob" type="TextureRect" parent="Stick"]
texture = ExtResource("3")
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
modulate = Color(1, 1, 1, 0.85)

[node name="Buttons" type="Control" parent="."]
mouse_filter = 2
''' + "".join([
    touch_button("Light", "attack_light", "4"),
    touch_button("Heavy", "attack_heavy", "5"),
    touch_button("Jump", "jump", "6"),
    touch_button("Grab", "grab", "7"),
    touch_button("Special", "special", "8"),
    touch_button("Guard", "guard", "10"),
    touch_button("Pause", "pause", "9"),
])

# ---------------------------------------------------------------- UI singletons
SCENES["ui/dialogue/DialogueBox.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/dialogue/DialogueBox.gd" id="1"]

[node name="DialogueBox" type="CanvasLayer"]
layer = 40
script = ExtResource("1")
'''

SCENES["ui/shops/ShopController.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/shops/ShopController.gd" id="1"]

[node name="ShopController" type="CanvasLayer"]
layer = 45
script = ExtResource("1")
'''

SCENES["ui/hud/HUD.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/hud/HUD.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
layer = 10
script = ExtResource("1")
'''

SCENES["ui/menus/PauseMenu.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/menus/PauseMenu.gd" id="1"]

[node name="PauseMenu" type="CanvasLayer"]
layer = 50
script = ExtResource("1")
'''

SCENES["ui/menus/DebugPanel.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/menus/DebugPanel.gd" id="1"]

[node name="DebugPanel" type="CanvasLayer"]
layer = 60
script = ExtResource("1")
'''

SCENES["ui/title/TitleScreen.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/title/TitleScreen.gd" id="1"]

[node name="TitleScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
'''

# ---------------------------------------------------------------- Game root
SCENES["scenes/game/Game.tscn"] = '''
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scenes/game/Game.gd" id="1"]
[ext_resource type="Script" path="res://world/GameCamera.gd" id="2"]
[ext_resource type="PackedScene" path="res://ui/hud/HUD.tscn" id="3"]
[ext_resource type="PackedScene" path="res://ui/menus/PauseMenu.tscn" id="4"]
[ext_resource type="PackedScene" path="res://ui/mobile/TouchControls.tscn" id="5"]
[ext_resource type="PackedScene" path="res://ui/menus/DebugPanel.tscn" id="6"]

[node name="Game" type="Node2D"]
script = ExtResource("1")

[node name="World" type="Node2D" parent="."]

[node name="Camera" type="Camera2D" parent="."]
script = ExtResource("2")

[node name="UI" type="CanvasLayer" parent="."]
layer = 5

[node name="HUD" parent="UI" instance=ExtResource("3")]

[node name="PauseMenu" parent="UI" instance=ExtResource("4")]

[node name="DebugPanel" parent="UI" instance=ExtResource("6")]

[node name="TouchControlsHost" type="Control" parent="UI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="TouchControls" parent="UI/TouchControlsHost" instance=ExtResource("5")]
'''

# ---------------------------------------------------------------- Boot
SCENES["scenes/boot/Boot.tscn"] = '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/boot/Boot.gd" id="1"]

[node name="Boot" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
'''

def main():
    print("Writing scenes:")
    for path, text in SCENES.items():
        write(path, text)
    print(f"{len(SCENES)} scenes written.")

if __name__ == "__main__":
    main()
