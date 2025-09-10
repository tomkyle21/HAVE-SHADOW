# import data analysis libraries
import numpy as np
import pandas as pd
from datetime import datetime

def convert_to_datetime(df, time_col):
    """Convert time column to datetime objects."""
    df[time_col] = pd.to_datetime(df[time_col], format='%H:%M:%S.%f')
    return df
    
def altitude_deviation(df, lead_alt, wing_alt, alt_block_radius=1000):
    """
    Calculate altitude deviation from assigned altitude block. Inputs are:
    df: DataFrame containing scenario data
    lead_alt: assigned altitude for lead in feet
    wing_alt: assigned altitude for wingman in feet
    alt_block_radius: radius of altitude block in feet (default ±1000ft)
    """
    alt_col_lead = f'Altitude_Lead'
    alt_col_wing = f'Altitude_Wing'
    

    # define a block of altitudes +- 1000ft from assigned altitude
    lead_block_min = lead_alt - alt_block_radius
    lead_block_max = lead_alt + alt_block_radius
    wing_block_min = wing_alt - alt_block_radius
    wing_block_max = wing_alt + alt_block_radius
    
    # count the number of times each aircraft is outside its assigned altitude block
    df[f'Lead_Alt_Dev'] = np.where(
        (df[alt_col_lead] < lead_block_min) | (df[alt_col_lead] > lead_block_max),
        np.minimum(np.abs(df[alt_col_lead] - lead_block_min), np.abs(df[alt_col_lead] - lead_block_max)),
        0
    )
    df[f'Wingman_Alt_Dev'] = np.where(
        (df[alt_col_wing] < wing_block_min) | (df[alt_col_wing] > wing_block_max),
        np.minimum(np.abs(df[alt_col_wing] - wing_block_min), np.abs(df[alt_col_wing] - wing_block_max)),
        0
    )

    # the actual count is the number of times the Alt_Dev column transitions from false to true
    lead_alt_dev_count = ((df[f'Lead_Alt_Dev'] > 0) & (df[f'Lead_Alt_Dev'].shift(1) == 0)).sum()
    wing_alt_dev_count = ((df[f'Wingman_Alt_Dev'] > 0) & (df[f'Wingman_Alt_Dev'].shift(1) == 0)).sum()

    # integrate the difference between actual altitude and assigned altitude block over time in feet-seconds for both aircraft, only when outside the block
    df['Time_Diff'] = df['Timestamp'].diff().dt.total_seconds().fillna(0)
    df['Lead_Alt_Dev_Integrated'] = df['Lead_Alt_Dev'] * df['Time_Diff']
    df['Wingman_Alt_Dev_Integrated'] = df['Wingman_Alt_Dev'] * df['Time_Diff']
    lead_alt_dev_integrated = df['Lead_Alt_Dev_Integrated'].sum()
    wing_alt_dev_integrated = df['Wingman_Alt_Dev_Integrated'].sum()

    return lead_alt_dev_count, wing_alt_dev_count, lead_alt_dev_integrated, wing_alt_dev_integrated

def is_within_cone(df, role):
    """
    Determine if an aircraft (lead/wingman) is within intercept criteria:
      1) Bank angle within ±10°
      2) Within 1.5 nm aft of CM
      3) Within 30° trailing cone of CM velocity vector
      4) Heading within ±20° of CM heading
    Inputs:
    df: DataFrame containing scenario data
    role: 'Lead' or 'Wingman'
    Returns a boolean Series indicating if the aircraft meets all criteria for a given timestamp and cm.
    TODO: MAY NEED TO PASS IN CM INDEX!!
    """

    # --- Column definitions ---
    roll_col = f'Roll_{role}'
    lat_col = f'Latitude_{role}'
    lon_col = f'Longitude_{role}'
    alt_col = f'Altitude_{role}'
    heading_col = f'True_Heading_{role}'

    cm_lat_col = 'Latitude'
    cm_lon_col = 'Longitude'
    cm_alt_col = f'CM_Altitude_{role}'
    cm_heading_col = 'Heading'   # you’ll need missile heading in your data

    # --- CONDITION 1: Bank angle ---
    cond1 = df[roll_col].abs() <= 10

    # --- Convert to radians ---
    lat_ac = np.radians(df[lat_col])
    lon_ac = np.radians(df[lon_col])
    lat_cm = np.radians(df[cm_lat_col])
    lon_cm = np.radians(df[cm_lon_col])

    # --- Approx Earth radius in nm ---
    R = 3440.065

    # --- ENU vector from CM → Aircraft (flat Earth approx for short ranges) ---
    dlat = lat_ac - lat_cm
    dlon = lon_ac - lon_cm
    dx = R * np.cos(lat_cm) * dlon     # east displacement [nm]
    dy = R * dlat                      # north displacement [nm]
    dz = (df[alt_col] - df[cm_alt_col]) / 6076.12  # alt diff [nm]
    vec_cm2ac = np.stack([dx, dy, dz], axis=1)

    # --- Missile velocity vector from heading ---
    cm_heading_rad = np.radians(df[cm_heading_col])
    # assume level flight (no vertical velocity)
    vx = np.sin(cm_heading_rad)
    vy = np.cos(cm_heading_rad)
    vz = 0.0
    vec_cm_vel = np.stack([vx, vy, np.full_like(vx, vz)], axis=1)

    # --- CONDITION 2: Aft + distance ---
    dist = np.linalg.norm(vec_cm2ac, axis=1)   # straight-line dist [nm]
    projection = np.sum(vec_cm2ac * vec_cm_vel, axis=1)
    aft_mask = projection < 0                  # behind the CM
    cond2 = (dist <= 1.5) & aft_mask

    # --- CONDITION 3: Inside trailing cone ---
    dot = np.sum(vec_cm2ac * vec_cm_vel, axis=1)
    cos_angle = dot / (dist * np.linalg.norm(vec_cm_vel, axis=1))
    cos_angle = np.clip(cos_angle, -1, 1)      # numerical safety
    angle = np.degrees(np.arccos(cos_angle))
    cond3 = angle <= 30

    # --- CONDITION 4: Heading Sanity Check ---
    heading_diff = np.abs(df[heading_col] - df[cm_heading_col])
    heading_diff = np.where(heading_diff > 180, 360 - heading_diff, heading_diff)
    cond4 = heading_diff <= 20

    intercept_criteria = cond1 & cond2 & cond3 & cond4

    # --- Combine all conditions ---
    return intercept_criteria


def terminal_condition_error(df, role, CM_index):
    """
    Calculate terminal condition error for interception events. This includes relative altitude, heading, airspeed, and distance behind the CM at the moment of interception.
    Inputs:
    df: DataFrame containing scenario data
    role: 'Lead' or 'Wingman'
    CM_index: index of the CM being intercepted
    Returns a DataFrame summarizing the terminal conditions at interception events.
    """

    intercept_col = f'{role}_Intercept_{CM_index}'
    
    # filter to only interception events
    intercept_events = df[df[intercept_col]]
    
    # record the intercepting aircraft, its altitude, airspeed, and distance to CM at the moment of interception
    if intercept_events.empty:
        return None
    else:
        alt_col = f'Altitude_{role}'
        airspeed_col = f'True_Airspeed_{role}'
        
        # Calculate distance to CM
        R = 3440.065
        lat_ac = np.radians(intercept_events[f'Latitude_{role}'])
        lon_ac = np.radians(intercept_events[f'Longitude_{role}'])
        lat_cm = np.radians(intercept_events[f'Latitude_{CM_index}'])
        lon_cm = np.radians(intercept_events['Longitude_CM_index'])
        dlat = lat_ac - lat_cm
        dlon = lon_ac - lon_cm
        dx = R * np.cos(lat_cm) * dlon
        dy = R * dlat
        dz = (intercept_events[alt_col] - intercept_events[f'CM_Altitude_{role}']) / 6076.12
        distance_to_cm = np.sqrt(dx**2 + dy**2 + dz**2)

        # calculate relative altitude, heading, airspeed
        rel_altitude = intercept_events[alt_col] - intercept_events[f'CM_Altitude_{role}']
        rel_heading = intercept_events[f'True_Heading_{role}'] - intercept_events[f'Heading_{CM_index}']
        rel_airspeed = intercept_events[airspeed_col] - intercept_events[f'CM_Airspeed']

        intercept_summary = pd.DataFrame({
            'Timestamp': intercept_events['Timestamp'],
            'Relative_Altitude_ft': rel_altitude,
            'Relative_Heading_deg': rel_heading,
            'Relative_Airspeed_kt': rel_airspeed,
            'Distance_to_CM_nm': distance_to_cm
        })
        
        return intercept_summary