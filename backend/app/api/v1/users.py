"""
Users API Endpoints
User profile and statistics
"""
from datetime import datetime, timedelta
from typing import List
from uuid import UUID, uuid4

from fastapi import APIRouter, Query

from ...schemas import DailyStat, CalendarStatsResponse

router = APIRouter()


@router.get("/me")
async def get_current_user():
    """
    Get current user profile
    
    In production, this would use authentication.
    """
    return {
        "user_id": str(uuid4()),
        "name": "Demo User",
        "email": "demo@aquametric.app",
        "created_at": datetime.now().isoformat(),
    }


@router.get("/stats/calendar", response_model=CalendarStatsResponse)
async def get_calendar_stats(
    start_date: str = Query(..., description="Start date (YYYY-MM-DD)"),
    end_date: str = Query(..., description="End date (YYYY-MM-DD)"),
):
    """
    Get swimming statistics for calendar heatmap
    
    Returns daily statistics for the specified date range.
    """
    # Parse dates
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    
    # Generate demo data (would come from database in production)
    stats: List[DailyStat] = []
    current = start
    
    import random
    random.seed(42)  # Reproducible demo data
    
    while current <= end:
        # Simulate swimming patterns (more likely on weekdays)
        is_weekday = current.weekday() < 5
        swim_probability = 0.6 if is_weekday else 0.3
        
        if random.random() < swim_probability:
            distance = random.randint(500, 3000)
            duration = int(distance / random.uniform(0.8, 1.5))  # Variable pace
            
            stats.append(DailyStat(
                date=current.strftime("%Y-%m-%d"),
                total_distance_m=distance,
                total_duration_sec=duration,
                session_count=random.randint(1, 2),
                intensity_level=min(4, distance // 750)
            ))
        
        current += timedelta(days=1)
    
    return CalendarStatsResponse(
        user_id=uuid4(),
        stats=stats
    )


@router.get("/stats/summary")
async def get_user_summary():
    """
    Get overall user statistics summary
    """
    # Demo data
    return {
        "total_sessions": 42,
        "total_distance_m": 84000,
        "total_duration_min": 2520,
        "avg_swolf": 42.3,
        "favorite_stroke": "freestyle",
        "current_streak_days": 5,
        "best_streak_days": 14,
        "this_week_distance_m": 6000,
        "this_month_distance_m": 24000,
    }
