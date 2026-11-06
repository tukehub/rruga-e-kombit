"""Geographic definitions of the six cities: origin, terrain window, track waypoints (lat, lon) on real
streets, and landmark anchors. Waypoints are routed over the OSM street graph by build_city.py, so
they only need to sit near the intended streets."""

CITIES = {
    'tirane': {
        'name': 'Tiranë',
        'origin': (41.3275, 19.8187),          # Skanderbeg Square
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 10.0,
        'exclude_pedestrian': True,
        # Three roadside trees obscure the Pyramid on the race approach.  The
        # coordinates are local metres relative to the Tirana origin.
        'tree_view_exclusions': [(293.2, 460.9, 1.0), (284.1, 442.0, 1.0), (287.1, 448.7, 1.0)],
        'waypoints': [
            (41.3282614, 19.8220752),  # Xhorxh W. Bush, east of Skanderbeg Square
            (41.3261165, 19.8249079),  # Namazgja Mosque approach
            (41.3245919, 19.8244470),  # Unaza by Downtown One
            (41.3239702, 19.8222220),  # Unaza along the Pyramid
            (41.3235618, 19.8196571),  # turn south onto Dëshmorët e Kombit
            (41.3211905, 19.8204364),  # Prime Minister's Office
            (41.3198310, 19.8233801),  # Papa Gjon Pali II by Air Albania
            (41.3173730, 19.8214600),  # Polytechnic / Nënë Tereza Square
            (41.3208399, 19.8182188),  # Ismail Qemali, Blloku
            (41.3236665, 19.8174473),  # Ibrahim Rugova, northbound
            (41.3268261, 19.8165549),  # Orthodox Cathedral
            (41.3282080, 19.8161849),  # Eyes of Tirana
        ],
        'landmarks': [
            {'id': 'skanderbeg', 'll': (41.32775, 19.81850), 'yaw': 180},
            # OSM building outlines for the museum and government offices;
            # dedicated geometry replaces their generic extrusions.
            {'id': 'national_museum', 'll': (41.329418, 19.817101), 'yaw': 12,
             'clear_half': (51, 41)},
            {'id': 'prime_minister', 'll': (41.321756, 19.821067), 'yaw': -78,
             'clear_half': (42, 43)},
            {'id': 'pyramid', 'll': (41.323058, 19.821443), 'yaw': 0,
             'offset_x': 29, 'offset_z': -9, 'clear_half': (29, 29)},
            {'id': 'downtown_one', 'll': (41.324082, 19.823911), 'yaw': 0, 'offset_x': 5, 'offset_z': 12},
            # 85 m Plaza/TID tower; move the race-game representation ten
            # metres north to keep its full footprint clear of the circuit.
            {'id': 'plaza_tower', 'll': (41.327574, 19.821557), 'yaw': 0,
             'offset_z': -10, 'clear_half': (17, 18)},
            {'id': 'namazgja', 'll': (41.3258077, 19.8241644), 'yaw': 0,
             'clear_half': (26, 26)},
            # Roadside offsets are deliberate racing-game adaptations.
            # Keep full footprints outside the road and camera corridor.
            {'id': 'eyes_tirana', 'll': (41.328561, 19.815744), 'yaw': 0,
             'offset_x': -19.1, 'offset_z': 6.4, 'clear_half': (21, 19)},
            {'id': 'bank_albania', 'll': (41.327758, 19.816685), 'yaw': 0,
             'offset_x': 8, 'offset_z': 2.8, 'clear_half': (19, 16)},
            {'id': 'international_hotel', 'll': (41.329863, 19.818686), 'yaw': 0,
             'offset_x': -70, 'offset_z': -10, 'clear_half': (28, 16)},
            {'id': 'polytechnic', 'll': (41.3166196, 19.8217354), 'yaw': 0,
             'offset_x': -20.7, 'offset_z': -45.1, 'clear_half': (44, 12)},
            # Approximate, unbranded rendering of the national stadium at its
            # OSM position; the dedicated 112 m tower is part of the model.
            {'id': 'air_albania', 'll': (41.3184, 19.8239), 'yaw': 12.5,
             'clear_half': (91, 112)},
            {'id': 'cathedral', 'll': (41.326518, 19.81753), 'yaw': 0,
             'offset_x': -25, 'offset_z': -7, 'clear_half': (25, 17)},
            # The full 85 x 55 m model crossed the circuit. Shift it slightly
            # toward its block so its entire footprint clears the road/camera.
            {'id': 'toptani', 'll': (41.327064, 19.822743), 'yaw': 0,
             'offset_x': -10, 'offset_z': 16, 'clear_half': (42.7, 27.8)},
            {'id': 'clocktower', 'll': (41.32800, 19.82000), 'yaw': 0},
            {'id': 'mosque', 'll': (41.32790, 19.81950), 'yaw': 0},
            {'id': 'blloku_sign', 'll': (41.32070, 19.81600), 'yaw': 90},
        ],
        # Replace these specific OSM footprints with the original landmarks,
        # instead of drawing a generic extruded building through each model.
        'landmark_buildings': [174510408, 1255594721, 885643060, 236566880, 236566876, 177186612, 7753718, 410277121, 410277109, 410277110, 10311002, 795642504, 469424840, 461375120, 6785985, 21804933],
        'style': 'tirana',
    },
    'vlore': {
        'name': 'Vlorë',
        'origin': (40.4565, 19.4890),          # Flag Square (Independence Monument)
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 10.0,
        'waypoints': [
            (40.4572235, 19.4891185),  # Flag Square north
            (40.4546913, 19.4867492),  # west side of the centre
            (40.4513451, 19.4888815),  # southern street junction
            (40.4566135, 19.4922383),  # eastern junction, back to Flag Square
        ],
        'landmarks': [
            {'id': 'independence', 'll': (40.45640, 19.48900), 'yaw': 0},
            {'id': 'flagpole_big', 'll': (40.45700, 19.48860), 'yaw': 0},
            {'id': 'mosque', 'll': (40.45820, 19.49120), 'yaw': 0},
        ],
        'sea': True,
        'style': 'seaside',
    },
    'berat': {
        'name': 'Berat',
        'origin': (40.7055, 19.9520),          # centre, below the castle
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 9.0,
        'waypoints': [
            (40.7050, 19.9522),   # centre
            (40.7035, 19.9600),   # Gorica side, west
            (40.7038, 19.9510),   # Gorica bridge area
            (40.7046, 19.9478),   # under Mangalem
        ],
        'landmarks': [
            {'id': 'castle_berat', 'll': (40.71000, 19.94300), 'yaw': 0},
            {'id': 'mangalem', 'll': (40.70650, 19.94600), 'yaw': 0},
            {'id': 'gorica', 'll': (40.70330, 19.94700), 'yaw': 180},
            {'id': 'bridge_gorica', 'll': (40.70400, 19.95000), 'yaw': 0},
            {'id': 'mosque', 'll': (40.70560, 19.95080), 'yaw': 0},
        ],
        'style': 'old',
    },
    'gjirokaster': {
        'name': 'Gjirokastër',
        'origin': (40.0760, 20.1395),          # old bazaar below the castle
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 9.0,
        'waypoints': [
            (40.0790, 20.1418),   # Bulevardi 18 Shtatori
            (40.0826, 20.1445),
            (40.0836, 20.1398),
            (40.0803, 20.1370),
            (40.0770, 20.1380),   # climb towards the bazaar
        ],
        'landmarks': [
            {'id': 'castle_gjirokaster', 'll': (40.07350, 20.13950), 'yaw': 0},
            {'id': 'stone_roofs', 'll': (40.07620, 20.13880), 'yaw': 0},
            {'id': 'mosque', 'll': (40.07580, 20.13990), 'yaw': 0},
        ],
        'style': 'stone',
    },
    'shkoder': {
        'name': 'Shkodër',
        'origin': (42.0600, 19.5060),          # south of the centre, towards Rozafa
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 10.0,
        'waypoints': [
            (42.0665, 19.5125),   # Sheshi Demokracia
            (42.0640, 19.5160),
            (42.0548, 19.5048),   # towards the castle road
            (42.0570, 19.4985),
            (42.0652, 19.5068),
        ],
        'landmarks': [
            {'id': 'rozafa', 'll': (42.04650, 19.49350), 'yaw': 0},
            {'id': 'mosque_lead', 'll': (42.06530, 19.51180), 'yaw': 0},
            {'id': 'flagpole', 'll': (42.06700, 19.51300), 'yaw': 0},
        ],
        'lake': True,
        'style': 'old',
    },
    'tetove': {
        'name': 'Tetovë',
        'origin': (42.0100, 20.9710),          # centre, by the Painted Mosque
        'near_km': 4.5, 'far_km': 24.0,
        'half_width': 10.0,
        'waypoints': [
            (42.0092789, 20.9708636),
            (42.0083544, 20.9773683),
            (42.0121508, 20.9791749),
            (42.0152582, 20.9730666),
            (42.0103832, 20.9640644),
            (42.0073634, 20.9668280),
        ],
        'landmarks': [
            {'id': 'painted_mosque', 'll': (42.00850, 20.97050), 'yaw': 0},
            {'id': 'mosque', 'll': (42.01200, 20.97500), 'yaw': 0},
            {'id': 'flagpole', 'll': (42.01000, 20.97120), 'yaw': 0},
        ],
        'style': 'old',
    },
}

ROUTABLE = {
    'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified', 'residential',
    'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link',
    'living_street', 'service', 'pedestrian', 'road',
}
# cost multiplier when routing: prefer big streets
ROUTE_COST = {
    'motorway': 1.0, 'trunk': 1.0, 'primary': 1.0, 'secondary': 1.05, 'tertiary': 1.15,
    'unclassified': 1.4, 'residential': 2.2, 'living_street': 2.6, 'service': 4.0, 'pedestrian': 2.0, 'road': 2.0,
    'motorway_link': 1.2, 'trunk_link': 1.2, 'primary_link': 1.2, 'secondary_link': 1.3, 'tertiary_link': 1.4,
}
ROAD_WIDTH = {
    'motorway': 14, 'trunk': 12, 'primary': 11, 'secondary': 9, 'tertiary': 8, 'unclassified': 6, 'residential': 6,
    'living_street': 5, 'service': 4, 'pedestrian': 6, 'road': 6, 'motorway_link': 7, 'trunk_link': 7,
    'primary_link': 7, 'secondary_link': 6, 'tertiary_link': 6, 'footway': 2, 'path': 1.5, 'cycleway': 2.5, 'track': 3,
}
