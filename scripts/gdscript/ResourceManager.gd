extends Node
# ResourceManager - Manages game resources across planets and civilizations
# Handles mining, trading, production, and resource distribution

class_name ResourceManager

# Resource types
enum ResourceType {
	METALS,
	CRYSTALS,
	ENERGY,
	ORGANICS,
	EXOTICS,
	DATA,
	CULTURE
}

# Global resource pools
var global_resources = {}
var planet_resources = {}  # Per-planet storage
var civ_resources = {}     # Per-civilization storage

# Production rates
var production_multipliers = {
	ResourceType.METALS: 1.0,
	ResourceType.CRYSTALS: 0.8,
	ResourceType.ENERGY: 1.2,
	ResourceType.ORGANICS: 1.5,
	ResourceType.EXOTICS: 0.3,
	ResourceType.DATA: 2.0,
	ResourceType.CULTURE: 0.5
}

# Trading system
var trade_routes = []
var market_prices = {}

func _ready():
	print("[ResourceManager] Initializing...")
	_initialize_global_resources()
	_calculate_market_prices()

func _initialize_global_resources():
	for type in ResourceType.values():
		global_resources[type] = 0.0
		market_prices[type] = 100.0  # Base price

func add_planet_resources(planet_id: String, resources: Dictionary):
	if not planet_resources.has(planet_id):
		planet_resources[planet_id] = {}
		
	for type in resources:
		if not planet_resources[planet_id].has(type):
			planet_resources[planet_id][type] = 0.0
		planet_resources[planet_id][type] += resources[type]
		global_resources[type] += resources[type]

func mine_resource(planet_id: String, type: int, amount: float) -> float:
	"""Mine resources from a planet"""
	if not planet_resources.has(planet_id):
		return 0.0
		
	if not planet_resources[planet_id].has(type):
		return 0.0
		
	var available = planet_resources[planet_id][type]
	var mined = min(amount, available)
	
	planet_resources[planet_id][type] -= mined
	global_resources[type] += mined
	
	print("[ResourceManager] Mined ", mined, " ", ResourceType.keys()[type], " from planet ", planet_id)
	return mined

func transfer_resources(from_civ: String, to_civ: String, type: int, amount: float) -> bool:
	"""Transfer resources between civilizations"""
	if not civ_resources.has(from_civ):
		return false
		
	if not civ_resources[from_civ].has(type):
		return false
		
	if civ_resources[from_civ][type] < amount:
		return false
		
	if not civ_resources.has(to_civ):
		civ_resources[to_civ] = {}
		
	if not civ_resources[to_civ].has(type):
		civ_resources[to_civ][type] = 0.0
		
	civ_resources[from_civ][type] -= amount
	civ_resources[to_civ][type] += amount
	
	print("[ResourceManager] Transferred ", amount, " ", ResourceType.keys()[type], " from ", from_civ, " to ", to_civ)
	return true

func _calculate_market_prices():
	"""Dynamic pricing based on supply/demand"""
	for type in ResourceType.values():
		var supply = global_resources.get(type, 0.0)
		var base_price = 100.0
		
		# Price decreases with high supply
		if supply > 10000:
			market_prices[type] = base_price * 0.5
		elif supply > 5000:
			market_prices[type] = base_price * 0.75
		elif supply < 1000:
			market_prices[type] = base_price * 1.5
		elif supply < 500:
			market_prices[type] = base_price * 2.0
		else:
			market_prices[type] = base_price

func get_resource_value(type: int, amount: float) -> float:
	return market_prices.get(type, 100.0) * amount

func create_trade_route(from_planet: String, to_planet: String, resource_type: int):
	var route = {
		"from": from_planet,
		"to": to_planet,
		"resource": resource_type,
		"active": true,
		"efficiency": 1.0
	}
	trade_routes.append(route)
	print("[ResourceManager] Created trade route: ", from_planet, " -> ", to_planet)

func process_trade_routes(delta: float):
	for route in trade_routes:
		if not route["active"]:
			continue
			
		var transfer_amount = 10.0 * delta * route["efficiency"]
		var from_planet = route["from"]
		var to_planet = route["to"]
		var res_type = route["resource"]
		
		if planet_resources.has(from_planet) and planet_resources[from_planet].has(res_type):
			if planet_resources[from_planet][res_type] >= transfer_amount:
				planet_resources[from_planet][res_type] -= transfer_amount
				
				if not planet_resources.has(to_planet):
					planet_resources[to_planet] = {}
				if not planet_resources[to_planet].has(res_type):
					planet_resources[to_planet][res_type] = 0.0
					
				planet_resources[to_planet][res_type] += transfer_amount * route["efficiency"]
