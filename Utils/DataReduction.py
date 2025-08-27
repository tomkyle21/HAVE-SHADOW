# import data analysis libraries
import numpy as np
import pandas as pd
from datetime import datetime

def convert_to_datetime(df, time_col):
    """Convert time column to datetime objects."""
    df[time_col] = pd.to_datetime(df[time_col], format='%H:%M:%S.%f')
    return df

def is_within_cone(df, role):
    """
    Determine if an aircraft (lead/wingman) is within intercept criteria:
      1) Bank angle within ±10°
      2) Within 1.5 nm aft of CM
      3) Within 30° trailing cone of CM velocity vector
    """

    # --- Column definitions ---
    roll_col = f'Roll_{role}'
    lat_col = f'Latitude_{role}'
    lon_col = f'Longitude_{role}'
    alt_col = f'Altitude_Msl_{role}'
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