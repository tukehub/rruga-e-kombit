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
        # Midpoint of the expanded circuit, between Flag Square and Uji i Ftohtë.
        'origin': (40.444, 19.491),
        'near_km': 4.5, 'far_km': 24.0,
        'osm_radius': 3900, 'splat_span': 8000.0,
        # Keep landmark blocks at full scale and compress the longer roads
        # between them. Coordinates list south end, north end, and scale.
        'latitude_compression': (
            (40.4586, 40.4640, 0.43),  # Vlorë–Skelë between theatre and stadium
            (40.4304, 40.4475, 0.36),  # after the Lungomare entrance and gardens
            (40.4220, 40.4267, 0.62),  # approach to the coastal tunnel
        ),
        'building_radius': 3900, 'prop_radius': 3800,
        'half_width': 8.0,
        'exclude_pedestrian': True,
        # The mapped coastal tunnel carries the outbound leg under the headland.
        'race_ways': (228375726, 177181139),
        # A short closed-course connector from Celo Picari to Irfan Shehu.
        'race_connectors': ((2584087207, 1876295954),),
        'waypoints': [
            (40.4704777, 19.4912006),  # Sheshi i Flamurit, north of the monument
            (40.4698724, 19.4911927),  # Boulevard beside the house
            (40.4688450, 19.4912131),  # Muradie Mosque, then toward Skelë
            (40.4628, 19.4894),       # Bulevardi Ismail Qemali, southbound
            (40.4574, 19.4876),       # Flamurtari stadium
            (40.4545, 19.4866),       # Sheshi Pavarësia
            (40.4530, 19.4865),       # Independence Museum approach
            (40.4500, 19.4904),       # Rruga Çamëria, Lungomare
            (40.4462743, 19.4943573), # seaside boulevard
            (40.4321612, 19.4944346), # Murat Tërbaçi on the waterfront
            (40.4212347, 19.4876934), # Uji i Ftohtë, north portal
            (40.4205612, 19.4869312), # south portal
            (40.4169588, 19.4870453), # the climb inland, Dhimitër Konomi
            (40.4238856, 19.4935304),
            (40.4345345, 19.4958724), # Duro Shaska toward Centrale
            (40.4526699, 19.4973512), # Centrale return via Zenel Murra
            (40.4593455, 19.4960511), # Sulejman Delvina
            (40.47066, 19.49496),
            (40.4707020, 19.4928220),
            (40.4714072, 19.4931028),
            (40.4714889, 19.4919095), # Justin Godard in Muradie
            (40.4728369, 19.4926983),
            (40.4733250, 19.4939970),
            (40.4747170, 19.4939030), # approach the Municipality from the east
            (40.4748120, 19.4933420), # Bashkia Vlorë
            (40.4748120, 19.4929890),
            (40.4713892, 19.4910000), # back across Flag Square
        ],
        'tunnel': ((40.4212347, 19.4876934), (40.4205612, 19.4869312)),
        'turnaround': ((40.4191404, 19.4866541), (40.4197696, 19.4902821)),
        'median': ((40.4523, 19.4874), (40.4473, 19.4929)),
        'stone_street': ((40.47165, 19.49202), (40.47258, 19.49256)),
        'scenery_clearances': [
            ((40.47210, 19.49228), (42, 66)),  # the modeled Muradie street fronts
            ((40.42090, 19.48733), (63, 67)),  # rock and tunnel portals
        ],
        'landmarks': [
            # Independence Monument at its OSM node, "1912" and the group
            # facing the circuit; the park's scattered trees keep clear.
            {'id': 'independence', 'll': (40.47067, 19.49066), 'yaw': -44.3,
             'clear_half': (14, 14)},
            # The great flag stands beside it on the square (placed, not mapped).
            {'id': 'flagpole_big', 'll': (40.470543, 19.49083), 'yaw': -44.3,
             'clear_half': (8, 8)},
            {'id': 'muradie_mosque', 'll': (40.46907, 19.49087), 'yaw': -72,
             'clear_half': (21, 27)},
            {'id': 'vlora_house', 'll': (40.469837, 19.490869), 'yaw': -90,
             'clear_half': (15, 15)},
            # Centre spot of the mapped pitch; the main stand's facade faces
            # west across its plaza to the boulevard (OSM axis 96.8 deg).
            {'id': 'petro_marko', 'll': (40.46488, 19.49068), 'yaw': 72,
             'offset_x': -9, 'clear_half': (29, 26)},
            {'id': 'skela_roundabout', 'll': (40.454502, 19.486624), 'yaw': 0},
            {'id': 'skela_corner', 'll': (40.45471, 19.48712), 'yaw': 76,
             'clear_half': (18, 27)},
            {'id': 'lungomare_gateway', 'll': (40.45228, 19.48812), 'yaw': 123,
             'clear_half': (29, 27)},
            {'id': 'waterfront_courts', 'll': (40.42871, 19.49157), 'yaw': -33,
             'offset_x': 20, 'offset_y': 1.15, 'offset_z': 21, 'clear_half': (60, 77)},
            {'id': 'vlore_municipality', 'll': (40.47458, 19.49335), 'yaw': -32,
             'offset_z': 8, 'clear_half': (31, 27)},
            {'id': 'flamurtari', 'll': (40.456086, 19.488786), 'yaw': -6.8, 'clear_half': (95, 85)},
            # Move the Independence Museum through its park toward the road
            # so the entrance and balcony read from the seafront approach.
            {'id': 'independence_museum', 'll': (40.45218, 19.48528), 'yaw': -62.4,
             'offset_x': 76.0, 'offset_z': -62.0, 'clear_half': (24, 24)},
        ],
        # Replace mapped landmark outlines and open the stadium's frontage
        # by omitting the two buildings that flank its plaza.
        'landmark_buildings': [1237374187, 1237374188, 1237374189, 1237374190, 1003616059,
                               1083265737, 1083173083, 533052049, 731109970, 491621848, 776920597],
        # Lungomare: from Sheshi Pavarsia past the museum to the end of the
        # promenade. Sea on one side (palms), cafés and 10-15 storey blocks on the other.
        'seafront': {'from': (40.4530, 19.4865), 'to': (40.4462, 19.4943),
                     'levels': (10, 15), 'frontage': 140},
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
