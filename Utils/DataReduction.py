# import data analysis libraries
import numpy as np
import pandas as pd
import math

def convert_to_datetime(df, time_col):
    """Convert time column to datetime objects."""
    df[time_col] = pd.to_datetime(df[time_col])
    return df

def brute_force_merge_airspeed(df, airspeed_df_lead, airspeed_df_wing):
    """
    For each row in df, find the nearest SampleTime in the appropriate
    airspeed dataframe (lead or wing) and copy over Calibrated_Airspeed.
    Returns df with a new column 'CalibratedAirspeed'.
    """

    # Ensure datetime
    df['SampleTime'] = pd.to_datetime(df['SampleTime'])
    airspeed_df_lead['SampleTime'] = pd.to_datetime(airspeed_df_lead['SampleTime'])
    airspeed_df_wing['SampleTime'] = pd.to_datetime(airspeed_df_wing['SampleTime'])

    # Sort
    df = df.sort_values('SampleTime').reset_index(drop=True)
    airspeed_df_lead = airspeed_df_lead.sort_values('SampleTime').reset_index(drop=True)
    airspeed_df_wing = airspeed_df_wing.sort_values('SampleTime').reset_index(drop=True)

    # Add column
    df['CalibratedAirspeed'] = np.nan

    # --- Lead (AMBUSH51) ---
    mask_lead = df['MarkingTxt'] == 'AMBUSH51'
    for idx in df[mask_lead].index:
        t = df.at[idx, 'SampleTime']
        diffs = (airspeed_df_lead['SampleTime'] - t).abs()
        nearest_idx = diffs.idxmin()
        df.at[idx, 'CalibratedAirspeed'] = airspeed_df_lead.at[nearest_idx, 'Calibrated_Airspeed']

    # --- Wingman (HAWK11) ---
    mask_wing = df['MarkingTxt'] == 'HAWK11'
    for idx in df[mask_wing].index:
        t = df.at[idx, 'SampleTime']
        diffs = (airspeed_df_wing['SampleTime'] - t).abs()
        nearest_idx = diffs.idxmin()
        df.at[idx, 'CalibratedAirspeed'] = airspeed_df_wing.at[nearest_idx, 'Calibrated_Airspeed']

    return df

    
def altitude_deviation(df, role, assigned_alt, alt_block_radius=500):
    """
    Calculate altitude deviation from assigned altitude block. Inputs are:
    df: DataFrame containing scenario data
    lead_alt: assigned altitude for lead in feet
    wing_alt: assigned altitude for wingman in feet
    alt_block_radius: radius of altitude block in feet (default ±1000ft)
    """
    alt_col = 'Altitude'
    if role == 'Lead':
        marking = 'AMBUSH51'
    elif role == 'Wingman':
        marking = 'HAWK11'

    # define a block of altitudes +- 1000ft from assigned altitude
    block_min = assigned_alt - alt_block_radius
    block_max = assigned_alt + alt_block_radius
    
    # count the number of times in df where df[df['MarkingTxt']==marking][alt_col] is outside the block
    role_df = df[df['MarkingTxt'] == marking]
    role_df['Outside_Altitude_Block'] = (role_df[alt_col] < block_min) | (role_df[alt_col] > block_max)
    role_df['Block_Transition'] = role_df['Outside_Altitude_Block'].ne(role_df['Outside_Altitude_Block'].shift())
    altitude_violations = role_df[role_df['Block_Transition'] & role_df['Outside_Altitude_Block']]
    num_violations = altitude_violations.shape[0]

    # integrate the altitude deviation over time - sum the altitude deviation from block multiplied by the time in seconds
    role_df['Altitude_Deviation'] = np.where(role_df[alt_col] < block_min, block_min - role_df[alt_col],
                                            np.where(role_df[alt_col] > block_max, role_df[alt_col] - block_max, 0))
    role_df['Time_Diff'] = role_df['Timestamp'].diff().dt.total_seconds().fillna(0)
    altitude_deviation_integral = (role_df['Altitude_Deviation'] * role_df['Time_Diff']).sum()

    return num_violations, altitude_deviation_integral


def is_within_cone(scenario_data, cm_index, role, scenario_alt):
    """
    Determine if an aircraft (lead/wingman) is within intercept criteria:
      1) Bank angle within ±10°
      2) Within 1.5 nm aft of CM
      3) Within 30° trailing cone of CM velocity vector
      4) Heading within ±20° of CM heading
    Inputs:
    df: DataFrame containing scenario data
    cm_index: index of the CM being intercepted
    role: 'Lead' or 'Wingman'
    Returns a boolean Series indicating if the aircraft meets all criteria for a given timestamp and cm.
    """

    # for every entry in scenario_data['EntId']==cm_index, get the nearest entry in scenario_data['MarkingTxt']==role
    if role == 'Lead':
        marking = 'AMBUSH51'
    elif role == 'Wingman':
        marking = 'HAWK11'

    df_cm = scenario_data[scenario_data['EntId'] == cm_index].copy()
    df_ac = scenario_data[scenario_data['MarkingTxt'] == marking].copy()
    df = pd.merge_asof(df_ac.sort_values('Timestamp'), df_cm.sort_values('Timestamp'), on='Timestamp', suffixes=('_ac', '_cm'))
    df = df.dropna(subset=['EntId_cm'])  # drop rows where no matching CM data
    if df.empty:
        return pd.Series([False]*len(scenario_data), index=scenario_data.index)

    # relevant columns
    lat_col = 'Latitude_ac'
    lon_col = 'Longitude_ac'
    alt_col = 'Altitude_ac'
    heading_col = 'Heading_ac'
    cm_lat_col = 'Latitude_cm'
    cm_lon_col = 'Longitude_cm'
    cm_alt_col = 'Altitude_cm'
    cm_heading_col = 'Heading_cm'
    bank_col = 'Roll_ac'

    # get the SampleTime where the cm_index is last seen
    cm_last_time = df_cm['SampleTime'].max()

    # get the scenario start time
    scenario_data['SampleTime'] = pd.to_datetime(scenario_data['SampleTime'])   
    scenario_start_time = scenario_data['SampleTime'].min()

    # --- CONDITION NO LONGER USED!!: Bank Angle ---
    # THIS CONDITION IS MORE STRESSING THAN WE THOUGHT - MAY NEED TO RELAX
    cond_bank = df[bank_col].abs() <= 10
    df['Bank_Angle_Condition'] = cond_bank
    
    # --- CONDITION 1: Aft + Distance ---
    # Flat-earth approximation in nautical miles
    dlat = (df[lat_col] - df[cm_lat_col]) * 60.0    # nm
    dlon = (df[lon_col] - df[cm_lon_col]) * 60.0 * np.cos(np.radians(df[cm_lat_col]))
    # Distance between aircraft and CM
    df['distance_nm'] = np.sqrt(dlat**2 + dlon**2)
    cond1 = df['distance_nm'] <= 1.5
    df['Distance_Condition'] = cond1
    
    # --- CONDITION NOT USED - NICE TO HAVE: Inside trailing cone VELOCITY ---
    vel_vector_cm = np.column_stack([df['LinVelX_cm'], df['LinVelY_cm'], df['LinVelZ_cm']])
    vel_vector_ac = np.column_stack([df['LinVelX_ac'], df['LinVelY_ac'], df['LinVelZ_ac']])
    dot = np.sum(vel_vector_cm * vel_vector_ac, axis=1)
    angle_between_vec = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(vel_vector_cm, axis=1) * np.linalg.norm(vel_vector_ac, axis=1)), -1, 1)))
    df['angle_between_vel'] = angle_between_vec
    cond_vel = angle_between_vec <= 30

    # --- CONDITION 2: Inside trailing cone POSITION ---
    pos_vector_ac = np.column_stack([df['EcefX_ac'], df['EcefY_ac'], df['EcefZ_ac']])
    pos_vector_cm = np.column_stack([df['EcefX_cm'], df['EcefY_cm'], df['EcefZ_cm']])
    rel_pos = pos_vector_cm - pos_vector_ac
    dot = np.sum(rel_pos * vel_vector_cm, axis=1)
    angle_between_pos = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(rel_pos, axis=1) * np.linalg.norm(vel_vector_cm, axis=1)), -1, 1)))
    df['angle_between_pos'] = angle_between_pos
    cond2 = angle_between_pos <= 30
    df['Cone_Condition'] = cond2

    # --- CONDITION 3: Inside nose cone POSITION ---
    dot = np.sum(rel_pos * vel_vector_ac, axis=1)
    angle_between_pos_nose = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(rel_pos, axis=1) * np.linalg.norm(vel_vector_ac, axis=1)), -1, 1)))
    df['angle_between_pos_nose'] = angle_between_pos_nose
    cond3 = angle_between_pos_nose <= 30
    df['Nose_Cone_Condition'] = cond3

    intercept_criteria = cond1 & cond2 & cond3
    df['Intercept_Criteria'] = intercept_criteria

    if intercept_criteria.any():
        # --- SCENARIO META DATA ---
        # get the calibrated airspeed at the time of intercept
        airspeed_at_intercept = df.loc[intercept_criteria, 'CalibratedAirspeed_ac'].values[0]
        heading_at_intercept = df.loc[intercept_criteria, heading_col].values[0]
        cm_heading_at_intercept = df.loc[intercept_criteria, cm_heading_col].values[0]
        heading_diff_at_intercept = (heading_at_intercept - cm_heading_at_intercept + 180) % 360 - 180
        altitude_at_intercept = df.loc[intercept_criteria, alt_col].values[0]
        alt_offset_at_intercept = np.abs(altitude_at_intercept - scenario_alt)
        airspeed_diff_at_intercept = airspeed_at_intercept - df.loc[intercept_criteria, 'CM_Airspeed_ac'].values[0]
        bank_angle_at_intercept = df.loc[intercept_criteria, bank_col].values[0]

        # get the min SampleTime where intercept_criteria is True
        cm_int_time = df['SampleTime_cm'][intercept_criteria].min()
        # print(f"{role} meets intercept criteria for CM {cm_index} at {cm_int_time}")
        # print('This CM disappears at', cm_last_time)
        # print('Time to kill:', (cm_last_time - cm_int_time).total_seconds(), 'seconds')
        # df.to_csv(f'{role}_CM{cm_index}_intercept_debug.csv', index=False) # FOR DEBUGGING!!

        # define a dictionary that records the intercept event
        intercept_event = {
            'Interceptor Role': role,
            'CM_Index': cm_index,
            'Intercept_Time': cm_int_time,
            'Time_to_Consent_s': (cm_last_time - cm_int_time).total_seconds(),
            'Time_to_Intercept_s': (cm_int_time - scenario_start_time).total_seconds(),
            'Airspeed_at_Intercept_kt': airspeed_at_intercept,
            'Airspeed_Diff_at_Intercept_kt': airspeed_diff_at_intercept,
            'Heading_at_Intercept_deg': heading_at_intercept,
            'CM_Heading_at_Intercept_deg': cm_heading_at_intercept,
            'Heading_Diff_at_Intercept_deg': heading_diff_at_intercept,
            'Altitude_at_Intercept_ft': altitude_at_intercept,
            'Altitude_Offset_at_Intercept_ft': alt_offset_at_intercept,
            'Bank_Angle_at_Intercept_deg': bank_angle_at_intercept
        }
        # print(intercept_event)

        return intercept_event


# --- SAM ID TARS FUNCTIONS ---

# -------------------
# CONFIGURATION
# -------------------

# Bullseye position
bullseye_lat = 41.38494111111111
bullseye_lon = -91.24627944444444

# Offsets (x = east, y = north) in NM
offsets_nm = [
    (9, -7),   # SAM_A
    (9, 0),    # SAM_B
    (9, 7),    # SAM_C
    (-9, -7),  # SAM_D
    (-9, 0),   # SAM_E
    (-9, 7),   # SAM_F
]

labels = ["SAM_A", "SAM_B", "SAM_C", "SAM_D", "SAM_E", "SAM_F"]

# Axis for bullseye callouts (degrees clockwise from North)
axis_deg = 120

# -------------------
# HELPER FUNCTIONS
# -------------------

def offset_to_latlon(lat, lon, x_nm, y_nm):
    """Convert NM offsets to decimal degrees assuming flat Earth."""
    lat_new = lat + y_nm / 60.0
    lon_new = lon + x_nm / (60.0 * math.cos(math.radians(lat)))
    return lat_new, lon_new

def decimal_to_dms(lat, lon):
    """Convert decimal degrees to DMS string format."""
    lat_deg = int(abs(lat))
    lat_min = int((abs(lat) - lat_deg) * 60)
    lat_sec = (abs(lat) - lat_deg - lat_min/60) * 3600
    lat_dir = 'n' if lat >= 0 else 's'

    lon_deg = int(abs(lon))
    lon_min = int((abs(lon) - lon_deg) * 60)
    lon_sec = (abs(lon) - lon_deg - lon_min/60) * 3600
    lon_dir = 'w' if lon < 0 else 'e'

    return f"{lat_deg}:{lat_min:02d}:{lat_sec:06.3f}{lat_dir} {lon_deg}:{lon_min:02d}:{lon_sec:06.3f}{lon_dir}"

def bearing_range_flat(lat1, lon1, lat2, lon2, axis_deg=0):
    """Compute bearing and range from bullseye to target relative to axis, flat Earth."""
    dx = (lon2 - lon1) * 60.0 * math.cos(math.radians(lat1))  # NM east
    dy = (lat2 - lat1) * 60.0  # NM north

    rng = math.hypot(dx, dy)
    brg_true = (math.degrees(math.atan2(dx, dy)) + 360) % 360

    # Correct 90° offset and apply axis rotation
    brg_axis = (brg_true - 90 + axis_deg + 360) % 360

    return brg_axis, rng

# -------------------
# MAIN EXECUTION
# -------------------

for (x_nm, y_nm), label in zip(offsets_nm, labels):
    # Convert offsets to lat/lon (no rotation needed)
    lat, lon = offset_to_latlon(bullseye_lat, bullseye_lon, x_nm, y_nm)

    # Convert to DMS
    pos_str = decimal_to_dms(lat, lon)

    # Compute bullseye callout relative to axis
    brg, rng = bearing_range_flat(bullseye_lat, bullseye_lon, lat, lon, axis_deg=axis_deg)

    # Tactical rounding
    brg_round = int(round(brg))
    rng_round = int(round(rng))

    # Print results
    # print(f"# {label}: Bullseye {brg_round:03d}/{rng_round}")
    # print(f"platform {label}")
    # print(f"  position {pos_str}")
    # print("end_platform_type\n")