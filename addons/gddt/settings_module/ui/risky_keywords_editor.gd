@tool
extends RefCounted
class_name GDDTRiskyKeywordsEditor


static func parse_keyword_list(keywords_text: String) -> Array[String]:
    var parsed: Array[String] = []
    var seen := {}
    for raw_part in keywords_text.split(","):
        var keyword := raw_part.strip_edges().to_lower()
        if keyword.is_empty() or seen.has(keyword):
            continue
        parsed.append(keyword)
        seen[keyword] = true
    return parsed


static func to_display_text(keywords: Array[String]) -> String:
    var items: Array[String] = []
    for keyword in keywords:
        items.append(String(keyword))
    return ", ".join(items)
