from __future__ import annotations

import json
import math
from typing import Optional, Tuple

SEARCH_RADII_KM = [5, 10, 15, 20, 30, 40, 50, 60, 70]
MAX_SEARCH_RADIUS_KM = 70
EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two coordinates in kilometres."""
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def pincode_in_city_record(pincode: str, pincodes_raw) -> bool:
    """Check whether a pincode belongs to a city's stored pincode list."""
    if not pincode or not pincodes_raw:
        return False

    if isinstance(pincodes_raw, list):
        entries = pincodes_raw
    elif isinstance(pincodes_raw, str):
        try:
            parsed = json.loads(pincodes_raw)
            entries = parsed if isinstance(parsed, list) else [pincodes_raw]
        except json.JSONDecodeError:
            entries = [p for p in pincodes_raw.replace(";", ",").split(",") if p.strip()]
    else:
        return False

    normalized = {str(p).strip() for p in entries if str(p).strip()}
    return pincode.strip() in normalized


async def resolve_customer_coordinates(
    db,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    pincode: Optional[str] = None,
    city_name: Optional[str] = None,
) -> Tuple[Optional[float], Optional[float]]:
    """Resolve customer coordinates from explicit lat/lng, pincode, or city name."""
    if latitude is not None and longitude is not None:
        return float(latitude), float(longitude)

    from sqlalchemy import select, func, String
    from app.models.user_location import City

    if pincode and pincode.strip():
        clean_pincode = pincode.strip()
        if not clean_pincode.isdigit():
            city_name = clean_pincode
        else:
            city_res = await db.execute(
                select(City).where(
                    func.cast(City.pincodes, String).ilike(f"%{clean_pincode}%")
                )
            )
            city = city_res.scalars().first()
            if city and city.latitude is not None and city.longitude is not None:
                return float(city.latitude), float(city.longitude)

    if city_name and city_name.strip():
        clean_city = city_name.strip().lower()
        city_res = await db.execute(
            select(City).where(func.lower(City.name).ilike(f"%{clean_city}%"))
        )
        city = city_res.scalars().first()
        if city and city.latitude is not None and city.longitude is not None:
            return float(city.latitude), float(city.longitude)

        # Smart fallback coordinates for major operating cities
        if "hyderabad" in clean_city or "secunderabad" in clean_city or "cyberabad" in clean_city:
            return 17.385044, 78.486671
        elif "visakhapatnam" in clean_city or "vizag" in clean_city:
            return 17.686816, 83.218482
        elif "vijayawada" in clean_city:
            return 16.506174, 80.648015
        elif "bangalore" in clean_city or "bengaluru" in clean_city:
            return 12.971598, 77.594562
        elif "chennai" in clean_city:
            return 13.082680, 80.270718

    return None, None
