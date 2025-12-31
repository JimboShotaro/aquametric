"""
API v1 Router
Combines all API endpoints under /api/v1
"""
from fastapi import APIRouter

from .sessions import router as sessions_router
from .users import router as users_router
from .analysis import router as analysis_router

router = APIRouter()

router.include_router(sessions_router, prefix="/sessions", tags=["Sessions"])
router.include_router(users_router, prefix="/users", tags=["Users"])
router.include_router(analysis_router, prefix="/analysis", tags=["Analysis"])
