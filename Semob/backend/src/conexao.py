import os
from dotenv import load_dotenv

load_dotenv()

def obter_conexao():
    db_url = os.getenv("DATABASE_URL", "sqlite:///./app.db")
    print(f"Conectando ao banco em: {db_url}")
    return db_url