import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[3] / "src" / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
