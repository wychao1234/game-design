extends CanvasLayer

signal action(command: String, payload: Variant)

const GOLD := Color("e7c687")
const INK := Color("101c28")
const WHITE := Color("e5edf0")
const MUTED := Color("93a8b6")
const NAMES := {"shen":"沈砚", "jiang":"江照野", "zhu":"祝听澜", "lu":"陆惊弦"}
const ROLES := {"shen":"契刀 · 印记爆发", "jiang":"长枪 · 聚怪破势", "zhu":"符铃 · 召唤指挥", "lu":"机巧弓 · 远程标记"}
const SLOT_NAMES := {"weapon":"武器", "clothing":"衣装", "bracers":"护腕", "boots":"鞋履", "pendant":"佩饰", "ring":"戒指"}
const AWAKENINGS := {"shen":"同契", "jiang":"百步镇关", "zhu":"百灯引渡", "lu":"天罗落星"}
const MECHANISMS := {"shen_echo":"引印扩散，伤害邻近敌人", "jiang_break":"拖枪后强化下一次震关", "zhu_command":"驱令分配强化协同攻击", "lu_pierce":"裂帛形成贯穿射击"}

var screen: Control
var party_box: HBoxContainer
var party_cards: Array[Dictionary] = []
var title_label: Label
var objective: Label
var wallet: Label
var message_label: Label
var hints: Label
var skill_box: PanelContainer
var skills: Array[Dictionary] = []
var energy: ProgressBar
var dodge_label: Label
var boss_box: VBoxContainer
var boss_label: Label
var boss_health: ProgressBar
var overlay: ColorRect
var modal: PanelContainer
var menu_kind := ""
var catalog: Dictionary = {}
var current_data: Dictionary = {}
var inventory_character := "shen"
var selected_scrap: Array = []
var party_choice: Array = []
var difficulty_choice := 0
var mini: MiniMap
var ui_font: Font
var preview_label: Label

class SkillIcon extends Control:
	static var _atlas_attempted: bool = false
	static var _atlas_texture: Texture2D
	static var _atlas_regions: Array[Rect2] = []
	static func _load_atlas_once() -> void:
		if _atlas_attempted: return
		_atlas_attempted = true
		var image_path: String = "res://assets/ui/skill_icons.png"
		var metadata_path: String = "res://assets/ui/skill_icons.json"
		if not ResourceLoader.exists(image_path) or not FileAccess.file_exists(metadata_path): return
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if not parsed is Dictionary: return
		var frames: Variant = parsed.get("frames",[])
		if not frames is Array or frames.size()!=20: return
		var regions: Array[Rect2] = []
		for index: int in range(20): regions.append(Rect2())
		var seen: Dictionary = {}
		for value: Variant in frames:
			if not value is Dictionary: return
			var row_index: int = int(value.get("row",-1))
			var column_index: int = int(value.get("column",-1))
			var region: Variant = value.get("region",[])
			if row_index<0 or row_index>=4 or column_index<0 or column_index>=5 or not region is Array or region.size()!=4: return
			var index: int = row_index*5+column_index
			if seen.has(index): return
			var rect := Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
			if not rect.has_area(): return
			seen[index] = true
			regions[index] = rect
		var texture: Texture2D = load(image_path) as Texture2D
		if texture==null: return
		var bounds := Rect2(Vector2.ZERO,texture.get_size())
		for rect: Rect2 in regions:
			if not bounds.encloses(rect): return
		_atlas_texture = texture
		_atlas_regions = regions
	var role: String = "shen"
	var slot: int = 0
	var cooling: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Painted skill art is reduced from ~280px to a small HUD tile.
		# Mipmapped filtering keeps its silhouette readable at the displayed size.
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_load_atlas_once()
	func _draw() -> void:
		var center: Vector2 = size*0.5
		var radius: float = minf(size.x,size.y)*0.43
		var cyan := Color("bceeff") if not cooling else Color("506a7c")
		if slot == 4:
			draw_circle(center,radius,Color(0.025,0.075,0.13,0.92))
			draw_arc(center,radius,-PI,PI,64,Color("bca46b"),2,true)
			draw_arc(center,radius-4,-PI,PI,64,Color("577086"),1,true)
			for angle in [0.0,PI*0.5,PI,PI*1.5]:
				var point := center+Vector2.from_angle(angle)*radius
				draw_circle(point,2,Color("e8cf8a"))
		else:
			draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color(0.025,0.065,0.11,0.92))
			draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("9d895e") if not cooling else Color("455765"),false,1)
			draw_rect(Rect2(Vector2(6,6),size-Vector2(12,12)),Color("2b536f"),false,1)
		var row_index: int = ["shen","jiang","zhu","lu"].find(role)
		var atlas_index: int = row_index*5+slot
		if _atlas_texture!=null and row_index>=0 and slot>=0 and slot<5 and atlas_index<_atlas_regions.size():
			var region: Rect2 = _atlas_regions[atlas_index]
			var tint := Color(0.45,0.5,0.57,1.0) if cooling else Color.WHITE
			if slot==4:
				# Circular sampling keeps the painted awakening inside the existing gold ring.
				var points := PackedVector2Array()
				var uvs := PackedVector2Array()
				for index: int in range(48):
					var direction := Vector2.from_angle(TAU*float(index)/48.0)
					points.append(center+direction*(radius-5.0))
					uvs.append((region.get_center()+direction*region.size*0.44)/_atlas_texture.get_size())
				draw_polygon(points,PackedColorArray([tint]),uvs,_atlas_texture)
			else:
				var extent: Vector2 = Vector2.ONE*(minf(size.x,size.y)-10.0)
				draw_texture_rect_region(_atlas_texture,Rect2(center-extent*0.5,extent),region,tint)
			return
		var kind: int = slot if role == "shen" else ({"jiang":[2,0,3,1],"zhu":[1,2,3,0],"lu":[3,0,1,2]}.get(role,[0,1,2,3])[mini(slot,3)])
		if slot==4: kind=4
		var r := radius*0.64
		for pass_index in range(3):
			var width: float = [8.0,4.0,1.6][pass_index]
			var color: Color = Color(cyan,0.08 if pass_index==0 else (0.25 if pass_index==1 else 1.0))
			match kind:
				0:
					draw_arc(center+Vector2(-r*0.1,-r*0.1),r,-0.25,2.65,28,color,width,true)
					draw_line(center+Vector2(-r*0.75,r*0.6),center+Vector2(r*0.7,-r*0.65),color,width,true)
				1:
					var corners := PackedVector2Array([center+Vector2(0,-r),center+Vector2(r*0.5,-r*0.6),center+Vector2(r*0.45,r*0.6),center+Vector2(0,r),center+Vector2(-r*0.45,r*0.6),center+Vector2(-r*0.5,-r*0.6),center+Vector2(0,-r)])
					draw_polyline(corners,color,width,true)
					draw_line(center+Vector2(0,-r*0.6),center+Vector2(0,r*0.55),color,width,true)
				2:
					for line_index in range(3):
						var y: float = float(line_index-1)*r*0.5
						draw_arc(center+Vector2(0,y),r*(1.0-line_index*0.15),0.1,PI*1.85,26,color,width,true)
				3:
					for offset: float in [-0.42,0.42]:
						var x: float = offset*r
						draw_line(center+Vector2(x-r*0.3,r),center+Vector2(x+r*0.3,-r),color,width,true)
						draw_line(center+Vector2(x+r*0.3,-r),center+Vector2(x-r*0.05,-r*0.35),color,width,true)
				4:
					draw_arc(center,r,-2.6,2.1,38,color,width,true)
					draw_arc(center,r*0.55,-0.8,4.0,24,color,width,true)
					draw_line(center+Vector2(0,-r*1.1),center+Vector2(0,r*1.1),color,width,true)
					draw_line(center+Vector2(-r*0.8,r*0.55),center+Vector2(r*0.8,-r*0.55),color,width,true)
		if not cooling:
			for delta in [Vector2(-0.7,-0.6),Vector2(0.65,0.7),Vector2(0.85,-0.25)]:
				draw_circle(center+delta*radius,1.2,Color("d9f8ff"))

class MiniMap extends Control:
	var player := Vector2.ZERO
	var foes: Array[Vector2] = []
	var mode := "town"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_style_box(_background(),Rect2(Vector2.ZERO,size))
		var arena := PackedVector2Array([Vector2(0.1,0.28),Vector2(0.3,0.12),Vector2(0.87,0.17),Vector2(0.93,0.73),Vector2(0.72,0.88),Vector2(0.15,0.78)])
		for index in range(arena.size()): arena[index]*=size
		draw_colored_polygon(arena,Color(0.25,0.3,0.35,0.85))
		arena.append(arena[0])
		draw_polyline(arena,Color("64717b"),1,true)
		if mode == "town":
			for point in [Vector2(-0.6,-0.4),Vector2(0.7,-0.5),Vector2(-0.1,-0.5)]: draw_rect(Rect2(_point(point)-Vector2(3,3),Vector2(6,6)),Color("d6b06f"))
		for point in foes: draw_circle(_point(point),2,Color("e9876b"))
		var current := _point(player)
		draw_colored_polygon(PackedVector2Array([current+Vector2(0,-5),current+Vector2(4,4),current,current+Vector2(-4,4)]),Color("ffd987"))
	func _point(point:Vector2)->Vector2: return size*0.5+Vector2(point.x*size.x*0.43,point.y*size.y*0.4)
	func _background()->StyleBoxFlat:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.015,0.025,0.045,0.7)
		style.border_color=Color("74674f")
		style.set_border_width_all(1)
		return style

func setup(font_value: Font, item_catalog: Dictionary) -> void:
	ui_font = font_value
	catalog = item_catalog
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var ui_theme := Theme.new()
	ui_theme.default_font = ui_font
	screen.theme = ui_theme
	party_box = HBoxContainer.new()
	party_box.position = Vector2(28,16)
	party_box.add_theme_constant_override("separation",16)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(party_box)
	for index in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(82,82)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		party_box.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",2)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(column)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(76,67)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(portrait)
		var hp := _bar(Color("ce5c4e"),76,5)
		column.add_child(hp)
		var name_label := _label("",12)
		name_label.hide()
		column.add_child(name_label)
		var hp_text := _label("",12,MUTED)
		hp_text.hide()
		column.add_child(hp_text)
		var number := _label(str(index+1),12,Color("f3d797"))
		number.position = Vector2(5,3)
		card.add_child(number)
		party_cards.append({"panel":card,"portrait":portrait,"name":name_label,"hp":hp,"text":hp_text,"id":""})
	title_label = _label("临川 · 雨灯行旅",16,GOLD)
	title_label.position = Vector2(28,112)
	screen.add_child(title_label)
	preview_label = _label("代表关卡试玩",11,MUTED)
	preview_label.position = Vector2(29,136)
	screen.add_child(preview_label)
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-220,16)
	right.custom_minimum_size = Vector2(198,140)
	right.add_theme_constant_override("separation",8)
	screen.add_child(right)
	mini = MiniMap.new()
	mini.custom_minimum_size = Vector2(198,114)
	right.add_child(mini)
	objective = _label("",15,Color("e9e3d2"))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size.x = 198
	right.add_child(objective)
	wallet = _label("",12,MUTED)
	right.add_child(wallet)
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-210,24)
	boss_box.custom_minimum_size = Vector2(420,38)
	screen.add_child(boss_box)
	boss_label = _label("缚潮舟主",16,GOLD)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_label)
	boss_health = _bar(Color("b35e4c"),420,7)
	boss_box.add_child(boss_health)
	skill_box = PanelContainer.new()
	skill_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_box.position = Vector2(-225,-154)
	skill_box.custom_minimum_size = Vector2(450,116)
	skill_box.add_theme_stylebox_override("panel",_style(Color(0.025,0.045,0.07,0.06),Color(0,0,0,0),0))
	skill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(skill_box)
	var skill_column := VBoxContainer.new()
	skill_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_box.add_child(skill_column)
	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation",10)
	skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_column.add_child(skill_row)
	for index in range(5):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(66,90) if index<4 else Vector2(86,90)
		card.size_flags_vertical = Control.SIZE_SHRINK_END
		card.add_theme_stylebox_override("panel",_style(Color(0,0,0,0),Color(0,0,0,0),0))
		skill_row.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(column)
		var icon := SkillIcon.new()
		icon.custom_minimum_size = Vector2(66,62) if index<4 else Vector2(86,78)
		icon.slot = index
		column.add_child(icon)
		var name_label := _label("",10,WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var key := _label(["Q","E","R","F","X"][index],16,Color("f5e4b9"))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(key)
		skills.append({"panel":card,"name":name_label,"key":key,"icon":icon})
	var resource := HBoxContainer.new()
	resource.alignment = BoxContainer.ALIGNMENT_CENTER
	resource.add_theme_constant_override("separation",16)
	resource.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_column.add_child(resource)
	energy = _bar(Color("d7ac56"),240,7)
	energy.tooltip_text = "队伍共享觉醒能量"
	resource.add_child(energy)
	dodge_label = _label("◇  ◇",15,Color("8ddce8"))
	resource.add_child(dodge_label)
	message_label = _label("",15,GOLD)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.position = Vector2(-420,-196)
	message_label.custom_minimum_size = Vector2(840,24)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(message_label)
	hints = _label("",11,Color(0.68,0.75,0.8,0.7))
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(25,-24)
	screen.add_child(hints)
	overlay=ColorRect.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.color=Color(0.015,0.03,0.05,0.83);screen.add_child(overlay)
	modal=PanelContainer.new();modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER);modal.position=Vector2(-475,-335);modal.custom_minimum_size=Vector2(950,670);modal.add_theme_stylebox_override("panel",_style(INK,Color("a58b57"),26));overlay.add_child(modal);overlay.hide()

func update_state(data:Dictionary,snapshot:Dictionary,area:String,notice_text:String,interaction:String) -> void:
	current_data=data
	var party:Array=data.get("party",[])
	for i in range(3):
		var card:Dictionary=party_cards[i]
		if i>=party.size(): card.panel.hide();continue
		card.panel.show()
		var id:String=party[i]
		if card.id!=id:
			card.id=id;card.portrait.texture=_portrait(id)
		var active:bool=area=="town" and i==0 or (area!="town" and int(snapshot.get("active_slot",0))==i)
		card.panel.add_theme_stylebox_override("panel",_style(Color(0.035,0.06,0.085,0.9),GOLD if active else Color("4a5962"),3))
		var hp:float=float(snapshot.get("hp",{}).get(id,100.0))
		var maximum:float=float(snapshot.get("max_hp",{}).get(id,100.0))
		card.name.text="%d  %s"%[i+1,NAMES[id]];card.name.modulate=Color.WHITE if hp>0 else MUTED
		card.hp.max_value=maximum;card.hp.value=hp
		card.text.text="Lv.%d   %d / %d"%[int(data.characters[id].level),maxi(0,int(hp)),int(maximum)]
		card.panel.tooltip_text=card.name.text+"\n"+card.text.text
	wallet.text="铜钱 %d   灵尘 %d   印记 %d"%[int(data.coins),int(data.dust),int(data.seals)]
	message_label.text=notice_text
	wallet.visible=area=="town"
	title_label.visible=area=="town"
	preview_label.visible=area=="town"
	title_label.text={"town":"临川镇 · 雨夜归舟","ferry":"雨灯渡口 · 清理封锁","boss":"回潮石埠 · 缚潮舟主"}.get(area,area)
	skill_box.visible=area!="town"
	boss_box.visible=area=="boss" and not bool(snapshot.get("finished",false))
	if boss_box.visible:
		boss_label.text="缚潮舟主 · 第%d阶段"%int(snapshot.get("boss_phase",1))
		boss_health.value=float(snapshot.get("boss_hp_ratio",1.0))*100.0
	if area=="town":
		objective.text="整备后前往渡口\n"+interaction
		hints.text="WASD 移动   T 交互   M 选关   I 装备   P 编队   Esc 暂停"
	else:
		objective.text=("◇ 清理封锁 · %d / 3"%int(snapshot.get("wave",1))) if area=="ferry" else "◇ 击败缚潮舟主"
		if bool(snapshot.get("finished",false)): objective.text="战斗结束 · T 返回城镇"
		hints.text="WASD 移动   左键 普攻   空格 闪避   1 / 2 / 3 换人   I 查看装备"
		var names:Array=snapshot.get("skill_names",["回锋斩","掠影步","灵火签","引印"])
		var id:String=snapshot.get("active_id","shen")
		var cds:Array=snapshot.get("cooldowns",{}).get(id,[0,0,0,0])
		for i in range(4):
			var cooling:bool=float(cds[i])>0.05
			skills[i].name.text=("%.1fs"%float(cds[i])) if cooling else str(names[i])
			skills[i].icon.role=id
			skills[i].icon.cooling=cooling
			skills[i].icon.queue_redraw()
			skills[i].panel.tooltip_text=str(names[i])+"  ["+["Q","E","R","F"][i]+"]"
		energy.value=float(snapshot.get("awakening_energy",0.0))
		skills[4].name.text=str(AWAKENINGS.get(id,"觉醒"))+(" · 就绪" if energy.value>=100 else "")
		skills[4].icon.role=id
		skills[4].icon.cooling=energy.value<100
		skills[4].icon.queue_redraw()
		skills[4].panel.tooltip_text=str(AWAKENINGS.get(id,"觉醒"))+" · 共享能量 %d/100"%int(energy.value)
		var charges:int=int(snapshot.get("dodge_charges",2))
		dodge_label.text=("◆" if charges>=1 else "◇")+"  "+("◆" if charges>=2 else "◇")
		if charges<2: dodge_label.text+="  %.1fs"%float(snapshot.get("dodge_recharge",0.0))

func update_map(position:Vector3,enemy_nodes:Array,area:String)->void:
	mini.mode=area;mini.player=Vector2(position.x/12.0,position.z/8.0);mini.foes.clear()
	for e:Dictionary in enemy_nodes:
		if float(e.get("hp",0))<=0 or not is_instance_valid(e.get("node")):continue
		var p:Vector3=e.node.position;mini.foes.append(Vector2(p.x/12.0,p.z/8.0))
	mini.queue_redraw()

func is_open()->bool: return overlay.visible

func close_menu()->void:
	overlay.hide();menu_kind="";selected_scrap.clear()

func _base(title:String,subtitle:String="")->VBoxContainer:
	for child in modal.get_children(): modal.remove_child(child);child.queue_free()
	overlay.show()
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",13);modal.add_child(col)
	var top:=HBoxContainer.new();col.add_child(top)
	var heading:=_label(title,28,GOLD);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(heading)
	top.add_child(_button("关闭  Esc",func():action.emit("close",null)))
	if not subtitle.is_empty():
		var text:=_label(subtitle,15,MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(text)
	return col

func show_map(data:Dictionary)->void:
	menu_kind="map";current_data=data
	var col:=_base("临川水乡 · 选择地下城","代表关卡试玩：四名角色开放培养。关卡进度与后续完整主线分开。")
	var regions:=HBoxContainer.new();col.add_child(regions)
	for text in ["临川水乡 · 已开放","栖霞山门","朔风边城","烟罗妖市","天隙封关"]:
		regions.add_child(_label(text,14,GOLD if text.begins_with("临川") else MUTED))
	var diff:=HBoxContainer.new();col.add_child(diff);diff.add_child(_label("难度",17))
	var choice:=OptionButton.new();choice.add_item("普通 · 识招与成长");choice.add_item("困难 · 更密集的组合压力");choice.select(difficulty_choice);choice.item_selected.connect(func(i:int):difficulty_choice=i);diff.add_child(choice)
	for stage in ["ferry","boss"]:
		var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_style(Color("172b37"),Color("596450"),18));col.add_child(panel)
		var row:=HBoxContainer.new();panel.add_child(row)
		var text:=VBoxContainer.new();text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		text.add_child(_label("雨灯渡口" if stage=="ferry" else "缚潮舟主",25,GOLD))
		text.add_child(_label("三段栈桥清场 · 近远混编 · 守口精英" if stage=="ferry" else "独立首领挑战 · 船钩、锁链与潮水",16))
		text.add_child(_label("每次完成获得10印记 · 首通额外机制装备",14,MUTED))
		row.add_child(_button("进入关卡  →",func():action.emit("start",{"stage":stage,"difficulty":difficulty_choice})))
	var target_row:=HBoxContainer.new();col.add_child(target_row);target_row.add_child(_label("本趟追求",16,GOLD))
	var target:=OptionButton.new();target.add_item("暂不指定");target.set_item_metadata(0,"")
	for id:String in catalog:
		if int(catalog[id].cost)<=0:continue
		target.add_item(catalog[id].name);var i:=target.item_count-1;target.set_item_metadata(i,id)
		if data.get("target_item","")==id:target.select(i)
	target.item_selected.connect(func(i:int):action.emit("target",target.get_item_metadata(i)));target_row.add_child(target)
	col.add_child(_label("目标掉落每趟独立判定；印记可兑换指定装备。随机没出也有确定进度。",14,MUTED))
	col.add_child(_button("调整出战编队",func():action.emit("open_party",null)))

func show_party(data:Dictionary)->void:
	menu_kind="party";current_data=data;party_choice=data.party.duplicate()
	var col:=_base("同行者 · 三人编队","选择三人出战，战斗时只有当前控制者在场。后台角色继续获得大部分经验。")
	for id:String in NAMES:
		var row:=HBoxContainer.new();col.add_child(row)
		var box:=CheckBox.new();box.text="%s  ·  Lv.%d"%[NAMES[id],int(data.characters[id].level)];box.button_pressed=party_choice.has(id);box.custom_minimum_size=Vector2(250,64);row.add_child(box)
		row.add_child(_label(ROLES[id],18,MUTED))
		box.toggled.connect(func(on:bool):
			if on:
				if party_choice.size()>=3:box.set_pressed_no_signal(false);return
				party_choice.append(id)
			else:party_choice.erase(id))
	col.add_child(_button("保存三人编队",func():action.emit("party",party_choice.duplicate())))

func show_inventory(data:Dictionary,read_only:bool=false)->void:
	menu_kind="inventory";current_data=data;selected_scrap.clear()
	var col:=_base("行囊与装备","关卡中仅可查看；回到城镇后更换装备、兑换与拆解。" if read_only else "选择角色查看六个装备部位。锁定与已装备物品不会进入拆解清单。")
	var top:=HBoxContainer.new();col.add_child(top)
	var actor:=OptionButton.new()
	for id:String in NAMES:
		actor.add_item(NAMES[id]);actor.set_item_metadata(actor.item_count-1,id)
		if id==inventory_character:actor.select(actor.item_count-1)
	actor.item_selected.connect(func(i:int):inventory_character=actor.get_item_metadata(i);show_inventory(current_data,read_only));top.add_child(actor)
	var cash:=_label("铜钱 %d    灵尘 %d    秘境印记 %d"%[data.coins,data.dust,data.seals],16,GOLD);cash.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(cash)
	if not read_only:top.add_child(_button("印记兑换",func():action.emit("open_shop",null)))
	var slots:=HBoxContainer.new();col.add_child(slots)
	for slot:String in SLOT_NAMES:
		var item:Dictionary=_instance(data,data.equipped[inventory_character][slot]);var name:String="—" if item.is_empty() else str(catalog[item.template_id].name)
		var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",_style(Color("162833"),Color("53616b"),7));slots.add_child(panel)
		panel.add_child(_label(SLOT_NAMES[slot]+"\n"+name,13,MUTED))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,355);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for item:Dictionary in data.inventory:
		var template:Dictionary=catalog.get(item.template_id,{})
		if template.is_empty():continue
		var row:=HBoxContainer.new();row.custom_minimum_size.y=52;list.add_child(row)
		var equipped:String=_owner(data,item.id)
		if not read_only:
			var check:=CheckBox.new();check.disabled=not equipped.is_empty() or bool(item.locked) or bool(item.get("protected",false));row.add_child(check)
			check.toggled.connect(func(on:bool):
				if on:selected_scrap.append(item.id)
				else:selected_scrap.erase(item.id))
		var text:=VBoxContainer.new();text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		text.add_child(_label(template.name+("  [已装备·%s]"%NAMES[equipped] if not equipped.is_empty() else "")+("  锁定" if item.locked else ""),17,_rarity(template.rarity)))
		var desc:String=MECHANISMS.get(str(template.get("mechanism","")),"攻击 +%d · 防御 +%d"%[int(template.attack),int(template.defense)])
		text.add_child(_label(desc,13,MUTED))
		if not read_only:
			var can_equip:bool=(str(template.character).is_empty() or template.character==inventory_character) and (equipped.is_empty() or equipped==inventory_character)
			var equip:=_button("装备",func():action.emit("equip",{"id":item.id,"character":inventory_character}));equip.disabled=not can_equip;row.add_child(equip)
			row.add_child(_button("解锁" if item.locked else "锁定",func():action.emit("lock",item.id)))
	if not read_only:col.add_child(_button("预览拆解所选物品",func():action.emit("preview_scrap",selected_scrap.duplicate())))

func show_shop(data:Dictionary)->void:
	menu_kind="shop";current_data=data
	var col:=_base("守渡器物 · 印记兑换","首通后开放指定兑换。机制武器100、套装部件80、饰品60；不使用随机箱。")
	col.add_child(_label("现有秘境印记：%d"%int(data.seals),20,GOLD))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=440;col.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for id:String in catalog:
		var item:Dictionary=catalog[id];var cost:int=int(item.cost)
		if cost<=0:continue
		var row:=HBoxContainer.new();row.custom_minimum_size.y=47;list.add_child(row)
		var label:=_label(item.name+"  ·  "+("套装" if not str(item.set_id).is_empty() else (MECHANISMS.get(str(item.mechanism),"独立饰品"))),16,_rarity(item.rarity));label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var unlocked:bool=data.unlocked_items.has(id)
		var button:=_button("%d 印记"%cost if unlocked else "首通后开放",func():action.emit("buy",id));button.disabled=not unlocked or int(data.seals)<cost;row.add_child(button)
	col.add_child(_button("返回行囊",func():action.emit("open_inventory",null)))

func show_scrap(preview:Dictionary)->void:
	menu_kind="scrap"
	var col:=_base("确认拆解","已装备、锁定及受保护物品自动排除。确认后物品转为灵尘。")
	col.add_child(_label("可拆解 %d 件\n获得灵尘 %d\n已排除 %d 件"%[int(preview.count),int(preview.dust),preview.blocked.size()],23,GOLD))
	var confirm:=_button("确认拆解",func():action.emit("scrap",preview.ids));confirm.disabled=int(preview.count)==0;col.add_child(confirm)
	col.add_child(_button("取消并返回",func():action.emit("open_inventory",null)))

func show_results(reward:Dictionary,success:bool,stage:String)->void:
	menu_kind="results"
	var col:=_base("渡口已通" if success else "暂退城镇，整备再来","获得的装备、经验与材料全部保留。")
	if success:
		col.add_child(_label("秘境印记 +%d    铜钱 +%d    经验 +%d"%[int(reward.get("seals",0)),int(reward.get("coins",0)),int(reward.get("xp",0))],22,GOLD))
		if bool(reward.get("first_clear",false)):col.add_child(_label("首次完成 · 额外器物已收入行囊",18,Color("8cd9e2")))
		for instance:Dictionary in reward.get("items",[]):
			var item:Dictionary=catalog.get(instance.template_id,{})
			if not item.is_empty():col.add_child(_label("获得  "+item.name,21,_rarity(item.rarity)))
	else:col.add_child(_label("已获得的成长不会因本次失败而丢失。\n回城可换装、调整编队，再次挑战。",21,WHITE))
	col.add_child(_button("回城整备",func():action.emit("town",null)))
	col.add_child(_button("再次挑战",func():action.emit("retry",stage)))

func show_pause()->void:
	menu_kind="pause"
	var col:=_base("歇一会儿","单人暂停中。")
	col.add_child(_button("继续旅途",func():action.emit("close",null)))
	col.add_child(_button("返回城镇",func():action.emit("town",null)))
	col.add_child(_button("保存并退出",func():action.emit("quit",null)))

func show_note()->void:
	menu_kind="note"
	var col:=_base("临川渡口 · 行旅告示")
	col.add_child(_label("雨夜封渡，纸傀拦船。\n\n先清理栈桥与船舱，再去回潮石埠挑战缚潮舟主。\n\n找到的器物与印记可带回镇上整备。\n\n沈砚：「好消息，还活着。坏消息，今晚看样子睡不成了。」",21,WHITE))
	col.add_child(_button("前往选关",func():action.emit("open_map",null)))

func _portrait(id:String)->Texture2D:
	var path:String="res://assets/characters/"+id+".png"
	var metadata_path:String="res://assets/characters/"+id+".json"
	if not ResourceLoader.exists(path):path="res://assets/hero_sheet.png"
	if not ResourceLoader.exists(path):return null
	var source:Texture2D=load(path) as Texture2D
	var atlas:=AtlasTexture.new()
	atlas.atlas=source
	atlas.region=Rect2(0,0,source.get_width()/4.0,source.get_height()/4.0)
	if FileAccess.file_exists(metadata_path):
		var metadata:Variant=JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if metadata is Dictionary and not metadata.get("frames",[]).is_empty():
			var frame:Dictionary=metadata.frames[0]
			var region:Array=frame.region
			var bounds:Array=frame.bbox
			# Bbox is relative to its segmented cell, not to the sheet origin.
			var crop_size:float=minf(float(bounds[2]),float(bounds[3])*0.39)
			var center_x:float=float(frame.get("foot_x",float(bounds[0])+float(bounds[2])*0.5))
			var crop_x:float=clampf(center_x-crop_size*0.5,float(bounds[0]),float(bounds[0])+float(bounds[2])-crop_size)
			var head_offset:float=float(bounds[3])*({"jiang":0.13,"lu":0.04}.get(id,0.0))
			atlas.region=Rect2(float(region[0])+crop_x,float(region[1])+float(bounds[1])+head_offset,crop_size,crop_size)
	return atlas

func _instance(data:Dictionary,id:String)->Dictionary:
	for item:Dictionary in data.inventory:
		if item.id==id:return item
	return {}

func _owner(data:Dictionary,id:String)->String:
	for actor:String in data.equipped:
		for slot:String in data.equipped[actor]:
			if data.equipped[actor][slot]==id:return actor
	return ""

func _rarity(value:String)->Color: return Color("82cce5") if value=="稀有" else (Color("a8d5b4") if value=="精良" else WHITE)

func _label(text:String,size_value:int=18,color:Color=WHITE)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func _bar(color:Color,width:float,height:float)->ProgressBar:
	var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(width,height);bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",_style(Color("0b131c"),Color("3d4a53"),0));bar.add_theme_stylebox_override("fill",_style(color,color,0));return bar

func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=38;button.add_theme_font_size_override("font_size",16);button.add_theme_color_override("font_color",WHITE)
	button.add_theme_stylebox_override("normal",_style(Color("20343f"),Color("6e735c"),9));button.add_theme_stylebox_override("hover",_style(Color("304b54"),GOLD,9));button.add_theme_stylebox_override("pressed",_style(Color("142831"),GOLD,9));button.add_theme_stylebox_override("disabled",_style(Color("17242d"),Color("37434c"),9));button.pressed.connect(callback);return button

func _style(bg:Color,border:Color,padding:int)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(3);s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=padding;s.content_margin_bottom=padding;return s
