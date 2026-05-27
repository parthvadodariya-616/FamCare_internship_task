from app.routers.slots import router as slots_router, services_router
from app.routers.cart import router as cart_router, patients_router, caregivers_router

__all__ = [
    "slots_router",
    "services_router",
    "cart_router",
    "patients_router",
    "caregivers_router",
]
