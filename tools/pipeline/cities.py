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
        'waypoints': [
            (41.3242813, 19.8236043),  # Bajram Curri, Downtown One (start/finish)
            (41.3232735, 19.8224131),  # Papa Gjon Pali II, by the Pyramid
            (41.3173730, 19.8214600),  # Nënë Tereza Square, facing Polytechnic
            (41.3263000, 19.8170000),  # Dëshmorët e 4 Shkurtit, cathedral
            (41.3282280, 19.8158110),  # Kavajës, Eyes of Tirana
            (41.3303501, 19.8180710),  # Urani Pano, International Hotel
            (41.3274517, 19.8226091),  # Abdi Toptani, mall and square perimeter
        ],
        'landmarks': [
            {'id': 'skanderbeg', 'll': (41.32775, 19.81850), 'yaw': 180},
            {'id': 'pyramid', 'll': (41.323058, 19.821443), 'yaw': 0},
            {'id': 'downtown_one', 'll': (41.324082, 19.823911), 'yaw': 0, 'offset_x': 5, 'offset_z': 12},
            # Move these two away from the widened arcade circuit, preserving
            # their approximate positions while keeping chase cameras clear.
            {'id': 'eyes_tirana', 'll': (41.328561, 19.815744), 'yaw': 0, 'offset_x': -30},
            {'id': 'bank_albania', 'll': (41.327758, 19.816685), 'yaw': 0, 'offset_x': 20},
            {'id': 'international_hotel', 'll': (41.329863, 19.818686), 'yaw': 0},
            {'id': 'polytechnic', 'll': (41.3166196, 19.8217354), 'yaw': 0},
            {'id': 'cathedral', 'll': (41.326518, 19.81753), 'yaw': 0},
            {'id': 'toptani', 'll': (41.327064, 19.822743), 'yaw': 0, 'offset_z': 6},
            {'id': 'clocktower', 'll': (41.32800, 19.82000), 'yaw': 0},
            {'id': 'mosque', 'll': (41.32790, 19.81950), 'yaw': 0},
            {'id': 'mother_teresa', 'll': (41.31880, 19.82160), 'yaw': 0},
            {'id': 'blloku_sign', 'll': (41.32070, 19.81600), 'yaw': 90},
        ],
        # Replace these specific OSM footprints with the original landmarks,
        # instead of drawing a generic extruded building through each model.
        'landmark_buildings': [174510408, 1255594721, 885643060, 236566880, 236566876, 177186612, 7753718, 410277121],
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
