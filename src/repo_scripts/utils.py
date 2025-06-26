from datetime import datetime

def format_size(size_in_bytes: int) -> str:
    for unit in ['B', 'K', 'M', 'G', 'T']:
        if size_in_bytes < 1024:
            return f"{size_in_bytes:.1f}{unit}"
        size_in_bytes /= 1024
    return f"{size_in_bytes:.1f}P"

def format_date(date_str: str) -> str:
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt.strftime('%Y-%m-%d %H:%M')
    except:
        return "unknown"