extends Node
## Global signal hub. Systems talk through here so they never need hard references.

# --- Player ---
signal player_spawned(player: Node)
signal player_hp_changed(hp: int, max_hp: int)
signal player_energy_changed(energy: float, max_energy: float)
signal player_special_changed(special: float)
signal player_stats_changed()
signal player_died()
signal player_respawned()

# --- Economy / progression ---
signal money_changed(total: int, delta: int)
signal xp_changed(xp: int, xp_to_next: int)
signal level_up(new_level: int)
signal move_unlocked(move_id: String)
signal item_acquired(item_id: String, count: int)
signal item_used(item_id: String)

# --- Combat ---
signal hit_landed(attacker: Node, target: Node, damage: int, heavy: bool)
signal enemy_spawned(enemy: Node)
signal enemy_defeated(enemy: Node, enemy_id: String)
signal boss_started(boss: Node)
signal boss_hp_changed(hp: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss: Node, boss_id: String)
signal encounter_started(encounter_id: String)
signal encounter_cleared(encounter_id: String)

# --- Feel ---
signal screen_shake(strength: float, duration: float)
signal hit_stop(seconds: float)
signal slow_motion(scale: float, seconds: float)

# --- World ---
signal area_loading(area_id: String)
signal area_entered(area_id: String, area_name: String)
signal door_used(door_id: String)
signal interactable_focused(node: Node)
signal interactable_unfocused(node: Node)
signal flag_set(flag: String, value: Variant)

# --- Dialogue / shops / quests ---
signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
signal dialogue_choice(dialogue_id: String, choice_index: int)
signal shop_opened(shop_id: String)
signal shop_closed(shop_id: String)
signal shop_purchase(shop_id: String, item_id: String, price: int)
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)

# --- Meta ---
signal game_state_changed(new_state: int)
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal notification(text: String, kind: String)
signal touch_mode_changed(enabled: bool)
signal settings_changed()
