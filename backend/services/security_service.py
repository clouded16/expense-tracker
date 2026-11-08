import random
from fastapi.security import OAuth2PasswordBearer


def generate_otp():
    return str(random.randint(100000, 999999))